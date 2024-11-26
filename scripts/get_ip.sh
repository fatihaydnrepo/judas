#!/bin/bash
# get_ip.sh - IP adresini otomatik alma ve konfigürasyon scripti

# IP adresini alma fonksiyonu
get_host_ip() {
    # Linux'ta birincil IP adresini al
    IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n 1)
    if [ -z "$IP" ]; then
        echo "IP adresi bulunamadı!"
        exit 1
    fi
    echo $IP
}

# Terraform variables dosyası oluşturma
create_terraform_vars() {
    local ip=$1
    cat > terraform.tfvars <<EOF
host_ip = "${ip}"
cluster_name = "test-cluster"
api_server_port = 6444
EOF
}

# Terraform değişken tanımları
create_terraform_variables() {
    cat > variables.tf <<EOF
variable "host_ip" {
  description = "Host machine IP address"
  type        = string
}

variable "cluster_name" {
  description = "Kind cluster name"
  type        = string
}

variable "api_server_port" {
  description = "Kubernetes API server port"
  type        = number
}
EOF
}

# Kind cluster konfigürasyonu güncelleme
update_kind_config() {
    local ip=$1
    cat > kind_config.tf <<EOF
resource "kind_cluster" "default" {
  name = var.cluster_name
  wait_for_ready = true
  kind_config {
    kind = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"
    networking {
      api_server_address = var.host_ip
      api_server_port = var.api_server_port
    }
  }
}
EOF
}


create_kubeconfig_script() {
    local ip=$1
    cat > update-kubeconfig.sh <<EOF
#!/bin/bash
# Update kubeconfig with current IP
sed -i "s/server: https:\/\/[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+/server: https:\/\/${ip}/" \$HOME/.kube/config
EOF
    chmod +x update-kubeconfig.sh
}

# Ana script
main() {
    # Host IP'sini al
    HOST_IP=$(get_host_ip)
    echo "Host IP: $HOST_IP"

    # Terraform dosyalarını güncelle
    create_terraform_vars "$HOST_IP"
    create_terraform_variables
    update_kind_config "$HOST_IP"

    # Kubeconfig güncelleme scriptini oluştur
    create_kubeconfig_script "$HOST_IP"

    echo "Tüm konfigürasyonlar başarıyla güncellendi!"
}

# Scripti çalıştır
main
