locals {
  # Base64 encoded şifreyi decode et
  encoded_password = "Z0R5T3pRSUM1TA=="
  decoded_password = base64decode(local.encoded_password)

  db_connection = "Host=postgres-postgresql.demo.svc.cluster.local;Database=containers;Username=postgres;Password=Z0R5T3pRSUM1TA=="
  redis_connection = "redis-master.demo.svc.cluster.local:6379,password=Z0R5T3pRSUM1TA=="
}

resource "kubernetes_secret" "postgres" {
  metadata {
    name      = "postgres-postgresql"
    namespace = "demo"
  }
  data = {
    "postgres-password" = local.encoded_password  
  }
}

resource "kubernetes_secret" "redis" {
  metadata {
    name      = "redis"
    namespace = "demo"
  }
  data = {
    "redis-password" = local.encoded_password 
  }
}

resource "kubernetes_secret" "app_secret" {
  metadata {
    name      = "app-secret"
    namespace = "demo"
  }
  data = {
    "DefaultConnection" = base64encode(local.db_connection)
    "RedisConnection"  = base64encode(local.redis_connection)
    "app-secret" = local.encoded_password  # Zaten encoded
  }
}
