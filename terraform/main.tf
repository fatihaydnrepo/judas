resource "kind_cluster" "default" {
  name = "test-cluster"
  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    networking {
      api_server_address = "192.168.1.50"
      api_server_port    = 42105
    }

    node {
      role = "control-plane"
      extra_port_mappings {
        container_port = 80
        host_port      = 8081
      }
    }
    node {
      role = "worker"
    }
  }
}
