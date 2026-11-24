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
  hata "Bu script 'root' olarak çalıştırılmamalıdır!"
  exit 1
fi

echo -e "${KALIN}${YESIL}"
cat << "EOF"
   ______           __            ____  _____   ____           __        ____
  / ____/___ ______/ /_  __  __  / __ \/ ___/  /  _/___  _____/ /_____ _/ / /
 / /   / __ `/ ___/ __ \/ / / / / / / /\__ \   / // __ \/ ___/ __/ __ `/ / / 
/ /___/ /_/ / /__/ / / / /_/ / / /_/ /___/ / _/ // / / (__  ) /_/ /_/ / / /  
\____/\__,_/\___/_/ /_/\__, /  \____//____/ /___/_/ /_/____/\__/\__,_/_/_/   
                      /____/                                                 
EOF
echo -e "${RESET}"
log "CachyOS Kurulum Scripti Başlatılıyor..."

sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
SUDO_PID=$!
trap 'kill "$SUDO_PID" 2>/dev/null || true' EXIT

baslik "1. Kullanıcı Dizinleri Oluşturuluyor"
mkdir -p ~/Phone ~/Projects ~/Syncthing ~/Notes ~/Downloads
basari "Klasörler hazır: ~/Phone ~/Projects ~/Syncthing ~/Notes ~/Downloads"

baslik "2. Ayna Hızlandırma & Sistem Güncellemesi"
if command -v cachyos-rate-mirrors &>/dev/null; then
  log "Aynalar optimize ediliyor..."
  sudo cachyos-rate-mirrors || uyari "Ayna optimizasyonu atlandı."
fi
log "Sistem paketleri güncelleniyor (pacman -Syu)..."
sudo pacman -Syu --needed --noconfirm
basari "Sistem güncellendi."

baslik "3. Temel Sistem Bileşenleri Kuruluyor"
sudo pacman -S --needed --noconfirm \
  base-devel git curl wget flatpak docker distrobox discover flatpak-kcm
basari "Temel bileşenler kuruldu."

baslik "4. Servisler Etkinleştiriliyor"
log "Docker servisi başlatılıyor..."
sudo systemctl enable --now docker || uyari "Docker servisi başlatılamadı."
sudo usermod -aG docker "$USER" 2>/dev/null || true

log "Bluetooth servisi başlatılıyor..."
sudo pacman -S --needed --noconfirm bluez bluez-utils
sudo systemctl enable --now bluetooth || uyari "Bluetooth servisi başlatılamadı."
basari "Sistem servisleri yapılandırıldı."

baslik "5. yay (AUR Yardımcısı) Kontrol Ediliyor"
if ! command -v yay &>/dev/null; then
  log "yay AUR üzerinden derlenip kuruluyor..."
  rm -rf /tmp/yay-build
  git clone https://aur.archlinux.org/yay.git /tmp/yay-build
  (cd /tmp/yay-build && makepkg -si --noconfirm)
  rm -rf /tmp/yay-build
  basari "yay başarıyla kuruldu."
else
  basari "yay zaten kurulu."
fi

baslik "6. Nix Paket Yöneticisi Kuruluyor"
if ! command -v nix-env &>/dev/null && [ ! -d /nix ]; then
  log "Nix daemon moduyla kuruluyor..."
  curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install | sh -s -- --daemon || uyari "Nix kurulumu tamamlanamadı."
  basari "Nix kuruldu."
else
  basari "Nix zaten mevcut."
fi

baslik "7. Antigravity CLI Kuruluyor"
if ! command -v antigravity &>/dev/null; then
  log "Antigravity CLI indiriliyor ve kuruluyor..."
  curl -fsSL https://antigravity.google/cli/install.sh | bash || uyari "Antigravity curl kurulumunda uyarı oluştu."
  basari "Antigravity CLI işlemi tamamlandı."
else
  basari "Antigravity CLI zaten kurulu."
fi

baslik "8. Pacman Resmi Paketleri Kuruluyor"
PACMAN_PACKAGES=(
  audacity
  audacious
  lmms
  blender
  krita
  shotcut
  vlc
  obs-studio
  mpv
  haruna
  kdenlive
  ansible
  distrobox
  docker
  github-cli
  gnome-builder
  kate
  terraform
  lazygit
  neovim
  vim
  zed
  go
  fastfetch
  bat
  btop
  fzf
  eza
  unrar
  7zip
  ncdu
  gnome-boxes
  gnome-disk-utility
  gnome-tweaks
  btrfs-assistant
  discord
  telegram-desktop
  kdeconnect
  qbittorrent
  syncthing
  thunderbird
  sshfs
  sshpass
  qrencode
  libfakekey
  plasma-browser-integration
  libreoffice-still
  okular
  python-pipx
  ttf-jetbrains-mono-nerd
  noto-fonts-emoji
  intel-media-driver
  libva-utils
  mesa-utils
  nvtop
  gst-plugins-good
  gst-plugins-bad
  gst-plugins-ugly
  gst-libav
)

log "Pacman paket listesi kuruluyor..."
sudo pacman -S --needed --noconfirm "${PACMAN_PACKAGES[@]}" || uyari "Bazı paketler pacman ile kurulamadı."
basari "Pacman paket kurulumu tamamlandı."

baslik "9. AUR Paketleri Kuruluyor (yay)"
YAY_PACKAGES=(
  snapd
  antigravity
  davinci-resolve
  visual-studio-code-bin
  pycharm-community-edition
  brave-bin
  tor-browser
  onlyoffice-bin
  opencode-desktop-bin
  opencode-bin
)

