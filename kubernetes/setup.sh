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

# Create namespace
echo -e "${GREEN}Creating namespace...${NC}"
kubectl create namespace demo

# Install PostgreSQL
echo -e "${GREEN}Installing PostgreSQL...${NC}"
cd /home/devops/k8s/kubernetes/helm-charts/postgres
helm install postgres bitnami/postgresql -f values.yaml -n demo

# Install Redis
echo -e "${GREEN}Installing Redis...${NC}"
cd ../redis
helm install redis bitnami/redis -f values.yaml -n demo

# Install Jenkins with simple configuration
echo -e "${GREEN}Installing Jenkins...${NC}"
cat > jenkins-deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jenkins
  namespace: demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jenkins
  template:
    metadata:
      labels:
        app: jenkins
    spec:
      securityContext:
        runAsUser: 0
        fsGroup: 0
      containers:
      - name: jenkins
        image: jenkins/jenkins:2.414.2-lts
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8080
          name: httpport
        - containerPort: 50000
          name: jnlpport
        securityContext:
          allowPrivilegeEscalation: true
        volumeMounts:
        - name: jenkins-data
          mountPath: /var/jenkins_home
      volumes:
      - name: jenkins-data
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: jenkins
  namespace: demo
spec:
  type: NodePort
  ports:
    - port: 8080
      targetPort: 8080
      nodePort: 32001
      name: http
    - port: 50000
      targetPort: 50000
      name: agent
  selector:
    app: jenkins
EOF

kubectl apply -f jenkins-deployment.yaml

# Wait for PostgreSQL to be ready
echo -e "${GREEN}Waiting for PostgreSQL to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgresql -n demo --timeout=120s

# Get PostgreSQL password
POSTGRES_PASSWORD=$(kubectl get secret --namespace demo postgres-postgresql -o jsonpath="{.data.postgres-password}" | base64 -d)

# Create databases
echo -e "${GREEN}Creating PostgreSQL databases...${NC}"
for db in containers accounts routes; do
    kubectl run postgres-client-$db --rm --tty -i --restart='Never' --namespace demo \
    --image docker.io/bitnami/postgresql:17.1.0-debian-12-r0 \
    --env="PGPASSWORD=$POSTGRES_PASSWORD" \
    --command -- psql --host postgres-postgresql -U postgres -d postgres -p 5432 \
    -c "CREATE DATABASE $db;" || true
done

# Create app secret
echo -e "${GREEN}Creating application secrets...${NC}"
kubectl create secret generic app-secret \
  --namespace demo \
  --from-literal=DefaultConnection="Host=postgres-postgresql;Database=containers;Username=postgres;Password=$POSTGRES_PASSWORD" \
  --from-literal=RedisConnection="redis-master:6379,password=devops"

# Build and load app image
echo -e "${GREEN}Building and loading application image...${NC}"
cd /home/devops/k8s/kubernetes/app
docker build -t app:latest .
kind load docker-image app:latest --name test-cluster

# Install app
echo -e "${GREEN}Installing application...${NC}"
cd ../helm-charts/app
helm install app . -n demo

# Wait for all services
echo -e "${GREEN}Waiting for all services to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app=jenkins -n demo --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=redis -n demo --timeout=300s

# Show status
echo -e "${GREEN}Deployment complete! Current status:${NC}"
echo -e "${BLUE}Pods:${NC}"
kubectl get pods -n demo
echo -e "${BLUE}Services:${NC}"
kubectl get svc -n demo

# Print access information
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')
echo -e "\n${GREEN}Access Information:${NC}"
echo -e "${BLUE}PostgreSQL:${NC} $NODE_IP:30432 (User: postgres, Password: $POSTGRES_PASSWORD)"
echo -e "${BLUE}Redis:${NC} $NODE_IP:32379 (Password: devops)"
echo -e "${BLUE}Jenkins:${NC} http://$NODE_IP:32001"
echo -e "${BLUE}Application:${NC} http://$NODE_IP:30080"

# Print Jenkins initial password when it's ready
echo -e "\n${YELLOW}Waiting for Jenkins to start and getting initial admin password...${NC}"
sleep 30
kubectl exec -n demo $(kubectl get pods -n demo -l app=jenkins -o jsonpath='{.items[0].metadata.name}') -- cat /var/jenkins_home/secrets/initialAdminPassword
