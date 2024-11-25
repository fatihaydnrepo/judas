#!/bin/bash

set -e

echo "🚀 Starting installation of development environment tools..."

# Git Installation
echo "📦 Installing Git..."
sudo apt-get update
sudo apt-get install -y git

# Kind CLI'nin indirilmesi
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Doğrulama
if kind --version &> /dev/null; then
  echo -e "${GREEN}✅ Kind CLI installed successfully!${NC}"
else
  echo -e "${RED}❌ Kind CLI installation failed.${NC}"
  exit 1
fi

# Docker Installation
echo "🐳 Installing Docker..."
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Terraform Installation
echo "🏗️ Installing Terraform..."
sudo apt-get install -y snapd
sudo snap install terraform --classic

# Helm Installation
echo "⎈ Installing Helm..."
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt-get install -y apt-transport-https
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | \
  sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install -y helm

#Kubectl Installation
echo "☸️ Installing Kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
echo "$(cat kubectl.sha256) kubectl" | sha256sum --check
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl kubectl.sha256


# Print versions for verification
echo -e "\n📌 Verifying installations..."
echo "Git version: $(git --version)"
echo "Docker version: $(docker --version)"
echo "Terraform version: $(terraform --version)"
echo "Helm version: $(helm version)"
echo "Kubectl version: $(kubectl version --client)"

echo "✅ All tools have been installed successfully!"
