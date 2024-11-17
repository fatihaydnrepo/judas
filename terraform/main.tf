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

resource "null_resource" "update_kubeconfig" {
  depends_on = [kind_cluster.default]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      echo "Creating temporary files..."
      kind get kubeconfig --name test-cluster > /tmp/kube_temp
      echo "Generated temp kubeconfig:"
      cat /tmp/kube_temp
      echo "Updating configuration..."
      cat /tmp/kube_temp | sed 's|server: https://0.0.0.0:6444|server: https://192.168.1.50:6444|g' | sed 's|certificate-authority-data:.*|insecure-skip-tls-verify: true|g' > /tmp/kube_final
      echo "Final configuration:"
      cat /tmp/kube_final
      echo "Moving to ~/.kube/config..."
      mkdir -p ~/.kube
      cp /tmp/kube_final ~/.kube/config
      chmod 600 ~/.kube/config
      echo "Cleanup..."
      rm /tmp/kube_temp /tmp/kube_final
      echo "Done. Current kubeconfig:"
      cat ~/.kube/config
    EOT
  }
}
