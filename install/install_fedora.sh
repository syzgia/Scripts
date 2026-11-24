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
    ______         __                     ____           __        ____
   / ____/__  ____/ /___  _________ _    /  _/___  _____/ /_____ _/ / /
  / /_  / _ \/ __  / __ \/ ___/ __ `/    / // __ \/ ___/ __/ __ `/ / / 
 / __/ /  __/ /_/ / /_/ / /  / /_/ /   _/ // / / (__  ) /_/ /_/ / / /  
/_/    \___/\__,_/\____/_/   \__,_/   /___/_/ /_/____/\__/\__,_/_/_/   
EOF
echo -e "${RESET}"
log "Fedora Kurulum Scripti Başlatılıyor..."

sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
SUDO_PID=$!
trap 'kill "$SUDO_PID" 2>/dev/null || true' EXIT

baslik "1. Kullanıcı Dizinleri Oluşturuluyor"
mkdir -p ~/Phone ~/Projects ~/Syncthing ~/Notes ~/Downloads
basari "Klasörler hazır: ~/Phone ~/Projects ~/Syncthing ~/Notes ~/Downloads"

baslik "2. DNF Ayna Hızlandırması & Sistem Güncellemesi"
DNF_CONF="/etc/dnf/dnf.conf"
if [ -f "$DNF_CONF" ]; then
  if ! grep -q "^fastestmirror=True" "$DNF_CONF"; then
    echo "fastestmirror=True" | sudo tee -a "$DNF_CONF" >/dev/null
  fi
  if ! grep -q "^max_parallel_downloads=" "$DNF_CONF"; then
    echo "max_parallel_downloads=10" | sudo tee -a "$DNF_CONF" >/dev/null
  fi
  basari "DNF ayna ve çoklu indirme ayarları optimize edildi."
fi

log "Sistem paketleri güncelleniyor (dnf upgrade --refresh)..."
sudo dnf upgrade -y --refresh
basari "Sistem paketleri güncellendi."

baslik "3. RPM Fusion Depoları Ekleniyor"
FEDORA_VER=$(rpm -E %fedora)
sudo dnf install -y \
  https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-"${FEDORA_VER}".noarch.rpm \
  https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-"${FEDORA_VER}".noarch.rpm || uyari "RPM Fusion eklenirken uyarı alındı."
basari "RPM Fusion depoları aktif edildi."

baslik "4. Harici Yazılım Depoları Yapılandırılıyor"
sudo dnf install -y dnf-plugins-core

if [ ! -f /etc/yum.repos.d/vscode.repo ]; then
  log "VS Code deposu ekleniyor..."
  sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc || true
  sudo tee /etc/yum.repos.d/vscode.repo > /dev/null << 'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
fi

if [ ! -f /etc/yum.repos.d/brave-browser.repo ]; then
  log "Brave Browser deposu ekleniyor..."
  sudo dnf config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo || true
  sudo rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc || true
fi

if [ ! -f /etc/yum.repos.d/hashicorp.repo ]; then
  log "HashiCorp deposu ekleniyor..."
  sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo || true
fi

if [ ! -f /etc/yum.repos.d/docker-ce.repo ]; then
  log "Docker CE deposu ekleniyor..."
  sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo || true
fi

log "Copr depoları etkinleştiriliyor..."
sudo dnf copr enable -y atim/lazygit || uyari "lazygit copr uyarısı."
sudo dnf copr enable -y bpostlethwaite/btrfs-assistant || uyari "btrfs-assistant copr uyarısı."

basari "Tüm depolar hazırlandı."

baslik "5. Temel Sistem ve Geliştirici Bileşenleri Kuruluyor"
sudo dnf install -y \
  @development-tools git curl wget flatpak snapd distrobox \
  docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
  plasma-discover plasma-discover-flatpak firewalld || uyari "Temel araçlar kurulumunda uyarı."
basari "Temel araçlar kuruldu."

baslik "6. Servisler Etkinleştiriliyor"
log "Docker servisi başlatılıyor..."
sudo systemctl enable --now docker || uyari "Docker başlatılamadı."
sudo usermod -aG docker "$USER" 2>/dev/null || true

log "Snapd soketi etkinleştiriliyor..."
sudo systemctl enable --now snapd.socket || uyari "Snapd başlatılamadı."
sudo ln -sf /var/lib/snapd/snap /snap 2>/dev/null || true

log "Bluetooth servisi başlatılıyor..."
sudo dnf install -y bluez bluez-tools
sudo systemctl enable --now bluetooth || true

basari "Servisler etkinleştirildi."

baslik "7. Nix Paket Yöneticisi Kuruluyor"
if ! command -v nix-env &>/dev/null && [ ! -d /nix ]; then
  log "Nix daemon kurulumu başlatılıyor..."
  curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install | sh -s -- --daemon || uyari "Nix kurulumu tamamlanamadı."
  basari "Nix kuruldu."
else
  basari "Nix zaten mevcut."
fi

baslik "8. Antigravity CLI Kuruluyor"
if ! command -v antigravity &>/dev/null; then
  log "Antigravity CLI kuruluyor..."
  curl -fsSL https://antigravity.google/cli/install.sh | bash || uyari "Antigravity kurulumunda uyarı."
  basari "Antigravity CLI kuruldu."
