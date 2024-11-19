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

# UFW'yi kontrol et ve devre dışı bırak
log "UFW durumu kontrol ediliyor..."
if command -v ufw >/dev/null 2>&1; then
    if sudo ufw status | grep -q "Status: active"; then
        log "${YELLOW}UFW aktif durumda. Devre dışı bırakılıyor...${NC}"
        sudo ufw disable
        check_error "UFW devre dışı bırakılamadı"
        log "${GREEN}UFW başarıyla devre dışı bırakıldı${NC}"
    else
        log "${GREEN}UFW zaten devre dışı${NC}"
    fi
else
    log "${BLUE}UFW sisteminizde yüklü değil${NC}"
fi

log "Script dosyaları çalıştırılabilir yapılıyor..."
chmod +x $SCRIPTS_DIR/get_ip.sh
chmod +x $SCRIPTS_DIR/install-dependencies.sh
chmod +x $SCRIPTS_DIR/postgresql-test.sh
chmod +x $SCRIPTS_DIR/redis-test.sh
chmod +x $SCRIPTS_DIR/setup.sh
chmod +x $SCRIPTS_DIR/update-kubeconfig.sh
chmod +x $SCRIPTS_DIR/automated-setup.sh

# Temizlik fonksiyonu
cleanup() {
    log "Sistem temizliği yapılıyor..."
    
    # Kind cluster'ı kontrol et ve sil
    if kind get clusters | grep -q "test-cluster"; then
        log "Eski cluster siliniyor..."
        kind delete clusters test-cluster
    fi
    
    # Docker temizliği
    log "Docker temizliği yapılıyor..."
    docker system prune -af --volumes
    
    # Terraform temizliği
    log "Terraform state temizleniyor..."
    cd $TERRAFORM_DIR
    rm -f terraform.tfstate*
    rm -f .terraform.lock.hcl
    rm -rf .terraform
    cd -
    
    log "Temizlik tamamlandı"
}

# Ana script başlangıcında çağır
cleanup() {
    log "Sistem temizliği yapılıyor..."
    
    # Kind cluster'ı kontrol et ve sil
    if kind get clusters | grep -q "test-cluster"; then
        log "Eski cluster siliniyor..."
        kind delete clusters test-cluster
    fi
    
    # Docker temizliği
    log "Docker temizliği yapılıyor..."
    docker system prune -af --volumes
    
    # Terraform temizliği
    log "Terraform state temizleniyor..."
    rm -f terraform.tfstate*
    rm -f .terraform.lock.hcl
    
    log "Temizlik tamamlandı"
}

# Ana script başlangıcında çağır
cleanup

# IP adresini alma fonksiyonu
get_host_ip() {
    IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n 1)
    if [ -z "$IP" ]; then
        log "${RED}IP adresi bulunamadı!${NC}"
        exit 1
    fi
    echo "$IP"
}

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

# Host IP'sini al ve terraform değişkenlerini güncelle
HOST_IP=$(get_host_ip)
update_terraform_vars "$HOST_IP"

# 1. Eski cluster'ı temizle
log "Eski cluster kontrol ediliyor..."
cd "$TERRAFORM_DIR" || exit 1
if kind get clusters | grep -q "test-cluster"; then
    log "${YELLOW}Eski cluster bulundu. Siliniyor...${NC}"
    terraform destroy -auto-approve
    check_error "Cluster silinemedi"
    log "Eski cluster başarıyla silindi"
fi

# 2. Bağımlılıkları yükle
log "Bağımlılıklar yükleniyor..."
bash "$SCRIPTS_DIR/install-dependencies.sh"
check_error "Bağımlılıkların kurulumunda hata oluştu"

# 3. Terraform ile altyapı kurulumu
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

# 4. Setup scriptini çalıştır
log "Setup script'i çalıştırılıyor..."
chmod +x "$SCRIPTS_DIR/setup.sh"
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
sleep 60  # Jenkins'in tam olarak başlaması için süreyi artıralım

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
