# Yerel Kubernetes Geliştirme Ortamı

## 📌 Genel Bakış
Bu proje, Terraform ile yönetilen bir Kind cluster üzerinde PostgreSQL veritabanı, Redis önbellek ve Jenkins CI/CD sistemlerini içeren tam kapsamlı bir yerel Kubernetes geliştirme ortamı sağlar.

## 📁 Proje Yapısı
```
k8s/
├── kubernetes/          # Kubernetes manifestoları
│   ├── app/            # Uygulama konfigürasyonları
│   ├── helm-charts/    # Helm chart dosyaları
│   └── job/            # Job manifestoları
├── scripts/            # Kurulum ve test scriptleri
│   ├── automated-setup.sh
│   ├── get_ip.sh
│   ├── install-dependencies.sh
│   ├── postgresql-test.sh
│   ├── redis-test.sh
│   ├── setup.sh
│   └── update-kubeconfig.sh
└── terraform/          # Terraform konfigürasyonları
```

## 🔌 Port Bilgileri
| Servis     | Port  | Erişim                          |
|------------|-------|----------------------------------|
| API        | 30080 | http://localhost:30080/swagger   |
| PostgreSQL | 30432 | localhost:30432                  |
| Redis      | 32379 | localhost:32379                  |
| Jenkins    | 32001 | http://localhost:32001           |

## 🚀 Script Açıklamaları
- `automated-setup.sh`: Tüm kurulum sürecini otomatize eden ana script
- `get_ip.sh`: Host IP adresini tespit eden yardımcı script
- `install-dependencies.sh`: Gerekli bağımlılıkları kuran script
- `postgresql-test.sh`: PostgreSQL bağlantı ve fonksiyon testleri
- `redis-test.sh`: Redis bağlantı ve fonksiyon testleri
- `setup.sh`: Kubernetes kurulumlarını yapan script
- `update-kubeconfig.sh`: Kubeconfig dosyasını güncelleyen script

## ⚙️ Kullanılan Teknolojiler
- Kind Kubernetes
- PostgreSQL 17.1.0
- Redis 7.0
- Jenkins
- .NET Core API
- Helm v3
- Terraform

## 🌐 Erişim Bilgileri
- API: http://localhost:30080/swagger
- Jenkins: http://localhost:32001
- PostgreSQL: localhost:30432
- Redis: localhost:32379

## 🔐 Güvenlik
Tüm şifreler ve hassas bilgiler Kubernetes secret'ları olarak yönetilmektedir.

Sırası ile uygulanacak komutlar 
- sudo su && apt install git && git clone --branch master https://github.com/fatihaydnrepo/k8s.git
- sudo systemctl restart docker && sleep 5 && sudo chmod 666 /var/run/docker.sock && cd /home/devops/k8s/terraform && rm -rf .terraform* terraform.tfstate* .terraform.lock.hcl && cd /home/devops/k8s/scripts && chmod +x automated-setup.sh && ./automated-setup.sh 

