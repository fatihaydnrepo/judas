#!/bin/bash

# Renkli çıktılar için
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'


HOST_IP=${1:-"192.168.1.103"}
PORT=${2:-"6444"}

echo -e "${BLUE}Updating kubeconfig with host IP: $HOST_IP and port: $PORT${NC}"

# Geçici dosyayı oluştur
kind get kubeconfig --name test-cluster > /tmp/kube_temp

# IP ve port'u güncelle
cat /tmp/kube_temp | \
    sed "s|server: https://.*|server: https://$HOST_IP:$PORT|g" | \
    sed 's|certificate-authority-data:.*|insecure-skip-tls-verify: true|g' > /tmp/kube_final

# Kubeconfig'i güncelle
mkdir -p ~/.kube
cp /tmp/kube_final ~/.kube/config
chmod 600 ~/.kube/config

# Geçici dosyaları temizle
rm /tmp/kube_temp /tmp/kube_final

echo -e "${GREEN}Kubeconfig updated successfully${NC}"
