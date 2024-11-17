variable "host_ip" {
  description = "Host IP address for kubeconfig"
  type        = string
  default     = "192.168.1.50"
}

variable "api_port" {
  description = "API server port"
  type        = number
  default     = 6444
}
