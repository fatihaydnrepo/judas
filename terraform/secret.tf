locals {
  db_password = "gDyOzQIC5L"
  redis_password = "gDyOzQIC5L"
  app_secret = "gDyOzQIC5L"
}

# PostgreSQL secret
resource "kubernetes_secret" "postgres" {
  metadata {
    name      = "postgres-postgresql"
    namespace = "demo"
  }
  data = {
    "postgres-password" = base64encode(local.db_password)
  }
}

# Redis secret
resource "kubernetes_secret" "redis" {
  metadata {
    name      = "redis"
    namespace = "demo"
  }
  data = {
    "redis-password" = base64encode(local.redis_password)
  }
}

# App secret
resource "kubernetes_secret" "app_secrets" {
  metadata {
    name      = "app-secret"
    namespace = "demo"
  }
  data = {
    "APP_SECRET" = base64encode(local.app_secret)
    "DefaultConnection" = base64encode("Host=postgres-postgresql.demo.svc.cluster.local;Database=containers;Username=postgres;Password=${local.db_password}")
    "RedisConnection"  = base64encode("redis-master.demo.svc.cluster.local:6379,password=${local.redis_password}")
  }
}
