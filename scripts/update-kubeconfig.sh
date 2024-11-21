#!/bin/bash
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# IP parametresi kontrolü
HOST_IP=${1:-$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n 1)}
PORT=${2:-"6444"}

echo -e "${BLUE}Updating kubeconfig with host IP: $HOST_IP and port: $PORT${NC}"

# Yedek oluştur
cp ~/.kube/config ~/.kube/config.backup 2>/dev/null || true

# Kind cluster kubeconfig'ini al ve direkt güncelle
kind get kubeconfig --name test-cluster | \
    sed -E "s|server: https://[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+|server: https://${HOST_IP}:${PORT}|g" | \
    sed 's|certificate-authority-data:.*|insecure-skip-tls-verify: true|g' > ~/.kube/config

# İzinleri ayarla
chmod 600 ~/.kube/config

# Doğrulama
if grep -q "server: https://${HOST_IP}:${PORT}" ~/.kube/config; then
    echo -e "${GREEN}Kubeconfig updated successfully${NC}"
    echo "New server configuration:"
    grep "server: " ~/.kube/config
else
    echo "Update failed. Restoring backup..."
    [ -f ~/.kube/config.backup ] && cp ~/.kube/config.backup ~/.kube/config
    exit 1
fi
