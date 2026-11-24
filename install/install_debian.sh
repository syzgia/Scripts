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
    ____       __    _               ____           __        ____
   / __ \___  / /_  (_)___ _____    /  _/___  _____/ /_____ _/ / /
  / / / / _ \/ __ \/ / __ `/ __ \    / // __ \/ ___/ __/ __ `/ / / 
 / /_/ /  __/ /_/ / / /_/ / / / /  _/ // / / (__  ) /_/ /_/ / / /  
/_____/\___/_.___/_/\__,_/_/ /_/  /___/_/ /_/____/\__/\__,_/_/_/   
EOF
echo -e "${RESET}"
log "Debian Kurulum Scripti Başlatılıyor..."

sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
SUDO_PID=$!
trap 'kill "$SUDO_PID" 2>/dev/null || true' EXIT

baslik "1. Kullanıcı Dizinleri Oluşturuluyor"
mkdir -p ~/Phone ~/Projects ~/Syncthing ~/Notes ~/Downloads ~/.local/bin
basari "Klasörler hazır: ~/Phone ~/Projects ~/Syncthing ~/Notes ~/Downloads ~/.local/bin"

baslik "2. Debian Depoları Yapılandırılıyor"
sudo apt install -y software-properties-common ca-certificates curl wget gnupg lsb-release apt-transport-https || true

if [ -f /etc/apt/sources.list ]; then
  sudo sed -i 's/main$/main contrib non-free non-free-firmware/g' /etc/apt/sources.list || true
  sudo sed -i 's/main non-free$/main contrib non-free non-free-firmware/g' /etc/apt/sources.list || true
fi

log "Paket listesi yenileniyor..."
sudo apt update
sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y
basari "Debian ana depoları güncellendi."

baslik "3. Harici Yazılım Depoları Ekleniyor"
sudo mkdir -p /etc/apt/keyrings

if [ ! -f /etc/apt/sources.list.d/vscode.list ]; then
  log "VS Code resmi deposu ekleniyor..."
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor 2>/dev/null | sudo tee /etc/apt/keyrings/packages.microsoft.gpg > /dev/null
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
fi

if [ ! -f /etc/apt/sources.list.d/brave-browser-release.list ]; then
  log "Brave Browser resmi deposu ekleniyor..."
  curl -fsS https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg 2>/dev/null | sudo gpg --dearmor -o /etc/apt/keyrings/brave-browser-archive-keyring.gpg 2>/dev/null || true
  echo "deb [signed-by=/etc/apt/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-release.list > /dev/null
fi

if [ ! -f /etc/apt/sources.list.d/github-cli.list ]; then
  log "GitHub CLI resmi deposu ekleniyor..."
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg 2>/dev/null | sudo gpg --dearmor -o /etc/apt/keyrings/githubcli-archive-keyring.gpg 2>/dev/null || true
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
fi

if [ ! -f /etc/apt/sources.list.d/hashicorp.list ]; then
  log "HashiCorp resmi deposu ekleniyor..."
  wget -O- https://apt.releases.hashicorp.com/gpg 2>/dev/null | sudo gpg --dearmor -o /etc/apt/keyrings/hashicorp-archive-keyring.gpg 2>/dev/null || true
  DEBIAN_CODENAME=$(lsb_release -cs 2>/dev/null || echo "bookworm")
  echo "deb [signed-by=/etc/apt/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com ${DEBIAN_CODENAME} main" | sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null
fi

if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
  log "Docker CE resmi deposu ekleniyor..."
  curl -fsSL https://download.docker.com/linux/debian/gpg 2>/dev/null | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null || true
  DEBIAN_CODENAME=$(lsb_release -cs 2>/dev/null || echo "bookworm")
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian ${DEBIAN_CODENAME} stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
fi

if [ ! -f /etc/apt/sources.list.d/gierens.list ]; then
  log "Eza resmi deposu ekleniyor..."
  wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc 2>/dev/null | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg 2>/dev/null || true
  echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list > /dev/null
fi