for pkg in "${YAY_PACKAGES[@]}"; do
  log "AUR paketi kuruluyor: $pkg"
  yay -S --needed --noconfirm "$pkg" || uyari "AUR paketi kurulamadı veya zaten kurulu: $pkg"
done

log "Snapd servisi ve soketi etkinleştiriliyor..."
sudo systemctl enable --now snapd.socket 2>/dev/null || true
sudo ln -sf /var/lib/snapd/snap /snap 2>/dev/null || true
basari "AUR paketleri işlendi."

baslik "10. Snap Paketleri Kontrol Ediliyor"
if command -v snap &>/dev/null; then
  log "Snap üzerinden Spotify kuruluyor..."
  sudo snap install spotify || uyari "Snap paketi yüklenemedi."
  basari "Snap işlemleri tamamlandı."
fi

baslik "11. Flathub Deposu ve Flatpak Uygulamaları Kuruluyor"
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

FLATPAK_PACKAGES=(
  net.labymod.LabyMod
  md.obsidian.Obsidian
  com.discordapp.Discord
  im.riot.Riot
  org.telegram.desktop
  app.zen_browser.zen
  org.localsend.localsend_app
  com.usebottles.bottles
  com.github.tchx84.Flatseal
  dev.zed.Zed
  com.jetbrains.GoLand
  com.jetbrains.DataGrip
  io.dbeaver.DBeaverCommunity
  com.obsproject.Studio
  org.pvermeer.WebAppHub
  org.freedownloadmanager.Manager
  com.onlyoffice.DesktopEditors
)

for fapp in "${FLATPAK_PACKAGES[@]}"; do
  log "Flatpak kuruluyor: $fapp"
  flatpak install flathub "$fapp" -y || uyari "Flatpak yüklenemedi: $fapp"
done
basari "Flatpak uygulamaları kuruldu."

baslik "12. Güvenlik Duvarı (firewalld) Yapılandırılıyor"
if command -v firewall-cmd &>/dev/null; then
  sudo firewall-cmd --zone=public --add-service=kdeconnect --permanent || true
  sudo firewall-cmd --zone=public --add-service=syncthing --permanent || true
  sudo firewall-cmd --reload || true
  basari "KDE Connect ve Syncthing güvenlik duvarı kuralları uygulandı."
else
  uyari "firewall-cmd bulunamadı, güvenlik duvarı adımı atlandı."
fi

baslik "13. Syncthing Kullanıcı Servisi Başlatılıyor"
systemctl --user enable --now syncthing.service || uyari "Syncthing servisi başlatılamadı."
log "Syncthing web arayüzü açılıyor..."
xdg-open http://localhost:8384 2>/dev/null || true
basari "Syncthing servisi aktif edildi."

baslik "14. Pipx ve spotdl Kurulumu"
if command -v pipx &>/dev/null; then
  pipx ensurepath || true
  pipx install spotdl || uyari "spotdl pipx üzerinden kurulamadı."
  basari "spotdl kuruldu."
fi

baslik "15. Distrobox Debian Konteyneri Oluşturuluyor"
if command -v distrobox &>/dev/null; then
  if ! distrobox list 2>/dev/null | grep -q "Debian"; then
    log "Debian konteyneri oluşturuluyor..."
    distrobox create -n Debian --image debian:latest --yes || uyari "Distrobox oluşturulamadı."
    nohup distrobox enter Debian -- sh -c "sudo apt update && sudo apt upgrade -y" > ~/debian_guncelleme.log 2>&1 &
    basari "Debian konteyneri oluşturuldu ve arkaplanda güncelleniyor (log: ~/debian_guncelleme.log)."
  else
    basari "Distrobox Debian konteyneri zaten mevcut."
  fi
fi

baslik "16. AnimeciX AppImage İndiriliyor"
cd ~/Downloads
if [ ! -f "AnimeciX-0.1.26-x64.AppImage" ]; then
  wget -c https://github.com/CaptainSP/animecix-desktop-2/releases/download/v0.1.26/AnimeciX-0.1.26-x64.AppImage || uyari "AnimeciX AppImage indirilemedi."
  chmod +x AnimeciX-0.1.26-x64.AppImage 2>/dev/null || true
  basari "AnimeciX AppImage ~/Downloads içerisine indirildi ve çalıştırılabilir yapıldı."
else
  basari "AnimeciX AppImage zaten mevcut."
fi
cd ~

baslik "17. OpenCode Kuruluyor"
if ! command -v opencode &>/dev/null; then
  log "OpenCode kuruluyor..."
  curl -fsSL https://opencode.ai/v2/install | bash || uyari "OpenCode curl scripti hata verdi."
  basari "OpenCode kuruldu."
else
  basari "OpenCode zaten kurulu."
fi

baslik "18. Zapret Kuruluyor"
log "Zapret kuruluyor..."
curl -fsSL https://raw.github.com/keift/zapret/refs/heads/main/src/install.sh | sudo bash || uyari "Zapret kurulumunda uyarı oluştu."
basari "Zapret kurulum adımı tamamlandı."

baslik "19. Son Sistem Güncellemesi ve Temizlik"
flatpak update -y || true
yay -Syu --noconfirm || true

baslik "KURULUM TAMAMLANDI"
basari "CachyOS üzerindeki tüm istenen uygulamalar ve servisler kuruldu!"
