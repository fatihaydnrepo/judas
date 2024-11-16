
#!/bin/bash

# Helm repos
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add jenkins https://charts.jenkins.io
helm repo update

# Install PostgreSQL
cd /home/devops/k8s/kubernetes/helm-charts/postgres
helm dependency update
helm install postgres . -n demo --create-namespace

# Install Redis
cd /home/devops/k8s/kubernetes/helm-charts/redis
helm dependency update
helm install redis . -n demo

# Install Jenkins
cd /home/devops/k8s/kubernetes/helm-charts/jenkins
helm dependency update
helm install jenkins . -n demo

# Build and load app image
cd /home/devops/k8s/kubernetes/app
docker build -t demo-app:latest .
kind load docker-image demo-app:latest --name test-cluster

# Install app
cd /home/devops/k8s/kubernetes/helm-charts/app
helm install app . -n demo

# Show status
kubectl get pods -n demo
kubectl get svc -n demo
