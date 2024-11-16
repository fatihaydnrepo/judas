#!/bin/bash
# create-cluster.sh

# Parametreleri al
EXTERNAL_IP=${1:-"192.168.1.50"}  # Varsayılan IP
CLUSTER_NAME=${2:-"test-cluster"} # Varsayılan cluster adı

# Renkli çıktılar için
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Boş port bul
find_free_port() {
    local port=6443
    while netstat -tna | grep -q ":$port "; do
        port=$((port + 1))
    done
    echo $port
}

API_PORT=$(find_free_port)

# Hata kontrolü fonksiyonu
check_error() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: $1${NC}"
        exit 1
    fi
}

echo -e "${BLUE}Creating Kubernetes Cluster with:${NC}"
echo -e "External IP: ${YELLOW}${EXTERNAL_IP}${NC}"
echo -e "API Port: ${YELLOW}${API_PORT}${NC}"
echo -e "Cluster Name: ${YELLOW}${CLUSTER_NAME}${NC}"

# Kind config oluştur
cat > kind-config.yaml << EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraMounts:
  - hostPath: /tmp/postgresql-data
    containerPath: /bitnami/postgresql
  extraPortMappings:
  - containerPort: 6443
    hostPort: ${API_PORT}
    protocol: TCP
  - containerPort: 30432
    hostPort: 30432
  - containerPort: 32379
    hostPort: 32379
  - containerPort: 32001
    hostPort: 32001
  - containerPort: 30080
    hostPort: 30080
EOF

# Host dizini oluştur
echo -e "\n${GREEN}Creating host directories...${NC}"
sudo mkdir -p /tmp/postgresql-data
sudo chmod -R 777 /tmp/postgresql-data
check_error "Failed to create host directories"

# Eski cluster'ı temizle
echo -e "\n${GREEN}Cleaning up old cluster if exists...${NC}"
kind delete cluster --name ${CLUSTER_NAME} 2>/dev/null || true

# Docker ağını temizle
docker network prune -f

# Yeni cluster oluştur
echo -e "\n${GREEN}Creating new cluster...${NC}"
kind create cluster --name ${CLUSTER_NAME} --config kind-config.yaml
check_error "Failed to create cluster"

# Kubeconfig'i güncelle
echo -e "\n${GREEN}Updating kubeconfig for external access...${NC}"
cat > ~/.kube/config << EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: https://${EXTERNAL_IP}:${API_PORT}
  name: ${CLUSTER_NAME}
contexts:
- context:
    cluster: ${CLUSTER_NAME}
    user: ${CLUSTER_NAME}
  name: ${CLUSTER_NAME}
current-context: ${CLUSTER_NAME}
users:
- name: ${CLUSTER_NAME}
  user:
    client-certificate-data: $(kind get kubeconfig --name ${CLUSTER_NAME} | grep client-certificate-data | awk '{print $2}')
    client-key-data: $(kind get kubeconfig --name ${CLUSTER_NAME} | grep client-key-data | awk '{print $2}')
EOF

chmod 600 ~/.kube/config
check_error "Failed to update kubeconfig"

# Bağlantıyı test et
echo -e "\n${BLUE}Testing cluster connection:${NC}"
kubectl cluster-info

echo -e "\n${GREEN}Cluster created successfully!${NC}"
echo -e "\n${BLUE}Cluster Information:${NC}"
echo -e "API Server: ${YELLOW}https://${EXTERNAL_IP}:${API_PORT}${NC}"
echo -e "Kubeconfig Location: ${YELLOW}~/.kube/config${NC}"
echo -e "\n${GREEN}You can now use Lens to connect to your cluster.${NC}"
echo -e "${GREEN}Run setup.sh to install applications.${NC}"
