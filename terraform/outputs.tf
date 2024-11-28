output "cluster_name" {
  value = kind_cluster.default.name
}

output "kubeconfig_path" {
  value = "~/.kube/config"
}

output "api_endpoint" {
  value = "https://${var.host_ip}:${var.api_port}"
}
