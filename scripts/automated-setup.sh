#!/bin/bash

# Renk tanımlamaları
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

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

# Ana dizin kontrolleri
BASE_DIR="/home/devops/k8s"
SCRIPTS_DIR="$BASE_DIR/scripts"
TERRAFORM_DIR="$BASE_DIR/terraform"

if [ ! -d "$SCRIPTS_DIR" ] || [ ! -d "$TERRAFORM_DIR" ]; then
    log "${RED}HATA: Gerekli dizinler bulunamadı. Lütfen dizin yapısını kontrol edin.${NC}"
    exit 1
fi

# 1. Eğer varsa eski cluster'ı temizle
log "Eski cluster kontrol ediliyor..."
cd "$TERRAFORM_DIR" || exit 1
if kind get clusters | grep -q "test-cluster"; then
    log "${YELLOW}Eski cluster bulundu. Siliniyor...${NC}"
    terraform destroy -auto-approve
    check_error "Cluster silinemedi"
    log "Eski cluster başarıyla silindi"
fi

# 2. Bağımlılıkları yükleme
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

# 4. Setup scriptini çalıştırma
log "Setup script'i çalıştırılıyor..."
chmod +x "$SCRIPTS_DIR/setup.sh"
bash "$SCRIPTS_DIR/setup.sh"
check_error "Setup script'i çalıştırılırken hata oluştu"

# Final kontroller
log "Sistem kontrolleri yapılıyor..."
kubectl get nodes
kubectl get pods -A

# Erişim bilgileri
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')
echo -e "\n${GREEN}Erişim Bilgileri:${NC}"
echo -e "${BLUE}PostgreSQL:${NC} $NODE_IP:30432"
echo -e "${BLUE}Redis:${NC} $NODE_IP:32379"
echo -e "${BLUE}Jenkins:${NC} http://$NODE_IP:32001"
echo -e "${BLUE}Application:${NC} http://$NODE_IP:30080"

# Jenkins şifresi
echo -e "\n${YELLOW}Jenkins şifresi alınıyor...${NC}"
JENKINS_POD=$(kubectl get pods -n demo -l app=jenkins -o jsonpath='{.items[0].metadata.name}')
echo -e "${GREEN}Jenkins admin şifresi:${NC}"
kubectl exec -n demo $JENKINS_POD -- cat /var/jenkins_home/secrets/initialAdminPassword

log "Tüm işlemler başarıyla tamamlandı!"
