terraform {
 required_providers {
   kind = {
     source = "tehcyx/kind"
     version = "0.4.0"
   }
   kubernetes = {
     source = "hashicorp/kubernetes"
     version = "2.33.0"
   }
 }
}

provider "kind" {}

provider "kubernetes" {
 host = "https://0.0.0.0:6444"
 insecure               = true
 client_certificate     = base64decode(yamldecode(data.local_file.kubeconfig.content).users[0].user["client-certificate-data"])
 client_key            = base64decode(yamldecode(data.local_file.kubeconfig.content).users[0].user["client-key-data"])
 #cluster_ca_certificate = base64decode(yamldecode(data.local_file.kubeconfig.content).clusters[0].cluster["certificate-authority-data"])
}

# Kubeconfig dosyasını oku
data "local_file" "kubeconfig" {
 depends_on = [null_resource.wait_for_cluster]
 filename = pathexpand("~/.kube/config")
}

resource "kind_cluster" "default" {
 name = "test-cluster"
 wait_for_ready = true
 kind_config {
   kind = "Cluster"
   api_version = "kind.x-k8s.io/v1alpha4"
   networking {
     api_server_address = "0.0.0.0"
     api_server_port = 6444
   }
   node {
     role = "control-plane"
     extra_port_mappings {
       container_port = 30432
       host_port = 30432
     }
     extra_port_mappings {
       container_port = 32379
       host_port = 32379
     }
     extra_port_mappings {
       container_port = 32001
       host_port = 32001
     }
     extra_port_mappings {
       container_port = 30080
       host_port = 30080
     }
     extra_mounts {
       host_path = "/tmp/postgresql-data"
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
