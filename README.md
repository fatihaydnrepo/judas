# 🚀 Yerel Kubernetes Geliştirme Ortamı

## 📌 Genel Bakış
Bu proje, Terraform ile yönetilen bir Kind cluster üzerinde PostgreSQL veritabanı, Redis önbellek ve Jenkins CI/CD sistemlerini içeren kapsamlı bir yerel Kubernetes geliştirme ortamı sunar.

## 🛠️ Hızlı Başlangıç

### Kurulum
```bash
# Repository'yi klonla
apt install git && git clone --branch master https://github.com/fatihaydnrepo/k8s.git

# Kurulum scriptini çalıştır
cd /home/devops/k8s/scripts && chmod +x automated-setup.sh &&./automated-setup.sh
```

### Test İşlemleri
```bash
# Redis bağlantı testi
./redis-test.sh

# PostgreSQL bağlantı testi
./postgresql-test.sh
```

## 📁 Proje Yapısı
```plaintext
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

## 🔌 Servis Port Bilgileri

| Servis     | Port  | URL                             | Açıklama                    |
|------------|-------|--------------------------------|----------------------------|
| API        | 30080 | http://localhost:30080/swagger | REST API ve Swagger UI     |
| PostgreSQL | 30432 | postgresql://localhost:30432   | PostgreSQL 17.1.0 Veritabanı |
| Redis      | 32379 | redis://localhost:32379        | Redis 7.0 Önbellek         |
| Jenkins    | 32001 | http://localhost:32001         | Jenkins CI/CD Arayüzü      |

## 🚀 Script Detayları

| Script | Açıklama |
|--------|----------|
| `automated-setup.sh` | Ana kurulum scripti - Tüm ortamı otomatik yapılandırır |
| `get_ip.sh` | Host IP tespiti için yardımcı script |
| `install-dependencies.sh` | Sistem bağımlılıklarını kurar (Docker, Kind, Kubectl, vb.) |
| `postgresql-test.sh` | PostgreSQL bağlantı ve fonksiyon testleri yapar |
| `redis-test.sh` | Redis bağlantı ve fonksiyon testleri yapar |
| `setup.sh` | Kubernetes servislerini ve uygulamaları kurar |
| `update-kubeconfig.sh` | Kubeconfig yapılandırmasını günceller |

## ⚙️ Kullanılan Teknolojiler

- **Konteynerizasyon & Orkestrasyon**
  - Kind Kubernetes
  - Docker
  - Helm v3

- **Veritabanları & Önbellek**
  - PostgreSQL 17.1.0
  - Redis 7.0

- **CI/CD & Altyapı**
  - Jenkins
  - Terraform

- **Uygulama**
  - .NET Core API
  - Swagger UI

## 🔐 Güvenlik Notları

- Tüm hassas bilgiler Kubernetes Secrets içinde şifrelenmiş olarak saklanır
- Servis portları yalnızca localhost üzerinden erişilebilir
- Jenkins admin şifresi ilk kurulumda otomatik oluşturulur
- Veritabanı ve Redis kimlik bilgileri güvenli bir şekilde yapılandırılır



