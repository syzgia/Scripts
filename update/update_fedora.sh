#!/usr/bin/env bash
set -uo pipefail

KIRMIZI='\033[0;31m'
YESIL='\033[0;32m'
SARI='\033[1;33m'
MAVI='\033[0;36m'
KALIN='\033[1m'
RESET='\033[0m'

log()    { echo -e "${MAVI}[*]${RESET} $1"; }
basari() { echo -e "${YESIL}[✓]${RESET} $1"; }
uyari()  { echo -e "${SARI}[!]${RESET} $1"; }
hata()   { echo -e "${KIRMIZI}[✗]${RESET} $1"; }
baslik() {
  echo -e "\n${KALIN}${MAVI}======================================================================${RESET}"
  echo -e "${KALIN}${MAVI} $1${RESET}"
  echo -e "${KALIN}${MAVI}======================================================================${RESET}"
}

if [[ $EUID -eq 0 ]]; then
  uyari "Bu script doğrudan 'root' olarak çalıştırılmamalıdır."
  uyari "Normal kullanıcı olarak çalıştırınız; gerekli adımlarda sudo yetkisi istenecektir."
  exit 1
fi

echo -e "${KALIN}${YESIL}"
cat << "EOF"
    ______         __                     __  __          __ate
   / ____/__  ____/ /___  _________ _    / / / /___  ____/ /___ _/ /____
  / /_  / _ \/ __  / __ \/ ___/ __ `/   / / / / __ \/ __  / __ `/ __/ _ \
 / __/ /  __/ /_/ / /_/ / /  / /_/ /   / /_/ / /_/ / /_/ / /_/ / /_/  __/
/_/    \___/\__,_/\____/_/   \__,_/    \____/ .___/\__,_/\__,_/\__/\___/
                                           /_/
EOF
echo -e "${RESET}"
log "Fedora Tam Sistem Güncellemesi Başlatılıyor..."

sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
SUDO_PID=$!
trap 'kill "$SUDO_PID" 2>/dev/null || true' EXIT

baslik "1. DNF Ayna Hızları ve İndirme Optimizasyonu"
DNF_CONF="/etc/dnf/dnf.conf"
if [ -f "$DNF_CONF" ]; then
  log "DNF ayna hızlandırma ayarları kontrol ediliyor ($DNF_CONF)..."
  if ! grep -q "^fastestmirror=True" "$DNF_CONF"; then
    echo "fastestmirror=True" | sudo tee -a "$DNF_CONF" >/dev/null
    log "fastestmirror=True eklendi."
  fi
  if ! grep -q "^max_parallel_downloads=" "$DNF_CONF"; then
    echo "max_parallel_downloads=10" | sudo tee -a "$DNF_CONF" >/dev/null
    log "max_parallel_downloads=10 eklendi."
  fi
  basari "DNF ayna ve paralel indirme ayarları optimize edildi."
fi

log "DNF önbelleği ve depolar tazeleniyor..."
sudo dnf clean all || true
sudo dnf makecache --refresh || uyari "DNF makecache uyarısı."
basari "DNF depo veritabanı yenilendi."

baslik "2. DNF Sistem Paketleri Güncelleniyor"
sudo dnf upgrade -y --refresh || uyari "Bazı paket güncellemelerinde hata oluştu."
basari "DNF sistem paketleri güncellendi."

baslik "3. Gereksiz Paket Temizliği"
log "Kullanılmayan bağımlılıklar temizleniyor (dnf autoremove)..."
sudo dnf autoremove -y || true
basari "Gereksiz paketler temizlendi."

baslik "4. Flatpak Uygulamaları ve Çalışma Zamanları"
if command -v flatpak &>/dev/null; then
  log "Flatpak paketleri güncelleniyor..."
  flatpak update -y || uyari "Flatpak güncellemesinde hata oluştu."
  log "Kullanılmayan Flatpak çalışma zamanları temizleniyor..."
  flatpak uninstall --unused -y || true
  basari "Flatpak güncellemeleri tamamlandı."
else
  log "Flatpak kurulu değil, atlandı."
fi

baslik "5. Snap Paket Güncellemeleri"
if command -v snap &>/dev/null; then
  log "Snap paketleri tazeleniyor..."
  sudo snap refresh || uyari "Snap refresh sırasında uyarı/hata oluştu."
  basari "Snap paketleri güncellendi."
else
  log "Snapd kurulu değil, atlandı."
fi

baslik "6. Nix Paket Yöneticisi Güncellemeleri"
if command -v nix-channel &>/dev/null && command -v nix-env &>/dev/null; then
  log "Nix kanalları ve paketleri güncelleniyor..."
  nix-channel --update || true
  nix-env -u '*' || true
  basari "Nix paketleri güncellendi."
else
  log "Nix kurulu değil veya profil aktif değil, atlandı."
fi

baslik "7. Pipx Uygulamaları Güncelleniyor"
if command -v pipx &>/dev/null; then
  log "pipx ile kurulu araçlar güncelleniyor..."
  pipx upgrade-all || uyari "pipx upgrade-all uyarısı."
  basari "Pipx araçları güncellendi."
else
  log "Pipx kurulu değil, atlandı."
fi

baslik "8. Distrobox Konteyner Güncellemeleri"
if command -v distrobox &>/dev/null; then
  if command -v distrobox-upgrade &>/dev/null; then
    log "Tüm distrobox konteynerleri güncelleniyor..."
    distrobox-upgrade --all || uyari "Distrobox upgrade uyarısı."
    basari "Distrobox konteynerleri güncellendi."
  elif distrobox list 2>/dev/null | grep -q "Debian"; then
    log "Distrobox Debian konteyneri güncelleniyor..."
    nohup distrobox enter Debian -- sh -c "sudo apt update && sudo apt upgrade -y" > ~/debian_guncelleme.log 2>&1 &
    basari "Distrobox Debian güncellemesi arkaplanda başlatıldı (log: ~/debian_guncelleme.log)."
  fi
else
  log "Distrobox kurulu değil, atlandı."
fi

baslik "9. Firmware (Donanım Yazılımı) Güncelleme Kontrolü"
if command -v fwupdmgr &>/dev/null; then
  log "Donanım yazılımı güncellemeleri kontrol ediliyor..."
  fwupdmgr refresh --force 2>/dev/null || true
  fwupdmgr get-updates 2>/dev/null || true
  basari "Firmware taraması tamamlandı."
fi

baslik "GÜNCELLEME TAMAMLANDI"
basari "Fedora üzerindeki tüm sistem bileşenleri ve paketler güncellendi!"
