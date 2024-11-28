#!/bin/bash
# Renkli çıktılar için
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}Starting deployment...${NC}"

# Helm repos
echo -e "${GREEN}Adding Helm repositories...${NC}"
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Install PostgreSQL
echo -e "${GREEN}Installing PostgreSQL...${NC}"
cd /home/devops/k8s/kubernetes/helm-charts/postgres
helm dependency update
helm install postgres bitnami/postgresql -f values.yaml -n demo

# Install Redis
echo -e "${GREEN}Installing Redis...${NC}"
cd ../redis
helm dependency update
helm install redis bitnami/redis -f values.yaml -n demo

# Install Jenkins
echo -e "${GREEN}Installing Jenkins...${NC}"
cd ../jenkins
helm install jenkins . -f values.yaml -n demo
cd /home/devops/k8s/kubernetes/helm-charts/jenkins/templates
kubectl apply -f  jenkins-sa.yaml -n demo


# Apply Jobs
echo -e "${GREEN}Creating Jobs...${NC}"
cd /home/devops/k8s/kubernetes/job
kubectl apply -f postgres-backup.yaml -n demo
kubectl apply -f postgresl-test-script.yaml -n demo
kubectl apply -f redis-test-script.yaml -n demo

# Build and load app image
echo -e "${GREEN}Building and loading application image...${NC}"
cd /home/devops/k8s/kubernetes/app
docker build -t app:latest .
kind load docker-image app:latest --name test-cluster

# Install app
echo -e "${GREEN}Installing application...${NC}"
cd /home/devops/k8s/kubernetes/helm-charts/app
helm install app . -n demo -f values.yaml

# Show status
echo -e "${GREEN}Deployment complete! Current status:${NC}"
echo -e "${BLUE}Pods:${NC}"
kubectl get pods -n demo
echo -e "${BLUE}Services:${NC}"
kubectl get svc -n demo

# Print access information
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')
echo -e "\n${GREEN}Access Information:${NC}"
echo -e "${BLUE}PostgreSQL:${NC} $NODE_IP:30432"
echo -e "${BLUE}Redis:${NC} $NODE_IP:32379"
echo -e "${BLUE}Jenkins:${NC} http://$NODE_IP:32001"
echo -e "${BLUE}Application:${NC} http://$NODE_IP:30080"

# Wait for Jenkins and get initial admin password
echo -e "\n${YELLOW}Waiting for Jenkins to start and getting initial admin password...${NC}"
sleep 30
JENKINS_POD=$(kubectl get pods -n demo -l app=jenkins -o jsonpath='{.items[0].metadata.name}')
echo -e "${GREEN}Jenkins admin password:${NC}"
kubectl exec -n demo $JENKINS_POD -- cat /var/jenkins_home/secrets/initialAdminPassword