log "Yeni depolar güncelleniyor..."
sudo apt update || uyari "Bazı depolar yenilenirken uyarı oluştu."
basari "Harici depolar hazırlandı."

baslik "4. Temel Sistem Bileşenleri Kuruluyor"
sudo DEBIAN_FRONTEND=noninteractive apt install -y \
  build-essential git curl wget flatpak snapd distrobox \
  plasma-discover plasma-discover-backend-flatpak ufw || uyari "Temel araçlar kurulumunda uyarı."
basari "Temel araçlar kuruldu."

baslik "5. Servisler Etkinleştiriliyor"
log "Docker servisi başlatılıyor..."
sudo DEBIAN_FRONTEND=noninteractive apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>/dev/null || \
  sudo DEBIAN_FRONTEND=noninteractive apt install -y docker.io docker-compose 2>/dev/null || true

sudo systemctl enable --now docker || true
sudo usermod -aG docker "$USER" 2>/dev/null || true

log "Snapd soketi etkinleştiriliyor..."
sudo systemctl enable --now snapd.socket || true
sudo ln -sf /var/lib/snapd/snap /snap 2>/dev/null || true

log "Bluetooth servisi başlatılıyor..."
sudo DEBIAN_FRONTEND=noninteractive apt install -y bluez bluez-tools
sudo systemctl enable --now bluetooth || true

basari "Servisler etkinleştirildi."

baslik "6. Nix Paket Yöneticisi Kuruluyor"
if ! command -v nix-env &>/dev/null && [ ! -d /nix ]; then
  log "Nix daemon kurulumu başlatılıyor..."
  curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install | sh -s -- --daemon || uyari "Nix kurulumu tamamlanamadı."
  basari "Nix kuruldu."
else
  basari "Nix zaten mevcut."
fi

baslik "7. Antigravity CLI Kuruluyor"
if ! command -v antigravity &>/dev/null; then
  log "Antigravity CLI kuruluyor..."
  curl -fsSL https://antigravity.google/cli/install.sh | bash || uyari "Antigravity curl kurulumunda uyarı oluştu."
  basari "Antigravity CLI kuruldu."
else
  basari "Antigravity CLI zaten kurulu."
fi

baslik "8. APT Paketleri Kuruluyor"
APT_PACKAGES=(
  audacity
  audacious
  lmms
  blender
  krita
  vlc
  obs-studio
  mpv
  kdenlive
  ansible
  distrobox
  gh
  gnome-builder
  kate
  terraform
  neovim
  vim
  golang-go
  bat
  btop
  fzf
  eza
  p7zip-full
  unrar-free
  ncdu
  gnome-boxes
  gnome-disk-utility
  gnome-tweaks
  torbrowser-launcher
  kdeconnect
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
  fonts-jetbrains-mono
  fonts-noto-color-emoji
  intel-media-va-driver
  vainfo
  mesa-utils
  nvtop
  gstreamer1.0-plugins-good
  gstreamer1.0-plugins-bad
  gstreamer1.0-plugins-ugly
  gstreamer1.0-libav
)

for pkg in "${APT_PACKAGES[@]}"; do
  sudo DEBIAN_FRONTEND=noninteractive apt install -y "$pkg" || uyari "APT paketi kurulamadı: $pkg"
done

if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
  sudo ln -sf "$(which batcat)" /usr/local/bin/bat 2>/dev/null || ln -sf "$(which batcat)" ~/.local/bin/bat
fi

if ! command -v fastfetch &>/dev/null; then
  log "Fastfetch kuruluyor..."
  FF_DEB=$(curl -s https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest | grep "browser_download_url.*linux-amd64.deb" | cut -d '"' -f 4 || true)
  if [ -n "$FF_DEB" ]; then
    wget -qO /tmp/fastfetch.deb "$FF_DEB" && sudo dpkg -i /tmp/fastfetch.deb || true
    rm -f /tmp/fastfetch.deb
  fi
fi

