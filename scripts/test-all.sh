#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Get node IP
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')

echo "🔍 Testing all services..."
echo "Using Node IP: $NODE_IP"

# PostgreSQL test
echo -n "Testing PostgreSQL... "
if PGPASSWORD=devops psql -h $NODE_IP -p 30432 -U devops -d containers -c "\l" &> /dev/null; then
    echo -e "${GREEN}✓ Connected${NC}"
else
    echo -e "${RED}✗ Failed${NC}"
    echo "PostgreSQL connection details:"
    kubectl get svc -n postgres
fi

# Redis test
echo -n "Testing Redis... "
if redis-cli -h $NODE_IP -p 32379 -a devops PING | grep -q "PONG"; then
    echo -e "${GREEN}✓ Connected${NC}"
else
    echo -e "${RED}✗ Failed${NC}"
    echo "Redis connection details:"
    kubectl get svc -n redis
fi

# Jenkins test
echo -n "Testing Jenkins... "
if curl -s -I http://$NODE_IP:32000 | grep -q "403\|200"; then
    echo -e "${GREEN}✓ Connected${NC}"
else
    echo -e "${RED}✗ Failed${NC}"
    echo "Jenkins connection details:"
    kubectl get svc -n jenkins
fi

# Kubernetes cluster status
echo -e "\n📊 Cluster Status:"
echo "-------------------"
kubectl get nodes

echo -e "\n🔧 Pods Status:"
echo "-------------------"
kubectl get pods -A

# Service ports check
echo -e "\n🔌 Service Ports:"
echo "-------------------"
echo "PostgreSQL: $(kubectl get svc -n postgres postgres -o jsonpath='{.spec.ports[0].nodePort}')"
echo "Redis: $(kubectl get svc -n redis redis-master -o jsonpath='{.spec.ports[0].nodePort}')"
echo "Jenkins: $(kubectl get svc -n jenkins jenkins -o jsonpath='{.spec.ports[0].nodePort}')"
