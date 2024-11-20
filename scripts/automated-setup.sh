#!/bin/bash
# Renk tanımlamaları
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Dizin yapısı
BASE_DIR="/home/devops/k8s"
SCRIPTS_DIR="$BASE_DIR/scripts"
TERRAFORM_DIR="$BASE_DIR/terraform"

# Log fonksiyonu
log() {
    echo -e "${GREEN}$(date '+%Y-%m-%d %H:%M:%S') - $1${NC}"
}

# Hata kontrolü
check_error() {
    if [ $? -ne 0 ]; then
        log "${RED}HATA: $1${NC}"
        exit 1
    fi
}

# Docker'ın hazır olmasını bekle
wait_for_docker() {
    log "Docker'ın hazır olması bekleniyor..."
    local counter=0
    while [ $counter -lt 30 ]; do
        if docker info >/dev/null 2>&1; then
            log "${GREEN}Docker hazır!${NC}"
            return 0
        fi
        counter=$((counter + 1))
        sleep 2
    done
    log "${RED}Docker hazır değil!${NC}"
    return 1
}

# System podlarının durumunu kontrol et
check_system_pods() {
    local all_running=true
    while read -r status; do
        if [ "$status" != "Running" ]; then
            all_running=false
            break
        fi
    done < <(kubectl get pods -n kube-system -o jsonpath='{.items[*].status.phase}')
    echo "$all_running"
}

# Temizlik fonksiyonu
cleanup() {
    log "Sistem temizliği yapılıyor..."
    
    # Kind cluster'ı kontrol et ve sil
    if kind get clusters 2>/dev/null | grep -q "test-cluster"; then
        log "Eski cluster siliniyor..."
        kind delete clusters test-cluster
        kind delete clusters --all 2>/dev/null || true
        sleep 10  # Cluster'ın tamamen silinmesi için bekle
    fi

    # Kubeconfig temizliği
    log "Kubeconfig temizliği yapılıyor..."
    rm -f ~/.kube/config 2>/dev/null || true

    # Docker temizliği
    log "Docker temizliği yapılıyor..."
    docker system prune -af --volumes
    
    log "Docker servisi yeniden başlatılıyor..."
    sudo systemctl restart docker
    wait_for_docker || exit 1
    
    log "Docker socket izinleri ayarlanıyor..."
    sudo chmod 666 /var/run/docker.sock
    
    # Terraform temizliği
    log "Terraform state temizleniyor..."
    cd "$TERRAFORM_DIR" || exit 1
    rm -f terraform.tfstate*
    rm -f .terraform.lock.hcl
    rm -rf .terraform* 2>/dev/null || true
    rm -rf .terraform
    cd - || exit 1
    
    # Ek bekleme süresi
    log "Sistem kaynaklarının serbest kalması için bekleniyor..."
    sleep 15
    
    log "Temizlik tamamlandı"
}

# IP adresini alma fonksiyonu
get_host_ip() {
    IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n 1)
    if [ -z "$IP" ]; then
        log "${RED}IP adresi bulunamadı!${NC}"
        exit 1
    fi
    echo "$IP"
}

# Terraform değişkenlerini güncelle
update_terraform_vars() {
    local ip=$1
    cat > "$TERRAFORM_DIR/terraform.tfvars" <<EOF
host_ip = "${ip}"
api_port = 6444
cluster_name = "test-cluster"
EOF
    log "Terraform değişkenleri güncellendi"
}

# Ana dizin kontrolü
if [ ! -d "$SCRIPTS_DIR" ] || [ ! -d "$TERRAFORM_DIR" ]; then
    log "${RED}HATA: Gerekli dizinler bulunamadı. Lütfen dizin yapısını kontrol edin.${NC}"
    exit 1
fi

# Ana işlem başlangıcı
log "İşlem başlıyor..."

# UFW kontrolü
if command -v ufw >/dev/null 2>&1; then
    if sudo ufw status | grep -q "Status: active"; then
        log "${YELLOW}UFW aktif durumda. Devre dışı bırakılıyor...${NC}"
        sudo ufw disable
        check_error "UFW devre dışı bırakılamadı"
    fi
fi

# Script dosyalarını çalıştırılabilir yap
log "Script dosyaları çalıştırılabilir yapılıyor..."
chmod +x $SCRIPTS_DIR/get_ip.sh
chmod +x $SCRIPTS_DIR/install-dependencies.sh
chmod +x $SCRIPTS_DIR/postgresql-test.sh
chmod +x $SCRIPTS_DIR/redis-test.sh
chmod +x $SCRIPTS_DIR/setup.sh
chmod +x $SCRIPTS_DIR/update-kubeconfig.sh
chmod +x $SCRIPTS_DIR/automated-setup.sh

# Temizlik işlemini çalıştır
cleanup

