#!/bin/bash

# Renk tanımlamaları
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}🚀 Starting PostgreSQL Health Check - $(date)${NC}"
echo -e "${BLUE}=========================================${NC}"

# PostgreSQL test pod oluştur
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
 name: postgres-test
 namespace: demo
spec:
 containers:
 - name: postgres-test
   image: bitnami/postgresql:17.1.0
   command: ['sleep', '600']
   env:
   - name: PGHOST
     value: "postgres-postgresql"
   - name: PGPORT
     value: "5432"
   - name: PGUSER
     value: "postgres"
   - name: PGDATABASE
     value: "containers"
   - name: PGPASSWORD
     valueFrom:
       secretKeyRef:
         name: postgres-postgresql
         key: postgres-password
EOF

# Pod'un hazır olmasını bekle
echo -e "${BLUE}⏳ Waiting for test pod to be ready...${NC}"
kubectl wait --for=condition=ready pod/postgres-test -n demo --timeout=30s

# PostgreSQL komutlarını çalıştırmak için fonksiyon
pg_cmd() {
   kubectl exec -n demo postgres-test -- psql -c "$1"
}

# Bağlantı testi
echo -e "\n${YELLOW}📡 Testing PostgreSQL Connection...${NC}"
echo -e "${BLUE}----------------------------------------${NC}"
pg_cmd "\conninfo"

# PostgreSQL versiyon bilgisi
echo -e "\n${YELLOW}ℹ️ PostgreSQL Version:${NC}"
echo -e "${BLUE}----------------------------------------${NC}"
pg_cmd "SELECT version();"

# Database listesi
echo -e "\n${YELLOW}📚 Database List:${NC}"
echo -e "${BLUE}----------------------------------------${NC}"
pg_cmd "\l"

# Mevcut bağlantılar
echo -e "\n${YELLOW}👥 Current Connections:${NC}"
echo -e "${BLUE}----------------------------------------${NC}"
pg_cmd "SELECT datname, usename, client_addr, client_port, backend_start FROM pg_stat_activity;"

# Tablo boyutları
echo -e "\n${YELLOW}📊 Table Sizes:${NC}"
echo -e "${BLUE}----------------------------------------${NC}"
pg_cmd "SELECT relname as table_name, pg_size_pretty(pg_total_relation_size(relid)) as total_size FROM pg_catalog.pg_statio_user_tables ORDER BY pg_total_relation_size(relid) DESC;"

# Test tablosu oluştur
echo -e "\n${YELLOW}🔨 Creating Test Table...${NC}"
echo -e "${BLUE}----------------------------------------${NC}"
pg_cmd "CREATE TABLE IF NOT EXISTS test_table (
   id SERIAL PRIMARY KEY,
   name VARCHAR(50),
   created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);"

# Test verisi ekle
echo -e "\n${YELLOW}📝 Inserting Test Data...${NC}"
echo -e "${BLUE}----------------------------------------${NC}"
for i in {1..5}; do
   pg_cmd "INSERT INTO test_table (name) VALUES ('Test Data $i');"
done

# Verileri sorgula
echo -e "\n${YELLOW}🔍 Querying Test Data:${NC}"
echo -e "${BLUE}----------------------------------------${NC}"
pg_cmd "SELECT * FROM test_table;"

# İndeks bilgileri
echo -e "\n${YELLOW}📇 Index Information:${NC}"
echo -e "${BLUE}----------------------------------------${NC}"
pg_cmd "\di+ test_table*"

# Tablo istatistikleri
echo -e "\n${YELLOW}📈 Table Statistics:${NC}"
echo -e "${BLUE}----------------------------------------${NC}"
pg_cmd "SELECT schemaname, relname, n_live_tup, n_dead_tup, last_autovacuum 
FROM pg_stat_user_tables WHERE relname = 'test_table';"

# Transaction istatistikleri
echo -e "\n${YELLOW}🔄 Transaction Statistics:${NC}"
echo -e "${BLUE}----------------------------------------${NC}"
pg_cmd "SELECT xact_commit, xact_rollback, blks_read, blks_hit, tup_returned, tup_fetched, tup_inserted, tup_updated, tup_deleted 
FROM pg_stat_database WHERE datname = current_database();"

# Lock bilgileri
echo -e "\n${YELLOW}🔒 Lock Information:${NC}"
echo -e "${BLUE}----------------------------------------${NC}"
pg_cmd "SELECT locktype, relation::regclass, mode, granted FROM pg_locks WHERE relation::regclass::text LIKE 'test_table%';"

# Vacuum ve analyze durumu
echo -e "\n${YELLOW}🧹 Vacuum Status:${NC}"
echo -e "${BLUE}----------------------------------------${NC}"
pg_cmd "SELECT relname, last_vacuum, last_autovacuum, last_analyze, last_autoanalyze 
FROM pg_stat_user_tables WHERE relname = 'test_table';"

# Settings
echo -e "\n${YELLOW}⚙️ Important Settings:${NC}"
echo -e "${BLUE}----------------------------------------${NC}"
pg_cmd "SELECT name, setting, unit, context FROM pg_settings 
WHERE name IN ('max_connections', 'shared_buffers', 'work_mem', 'maintenance_work_mem');"

# Test tablosunu temizle
echo -e "\n${YELLOW}🧹 Cleaning Test Table...${NC}"
echo -e "${BLUE}----------------------------------------${NC}"
pg_cmd "DROP TABLE IF EXISTS test_table;"

# Test pod'unu temizle
echo -e "\n${BLUE}🧹 Cleaning up test pod...${NC}"
kubectl delete pod postgres-test -n demo

echo -e "\n${BLUE}=========================================${NC}"
echo -e "${GREEN}✅ PostgreSQL Health Check Completed Successfully - $(date)${NC}"
echo -e "${BLUE}=========================================${NC}"