if ! command -v lazygit &>/dev/null; then
  log "Lazygit kuruluyor..."
  LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
  if [ -n "$LAZYGIT_VERSION" ]; then
    curl -Lo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
    tar xf /tmp/lazygit.tar.gz -C /tmp lazygit 2>/dev/null || true
    sudo install /tmp/lazygit /usr/local/bin 2>/dev/null || cp /tmp/lazygit ~/.local/bin/
    rm -rf /tmp/lazygit /tmp/lazygit.tar.gz
  fi
fi

basari "APT ve sistem araçları kurulumu tamamlandı."

baslik "9. Flathub Deposu ve Flatpak Uygulamaları Kuruluyor"
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
  org.shotcut.Shotcut
  org.kde.haruna
)

for fapp in "${FLATPAK_PACKAGES[@]}"; do
  log "Flatpak kuruluyor: $fapp"
  flatpak install flathub "$fapp" -y || uyari "Flatpak yüklenemedi: $fapp"
done
basari "Flatpak uygulamaları kuruldu."

baslik "10. Güvenlik Duvarı Yapılandırılıyor"
if command -v ufw &>/dev/null; then
  log "UFW kuralları ekleniyor..."
  sudo ufw allow 1714:1764/udp comment 'kdeconnect' || true
  sudo ufw allow 1714:1764/tcp comment 'kdeconnect' || true
  sudo ufw allow 22000/tcp comment 'syncthing' || true
  sudo ufw allow 22000/udp comment 'syncthing' || true
  sudo ufw allow 21027/udp comment 'syncthing-discovery' || true
fi
if command -v firewall-cmd &>/dev/null; then
  sudo firewall-cmd --zone=public --add-service=kdeconnect --permanent 2>/dev/null || true
  sudo firewall-cmd --zone=public --add-service=syncthing --permanent 2>/dev/null || true
  sudo firewall-cmd --reload 2>/dev/null || true
fi
basari "Güvenlik duvarı kuralları uygulandı."

baslik "11. Syncthing Kullanıcı Servisi Başlatılıyor"
systemctl --user enable --now syncthing.service || uyari "Syncthing servisi başlatılamadı."
log "Syncthing web arayüzü açılıyor..."
xdg-open http://localhost:8384 2>/dev/null || true
basari "Syncthing aktif edildi."

baslik "12. Pipx ve spotdl Kurulumu"
if command -v pipx &>/dev/null; then
  pipx ensurepath || true
  pipx install spotdl || uyari "spotdl kurulamadı."
  basari "spotdl kuruldu."
fi

baslik "13. Distrobox Debian Konteyneri Oluşturuluyor"
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

baslik "14. AnimeciX AppImage İndiriliyor"
cd ~/Downloads
if [ ! -f "AnimeciX-0.1.26-x64.AppImage" ]; then
  wget -c https://github.com/CaptainSP/animecix-desktop-2/releases/download/v0.1.26/AnimeciX-0.1.26-x64.AppImage || uyari "AnimeciX AppImage indirilemedi."
  chmod +x AnimeciX-0.1.26-x64.AppImage 2>/dev/null || true
  basari "AnimeciX AppImage ~/Downloads içerisine indirildi ve çalıştırılabilir yapıldı."
else
  basari "AnimeciX AppImage zaten mevcut."
fi
cd ~

baslik "15. OpenCode CLI Kuruluyor"
if ! command -v opencode &>/dev/null; then
  log "OpenCode resmi scripti ile kuruluyor..."
  curl -fsSL https://opencode.ai/v2/install | bash || uyari "OpenCode curl kurulumunda uyarı oluştu."
  basari "OpenCode kuruldu."
else
  basari "OpenCode zaten kurulu."
fi

baslik "16. Zapret Kuruluyor"
log "Zapret kuruluyor..."
curl -fsSL https://raw.github.com/keift/zapret/refs/heads/main/src/install.sh | sudo bash || uyari "Zapret kurulumunda bir uyarı veya hata oluştu."
basari "Zapret kurulum adımı tamamlandı."

baslik "17. Son Güncellemeler ve Temizlik"
sudo apt update && sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y || true
flatpak update -y || true

baslik "KURULUM TAMAMLANDI"
basari "Debian üzerindeki tüm istenen uygulamalar ve servisler kuruldu!"
