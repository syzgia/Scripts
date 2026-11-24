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
   ______           __            ____  _____   __  __          __ate
  / ____/___ ______/ /_  __  __  / __ \/ ___/  / / / /___  ____/ /___ _/ /____
 / /   / __ `/ ___/ __ \/ / / / / / / /\__ \  / / / / __ \/ __  / __ `/ __/ _ \
/ /___/ /_/ / /__/ / / / /_/ / / /_/ /___/ / / /_/ / /_/ / /_/ / /_/ / /_/  __/
\____/\__,_/\___/_/ /_/\__, /  \____//____/  \____/ .___/\__,_/\__,_/\__/\___/
                      /____/                     /_/
EOF
echo -e "${RESET}"
log "CachyOS Tam Sistem Güncellemesi Başlatılıyor..."

# Otomatik çalışmada sudo kimlik doğrulaması yapılmaz; gerekli komutlar
# /etc/sudoers.d/90-update-cachyos üzerinden şifresiz çalışır.
if [[ "${CACHYOS_AUTO:-0}" != "1" ]]; then
  sudo -v
  while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
  SUDO_PID=$!
  trap 'kill "$SUDO_PID" 2>/dev/null || true' EXIT
fi

baslik "1. Ayna Hızları Optimizasyonu"
if command -v cachyos-rate-mirrors &>/dev/null; then
  log "cachyos-rate-mirrors çalıştırılıyor..."
  sudo cachyos-rate-mirrors || uyari "cachyos-rate-mirrors uyarısı."
  basari "CachyOS aynaları optimize edildi."
elif command -v rate-mirrors &>/dev/null; then
  log "rate-mirrors çalıştırılıyor..."
  rate-mirrors --save=/tmp/arch-mirrorlist arch && sudo cp /tmp/arch-mirrorlist /etc/pacman.d/mirrorlist || uyari "rate-mirrors uyarısı."
  basari "Arch aynaları güncellendi."
elif command -v reflector &>/dev/null; then
  log "reflector çalıştırılıyor..."
  sudo reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist || uyari "reflector uyarısı."
  basari "Reflector ile ayna listesi yenilendi."
else
  uyari "Ayna hızlandırma aracı bulunamadı, mevcut aynalarla devam ediliyor."
fi

baslik "2. Pacman ve AUR Sistem Paketleri Güncelleniyor"
if command -v yay &>/dev/null; then
  log "yay ile sistem paketleri güncelleniyor..."
  yay -Syu --noconfirm || uyari "Paket güncellemesi sırasında uyarı alındı."
  basari "Pacman ve AUR paketleri güncellendi."
else
  log "pacman ile sistem güncelleniyor..."
  sudo pacman -Syu --noconfirm || hata "Pacman sistem güncellemesi başarısız."
  basari "Pacman paketleri güncellendi."
fi

baslik "3. Paket Önbelleği ve Artık Paket Temizliği"
ORPHANS=$(pacman -Qtdq 2>/dev/null || true)
if [ -n "$ORPHANS" ]; then
  log "Yetim paketler kaldırılıyor..."
  echo "$ORPHANS" | sudo pacman -Rns - --noconfirm || uyari "Yetim paketlerin bir kısmı kaldırılamadı."
  basari "Yetim paketler temizlendi."
else
  basari "Sistemde kaldırılacak yetim paket bulunamadı."
fi

if command -v paccache &>/dev/null; then
  log "paccache ile eski paket önbellekleri temizleniyor..."
  sudo paccache -rk2 || true
fi

baslik "4. Flatpak Uygulamaları ve Çalışma Zamanları"
if command -v flatpak &>/dev/null; then
  log "Flatpak uygulamaları güncelleniyor..."
  flatpak update -y || uyari "Flatpak güncellemesinde hata oluştu."
  log "Kullanılmayan Flatpak çalışma zamanları temizleniyor..."
  flatpak uninstall --unused -y || true
  basari "Flatpak güncellemeleri tamamlandı."
else
  uyari "Flatpak kurulu değil, atlandı."
fi

baslik "5. Snap Paket Güncellemeleri"
if command -v snap &>/dev/null; then
  log "Snap paketleri güncelleniyor..."
  sudo snap refresh || uyari "Snap refresh sırasında uyarı/hata oluştu."
  basari "Snap paketleri güncellendi."
else
  log "Snapd kurulu değil, atlandı."
fi

baslik "6. Nix Paket Yöneticisi Güncellemeleri"
if command -v nix-channel &>/dev/null && command -v nix-env &>/dev/null; then
  log "Nix paketleri güncelleniyor..."
  nix-channel --update || true
  nix-env -u '*' || true
  basari "Nix paketleri güncellendi."
else
  log "Nix kurulu değil veya profil aktif değil, atlandı."
fi

baslik "7. Pipx Uygulamaları Güncelleniyor"
if command -v pipx &>/dev/null; then
  log "pipx ile kurulmuş araçlar güncelleniyor..."
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
    log "Distrobox Debian konteyneri arkaplanda güncelleniyor..."
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
basari "CachyOS üzerindeki tüm sistem bileşenleri ve paketler güncellendi!"