else
  basari "Antigravity CLI zaten kurulu."
fi

baslik "9. DNF Paketleri Kuruluyor"
DNF_PACKAGES=(
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
  gh
  gnome-builder
  kate
  terraform
  lazygit
  neovim
  vim-enhanced
  golang
  fastfetch
  bat
  btop
  fzf
  eza
  unrar
  p7zip
  p7zip-plugins
  ncdu
  gnome-boxes
  gnome-disk-utility
  gnome-tweaks
  btrfs-assistant
  torbrowser-launcher
  kde-connect
  qbittorrent
  syncthing
  thunderbird
  sshfs
  sshpass
  qrencode
  plasma-browser-integration
  brave-browser
  code
  libreoffice
  okular
  python3-pipx
  jetbrains-mono-fonts
  google-noto-emoji-fonts
  intel-media-driver
  libva-utils
  mesa-demos
  nvtop
  gstreamer1-plugins-good
  gstreamer1-plugins-bad-freeworld
  gstreamer1-plugins-ugly
  gstreamer1-libav
)

for pkg in "${DNF_PACKAGES[@]}"; do
  sudo dnf install -y "$pkg" || uyari "DNF paketi kurulamadı: $pkg"
done
basari "DNF paketlerinin kurulumu tamamlandı."

baslik "10. Flathub Deposu ve Flatpak Uygulamaları Kuruluyor"
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
  com.jetbrains.PyCharm-Community
  org.freedownloadmanager.Manager
  com.onlyoffice.DesktopEditors
)

for fapp in "${FLATPAK_PACKAGES[@]}"; do
  log "Flatpak kuruluyor: $fapp"
  flatpak install flathub "$fapp" -y || uyari "Flatpak yüklenemedi: $fapp"
done
basari "Flatpak uygulamaları kuruldu."

baslik "11. Güvenlik Duvarı (firewalld) Kuralları"
sudo systemctl enable --now firewalld || true
sudo firewall-cmd --zone=public --add-service=kdeconnect --permanent || true
sudo firewall-cmd --zone=public --add-service=syncthing --permanent || true
sudo firewall-cmd --reload || true
basari "Güvenlik duvarı kuralları uygulandı."

baslik "12. Syncthing Kullanıcı Servisi Başlatılıyor"
systemctl --user enable --now syncthing.service || uyari "Syncthing başlatılamadı."
log "Syncthing web arayüzü açılıyor..."
xdg-open http://localhost:8384 2>/dev/null || true
basari "Syncthing aktif edildi."

baslik "13. Pipx ve spotdl Kurulumu"
if command -v pipx &>/dev/null; then
  pipx ensurepath || true
  pipx install spotdl || uyari "spotdl kurulamadı."
  basari "spotdl kuruldu."
fi

baslik "14. Distrobox Debian Konteyneri Oluşturuluyor"
if command -v distrobox &>/dev/null; then
  if ! distrobox list 2>/dev/null | grep -q "Debian"; then
    log "Debian konteyneri oluşturuluyor..."
    distrobox create -n Debian --image debian:latest --yes || uyari "Distrobox oluşturulamadı."
    nohup distrobox enter Debian -- sh -c "sudo apt update && sudo apt upgrade -y" > ~/debian_guncelleme.log 2>&1 &
    basari "Debian konteyneri oluşturuldu ve güncelleniyor."
  else
    basari "Distrobox Debian konteyneri zaten mevcut."
  fi
fi

baslik "15. AnimeciX AppImage İndiriliyor"
cd ~/Downloads
if [ ! -f "AnimeciX-0.1.26-x64.AppImage" ]; then
  wget -c https://github.com/CaptainSP/animecix-desktop-2/releases/download/v0.1.26/AnimeciX-0.1.26-x64.AppImage || uyari "AnimeciX indirilemedi."
  chmod +x AnimeciX-0.1.26-x64.AppImage 2>/dev/null || true
  basari "AnimeciX AppImage ~/Downloads içerisine indirildi."
else
  basari "AnimeciX AppImage zaten mevcut."
fi
cd ~

baslik "16. OpenCode CLI Kuruluyor"
if ! command -v opencode &>/dev/null; then
  log "OpenCode kuruluyor..."
  curl -fsSL https://opencode.ai/v2/install | bash || uyari "OpenCode kurulumunda uyarı."
  basari "OpenCode kuruldu."
else
  basari "OpenCode zaten kurulu."
fi

baslik "17. Zapret Kuruluyor"
log "Zapret kuruluyor..."
curl -fsSL https://raw.github.com/keift/zapret/refs/heads/main/src/install.sh | sudo bash || uyari "Zapret kurulumunda uyarı."
basari "Zapret kurulum adımı tamamlandı."

baslik "18. Son Güncellemeler ve Temizlik"
sudo dnf upgrade -y || true
flatpak update -y || true

baslik "KURULUM TAMAMLANDI"
basari "Fedora üzerindeki tüm istenen uygulamalar ve servisler kuruldu!"
