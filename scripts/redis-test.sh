#!/bin/bash

# Renk tanımlamaları
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}🚀 Starting Redis Health Check - $(date)${NC}"
echo -e "${BLUE}=========================================${NC}"

# Redis test pod oluştur
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
 name: redis-test
 namespace: demo
spec:
 containers:
 - name: redis-test
   image: redis:latest
   command: ['sleep', '600']
EOF

# Pod'un hazır olmasını bekle
echo -e "${BLUE}⏳ Waiting for test pod to be ready...${NC}"
kubectl wait --for=condition=ready pod/redis-test -n demo --timeout=30s

# Redis parolasını al
REDIS_PASSWORD=$(kubectl get secret -n demo redis -o jsonpath='{.data.redis-password}' | base64 -d)
if [ -z "$REDIS_PASSWORD" ]; then
   echo -e "${RED}❌ Error: Redis password not found!${NC}"
   exit 1
fi

# Redis komutlarını çalıştırmak için fonksiyon
redis_cmd() {
   kubectl exec -n demo redis-test -- /bin/bash -c "export REDISCLI_AUTH='$REDIS_PASSWORD'; redis-cli -h redis-master $1"
}

# Temel bağlantı testi
echo -e "\n${BLUE}📡 Testing Redis Connection...${NC}"
redis_cmd "ping"

# Redis server bilgileri
echo -e "\n${YELLOW}📊 Redis Server Information:${NC}"
echo -e "${BLUE}----------------------------------------${NC}"
redis_cmd "info server"

# Memory kullanımı
echo -e "\n${YELLOW}💾 Memory Usage Details:${NC}"
echo -e "${BLUE}----------------------------------------${NC}"
redis_cmd "info memory"

# Client bilgileri
echo -e "\n${YELLOW}👥 Connected Clients Information:${NC}"
echo -e "${BLUE}----------------------------------------${NC}"
redis_cmd "info clients"

# Test verisi oluştur
echo -e "\n${YELLOW}📝 Creating Test Data...${NC}"
echo -e "${BLUE}----------------------------------------${NC}"
for i in {1..5}; do
   redis_cmd "set test-key-$i test-value-$i"
done
echo -e "${GREEN}✅ Test data created${NC}"

# Hash veri yapısı testi
echo -e "\n${YELLOW}🔨 Testing Hash Data Structure...${NC}"
echo -e "${BLUE}----------------------------------------${NC}"
redis_cmd "hset user:1 username john age 30 city 'New York'"
echo -e "${GREEN}Hash data created. Getting hash fields:${NC}"
redis_cmd "hgetall user:1"

# List veri yapısı testi
echo -e "\n${YELLOW}📋 Testing List Data Structure...${NC}"
echo -e "${BLUE}----------------------------------------${NC}"
for i in {1..5}; do
   redis_cmd "lpush mylist item-$i"
done
echo -e "${GREEN}List data created. Getting list items:${NC}"
redis_cmd "lrange mylist 0 -1"

# Set veri yapısı testi
echo -e "\n${YELLOW}🎯 Testing Set Data Structure...${NC}"
echo -e "${BLUE}----------------------------------------${NC}"
for i in {1..5}; do
   redis_cmd "sadd myset member-$i"
done
echo -e "${GREEN}Set data created. Getting set members:${NC}"
redis_cmd "smembers myset"

# Sorted Set veri yapısı testi
echo -e "\n${YELLOW}🏆 Testing Sorted Set Data Structure...${NC}"
echo -e "${BLUE}----------------------------------------${NC}"
for i in {1..5}; do
   redis_cmd "zadd leaderboard $i player-$i"
done
echo -e "${GREEN}Sorted set data created. Getting sorted set with scores:${NC}"
redis_cmd "zrange leaderboard 0 -1 withscores"

# Tüm keyleri listele
echo -e "\n${YELLOW}🔑 All Keys in Redis:${NC}"
echo -e "${BLUE}----------------------------------------${NC}"
redis_cmd "keys *"

# Redis statistics
echo -e "\n${YELLOW}📈 Redis Statistics:${NC}"
echo -e "${BLUE}----------------------------------------${NC}"
redis_cmd "info stats"

# Database size
echo -e "\n${YELLOW}📊 Database Size:${NC}"
echo -e "${BLUE}----------------------------------------${NC}"
redis_cmd "dbsize"

# Persistence bilgisi
echo -e "\n${YELLOW}💾 Persistence Information:${NC}"
echo -e "${BLUE}----------------------------------------${NC}"
redis_cmd "info persistence"

# Replication bilgisi
echo -e "\n${YELLOW}🔄 Replication Information:${NC}"
echo -e "${BLUE}----------------------------------------${NC}"
redis_cmd "info replication"

# Test verilerini temizle
echo -e "\n${YELLOW}🧹 Cleaning Test Data...${NC}"
echo -e "${BLUE}----------------------------------------${NC}"
redis_cmd "del test-key-1 test-key-2 test-key-3 test-key-4 test-key-5 user:1 mylist myset leaderboard"
echo -e "${GREEN}✅ Test data cleaned${NC}"

# Test pod'unu temizle
echo -e "\n${BLUE}🧹 Cleaning up test pod...${NC}"
kubectl delete pod redis-test -n demo

echo -e "\n${BLUE}=========================================${NC}"
echo -e "${GREEN}✅ Redis Health Check Completed Successfully - $(date)${NC}"
echo -e "${BLUE}=========================================${NC}"
