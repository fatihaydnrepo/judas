locals {
  # Düz şifreyi direkt kullan, Kubernetes secret data field'ı otomatik encode edecek
  redis_password = base64decode("Z0R5T3pRSUM1TA==")  # Decode edilmiş hali
  db_connection = "Host=postgres-postgresql.demo.svc.cluster.local;Database=containers;Username=postgres;Password=${base64decode("Z0R5T3pRSUM1TA==")}"
  redis_connection = "redis-master.demo.svc.cluster.local:6379,password=${base64decode("Z0R5T3pRSUM1TA==")}"
}

resource "kubernetes_secret" "postgres" {
  metadata {
    name      = "postgres-postgresql"
    namespace = "demo"
  }
  data = {
    "postgres-password" = local.redis_password  # Düz şifre, Kubernetes otomatik encode edecek
  }
}

resource "kubernetes_secret" "redis" {
  metadata {
    name      = "redis"
    namespace = "demo"
  }
  data = {
    "redis-password" = local.redis_password  # Düz şifre, Kubernetes otomatik encode edecek
  }
}

resource "kubernetes_secret" "app_secret" {
  metadata {
    name      = "app-secret"
    namespace = "demo"
  }
  data = {
    "DefaultConnection" = local.db_connection
    "RedisConnection"  = local.redis_connection
    "app-secret" = local.redis_password  # Düz şifre, Kubernetes otomatik encode edecek
  }
}