# Host IP'sini al ve terraform değişkenlerini güncelle
HOST_IP=$(get_host_ip)
update_terraform_vars "$HOST_IP"

# Terraform işlemleri öncesi son kontrol
log "Terraform işlemleri öncesi son kontroller yapılıyor..."
if ! docker info >/dev/null 2>&1; then
    log "${RED}Docker hazır değil. İşlem iptal ediliyor.${NC}"
    exit 1
fi

# Eski cluster'ı kontrol et
log "Eski cluster kontrol ediliyor..."
cd "$TERRAFORM_DIR" || exit 1
if kind get clusters | grep -q "test-cluster"; then
    log "${YELLOW}Eski cluster bulundu. Siliniyor...${NC}"
    terraform destroy -auto-approve
    check_error "Cluster silinemedi"
    log "Eski cluster başarıyla silindi"
fi

# Bağımlılıkları yükle
log "Bağımlılıklar yükleniyor..."
bash "$SCRIPTS_DIR/install-dependencies.sh"
check_error "Bağımlılıkların kurulumunda hata oluştu"

# Terraform ile altyapı kurulumu
log "Terraform başlatılıyor..."
terraform init
check_error "Terraform init başarısız oldu"

log "Terraform apply çalıştırılıyor..."
terraform apply -auto-approve
check_error "Terraform apply başarısız oldu"

# Cluster'ın hazır olmasını bekle
log "Cluster hazırlığı için 30 saniye bekleniyor..."
sleep 30

# System podlarını kontrol et
log "System podları kontrol ediliyor..."
max_attempts=10
attempt=1
while [ $attempt -le $max_attempts ]; do
    log "Pod durumu kontrolü ($attempt/$max_attempts)..."
    kubectl get pods -n kube-system
    if [ "$(check_system_pods)" = "true" ]; then
        log "Tüm system podları çalışıyor!"
        break
    fi
    if [ $attempt -eq $max_attempts ]; then
        log "${RED}System podları hazır duruma gelmedi!${NC}"
        exit 1
    fi
    attempt=$((attempt+1))
    sleep 10
done

# Setup scriptini çalıştır
log "Setup script'i çalıştırılıyor..."
bash "$SCRIPTS_DIR/setup.sh"
check_error "Setup script'i çalıştırılırken hata oluştu"

# Final kontroller ve bilgi gösterimi
log "Sistem kontrolleri yapılıyor..."
kubectl get nodes
kubectl get pods -A

# Erişim bilgileri
echo -e "\n${GREEN}Erişim Bilgileri:${NC}"
echo -e "${BLUE}PostgreSQL:${NC} $HOST_IP:30432"
echo -e "${BLUE}Redis:${NC} $HOST_IP:32379"
echo -e "${BLUE}Jenkins:${NC} http://$HOST_IP:32001"
echo -e "${BLUE}Application:${NC} http://$HOST_IP:30080"

# Final mesajlar ve kubeconfig ayarları
echo -e "\n${GREEN}Final Yapılandırma:${NC}"
echo "----------------------------------------"

# Kubeconfig izinlerini ayarla
log "Kubeconfig dosyası izinleri ayarlanıyor..."
chmod 600 ~/.kube/config && \
log "Kubeconfig izinleri başarıyla ayarlandı (600)"

# Kubeconfig içeriğini göster
echo -e "\n${BLUE}Kubeconfig Dosya İçeriği:${NC}"
echo "----------------------------------------"
cat ~/.kube/config
echo "----------------------------------------"

# İzinleri göster
echo -e "\n${BLUE}Kubeconfig Dosya İzinleri:${NC}"
ls -l ~/.kube/config
echo "----------------------------------------"

# Jenkins şifresi
echo -e "\n${YELLOW}Jenkins şifresi alınıyor...${NC}"
sleep 60  # Jenkins'in tam olarak başlaması için bekle

RETRY_COUNT=0
MAX_RETRIES=5

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if JENKINS_POD=$(kubectl get pods -n demo -l app=jenkins -o jsonpath='{.items[0].metadata.name}' 2>/dev/null) && \
       kubectl exec -n demo $JENKINS_POD -- cat /var/jenkins_home/secrets/initialAdminPassword >/dev/null 2>&1; then
        echo -e "${GREEN}Jenkins admin şifresi:${NC}"
        kubectl exec -n demo $JENKINS_POD -- cat /var/jenkins_home/secrets/initialAdminPassword
        break
    else
        RETRY_COUNT=$((RETRY_COUNT+1))
        if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
            echo -e "${YELLOW}Jenkins şifresi henüz hazır değil. Jenkins UI üzerinden manuel olarak alabilirsiniz.${NC}"
        else
            echo "Jenkins şifresi için bekleniyor... ($RETRY_COUNT/$MAX_RETRIES)"
            sleep 15
        fi
    fi
done

log "Tüm işlemler başarıyla tamamlandı!"
