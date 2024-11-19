variable "host_ip" {
  description = "Host machine IP address"
  type        = string
  default     = "0.0.0.0"  # Default değer, script ile güncellenecek
}

variable "api_port" {
  description = "Kubernetes API server port"
  type        = number
  default     = 6444
}

variable "cluster_name" {
  description = "Kind cluster name"
  type        = string
  default     = "test-cluster"
}
