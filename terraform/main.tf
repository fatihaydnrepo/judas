terraform {
  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "0.4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.33.0"
    }
  }
}

provider "kind" {}

provider "kubernetes" {
  host                = "https://${var.host_ip}:${var.api_port}"
  insecure            = true
  client_certificate  = base64decode(yamldecode(data.local_file.kubeconfig.content).users[0].user["client-certificate-data"])
  client_key          = base64decode(yamldecode(data.local_file.kubeconfig.content).users[0].user["client-key-data"])
}

# Kubeconfig dosyasını oku
data "local_file" "kubeconfig" {
  depends_on = [null_resource.wait_for_cluster]
  filename   = pathexpand("~/.kube/config")
}

resource "kind_cluster" "default" {
  name           = var.cluster_name
  wait_for_ready = true
  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"
    
    networking {
      api_server_address = var.host_ip
      api_server_port    = var.api_port
    }

    node {
      role = "control-plane"
      
      dynamic "extra_port_mappings" {
        for_each = {
          postgresql = { container_port = 30432, host_port = 30432 }
          redis     = { container_port = 32379, host_port = 32379 }
          jenkins   = { container_port = 32001, host_port = 32001 }
          api       = { container_port = 30080, host_port = 30080 }
        }
        content {
          container_port = extra_port_mappings.value.container_port
          host_port     = extra_port_mappings.value.host_port
          listen_address = var.host_ip  # Her port için dinleme adresi
        }
      }

      extra_mounts {
        host_path      = "/tmp/postgresql-data"
        container_path = "/bitnami/postgresql"
      }
    }
  }
}

resource "null_resource" "wait_for_cluster" {
  depends_on = [kind_cluster.default]
  
  provisioner "local-exec" {
    command = "/home/devops/k8s/scripts/update-kubeconfig.sh"
  }
}

resource "kubernetes_namespace" "demo" {
  depends_on = [data.local_file.kubeconfig]
  
  metadata {
    name = "demo"
  }
}
