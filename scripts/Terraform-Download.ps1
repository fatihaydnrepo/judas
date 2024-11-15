# kind Kurulum Scripti

# kind sürümünü belirleyin (Güncel sürüm için GitHub sayfasını kontrol edebilirsiniz)
$kindVersion = "v0.20.0" 
$kindDownloadUrl = "https://github.com/kubernetes-sigs/kind/releases/download/$kindVersion/kind-windows-amd64"
$installPath = "C:\Program Files\kind"

# Kurulum dizini varsa, varsa oluştur
if (!(Test-Path -Path $installPath)) {
    New-Item -ItemType Directory -Force -Path $installPath
}

# kind'i İndir
$kindExePath = "$installPath\kind.exe"
Write-Output "kind $kindVersion sürümü indiriliyor..."
Invoke-WebRequest -Uri $kindDownloadUrl -OutFile $kindExePath

# İndirme tamamlandıktan sonra dosyayı çalıştırılabilir hale getirin (gerekirse)
If (!(Test-Path -Path $kindExePath)) {
    Write-Output "kind indirilemedi. Lütfen URL'yi ve internet bağlantınızı kontrol edin."
    exit
}

# PATH'e Ekle
$envPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
if ($envPath -notlike "*$installPath*") {
    Write-Output "kind dizini sistem PATH'ine ekleniyor..."
    [System.Environment]::SetEnvironmentVariable("Path", "$envPath;$installPath", [System.EnvironmentVariableTarget]::Machine)
}

Write-Output "kind kurulumu tamamlandı. Değişikliklerin geçerli olması için terminali yeniden başlatın."

# Kurulumu test et
Write-Output "Kurulumu test etmek için 'kind version' komutunu çalıştırabilirsiniz."
