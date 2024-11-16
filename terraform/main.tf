terraform {
 required_providers {
   kind = {
     source = "tehcyx/kind"
     version = "0.4.0"
   }
 }
}

provider "kind" {}

resource "kind_cluster" "default" {
 name = "test-cluster"
 kind_config {
   kind = "Cluster"
   api_version = "kind.x-k8s.io/v1alpha4"
   
   networking {
     api_server_address = "192.168.1.50"
     api_server_port = 42105
   }

   node {
     role = "control-plane"
   }
   
   node {
     role = "worker"
   }
 }
}
resource "null_resource" "apply_manifests" {
 depends_on = [kind_cluster.default]

 provisioner "local-exec" {
   command = <<-EOT
     cd /home/devops/k8s/kubernetes
     for file in jenkins.yaml postgres.yaml redis.yaml; do
       if [ -f "$file" ]; then
         kubectl apply -f "$file"
       fi
     done
   EOT
 }
}
