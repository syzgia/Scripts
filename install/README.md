# Installation Scripts

Automated Bash provisioning scripts for bootstrapping development workstations across CachyOS/Arch Linux, Fedora, and Debian GNU/Linux.

---

## 📁 Directory Structure

```text
install/
├── install_cachyos.sh   # CachyOS / Arch Linux workstation provisioning
├── install_fedora.sh    # Fedora Linux workstation provisioning
├── install_debian.sh    # Debian GNU/Linux workstation provisioning
└── README.md            # This file
```

---

## 🚀 Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/syzgia/Scripts.git ~/Scripts
cd ~/Scripts/install
```

### 2. Make Scripts Executable

```bash
chmod +x *.sh
```

### 3. Run the Script for Your Distribution

All scripts must be run as a **regular user with `sudo` privileges** (never as root). Administrative access is requested automatically when needed.

```bash
# CachyOS / Arch Linux
./install_cachyos.sh

# Fedora Linux
./install_fedora.sh

# Debian GNU/Linux
./install_debian.sh
```

---

## 🛠️ What Each Script Does

### `install_cachyos.sh` — CachyOS / Arch Linux
- Creates user directories (`~/Phone`, `~/Projects`, `~/Syncthing`, `~/Notes`, `~/Downloads`)
- Optimizes package mirrors with `cachyos-rate-mirrors`
- Updates the system with `pacman -Syu`
- Installs core components (base-devel, git, docker, distrobox, flatpak, etc.)
- Enables Docker and Bluetooth services
- Installs `yay` AUR helper if missing
- Installs Nix package manager (daemon mode)
- Installs Antigravity CLI
- Installs a curated set of Pacman packages (multimedia, development, system tools, fonts, etc.)
- Installs AUR packages via `yay` (Snapd, Visual Studio Code, Brave, PyCharm, etc.)
- Enables Snapd socket and symlinks `/snap`
- Installs Spotify via Snap
- Adds Flathub and installs Flatpak applications
- Configures `firewalld` for KDE Connect and Syncthing
- Starts the Syncthing user service
- Installs `spotdl` via Pipx
- Creates a Distrobox Debian container
- Downloads the AnimeciX AppImage
- Installs OpenCode and Zapret
- Runs a final system update and cleanup

### `install_fedora.sh` — Fedora Linux
- Updates the system with `dnf`
- Enables RPM Fusion and Copr repositories
- Installs development toolchains and multimedia packages
- Configures Flatpak, Snap, Docker, and Distrobox
- Installs productivity and developer applications

### `install_debian.sh` — Debian GNU/Linux
- Updates the system with `apt`
- Configures official software keyrings and third-party repositories
- Installs Flatpak and binary fallbacks where packages are unavailable in official repos
- Sets up Docker, build tools, and desktop applications

---

## ⚙️ Design Principles

- **Non-root execution**: Scripts refuse to run as `root` and use `sudo` only where required.
- **Idempotent**: Safe to re-run; existing configurations are not broken.
- **Unattended-ready**: Uses `--noconfirm`, `-y`, and similar flags for automated execution.
- **Fail-safe**: Uses `set -uo pipefail` and conditional guards so a single package failure does not abort the whole script.

---

## 📄 License

This repository is maintained for personal and community automation workflows. Feel free to fork, adapt, and customize according to your hardware and distribution setup.

---

## 📄 Türkçe Dokümantasyon

### 📁 Dizin Yapısı

```text
install/
├── install_cachyos.sh   # CachyOS / Arch Linux iş istasyonu kurulumu
├── install_fedora.sh    # Fedora Linux iş istasyonu kurulumu
├── install_debian.sh    # Debian GNU/Linux iş istasyonu kurulumu
└── README.md            # Bu dosya
```

---

### 🚀 Başlangıç

#### 1. Depoyu Klonlayın

```bash
git clone https://github.com/syzgia/Scripts.git ~/Scripts
cd ~/Scripts/install
```

#### 2. Scriptleri Çalıştırılabilir Yapın

```bash
chmod +x *.sh
```

#### 3. Dağıtımınıza Göre Scripti Çalıştırın

Tüm scriptler **root olmayan bir kullanıcı ile `sudo` yetkisine sahip şekilde çalıştırılmalıdır** (asla root olarak çalıştırılmamalıdır). Gerekli yerlerde yönetici erişimi otomatik olarak istenir.

```bash
# CachyOS / Arch Linux
./install_cachyos.sh

# Fedora Linux
./install_fedora.sh

# Debian GNU/Linux
./install_debian.sh
```

---

### 🛠️ Her Script Ne İşe Yarar

#### `install_cachyos.sh` — CachyOS / Arch Linux
- Kullanıcı dizinleri oluşturur (`~/Phone`, `~/Projects`, `~/Syncthing`, `~/Notes`, `~/Downloads`)
- Paket aynalarını `cachyos-rate-mirrors` ile optimize eder
- Sistemi `pacman -Syu` ile günceller
- Temel bileşenleri kurar (base-devel, git, docker, distrobox, flatpak vb.)
- Docker ve Bluetooth servislerini etkinleştirir
- `yay` AUR yardımcısı yoksa kurar
- Nix paket yöneticisini kurar (daemon modunda)
- Antigravity CLI'yi kurar
- Pacman paketlerinin seçilmiş bir kümesini kurar (multimedya, geliştirme, sistem araçları, yazı tipleri vb.)
- AUR paketlerini `yay` üzerinden kurar (Snapd, Visual Studio Code, Brave, PyCharm vb.)
- Snapd soketini etkinleştirir ve `/snap` simgesel bağını oluşturur
- Snap üzerinden Spotify'ı kurar
- Flathub deposunu ekler ve Flatpak uygulamalarını kurar
- `firewalld` ile KDE Connect ve Syncthing için güvenlik duvarı kurallarını yapılandırır
- Syncthing kullanıcı servisini başlatır
- `spotdl`'yi Pipx ile kurar
- Distrobox Debian konteyneri oluşturur
- AnimeciX AppImage'ini indirir
- OpenCode ve Zapret'i kurar
- Son sistem güncellemesi ve temizliği çalıştırır

#### `install_fedora.sh` — Fedora Linux
- Sistemi `dnf` ile günceller
- RPM Fusion ve Copr depolarını etkinleştirir
- Geliştirme araç zincirlerini ve multimedya paketlerini kurar
- Flatpak, Snap, Docker ve Distrobox'ı yapılandırır
- Üretkenlik ve geliştirici uygulamalarını kurar

#### `install_debian.sh` — Debian GNU/Linux
- Sistemi `apt` ile günceller
- Resmi yazılım anahtar zincirleri ve üçüncü taraf depolarını yapılandırır
- Paketler resmi depolarda mevcut değilse Flatpak ve ikonik yedekleri kurar
- Docker, derleme araçları ve masaüstü uygulamalarını ayarlar

---

### ⚙️ Tasarım İlkeleri

- **Root olarak çalıştırılmaz**: Scriptler `root` olarak çalışmayı reddeder ve `sudo`'yu yalnızca gereken yerlerde kullanır.
- **Idsempotent**: Tekrar çalıştırılması güvenlidir; mevcut yapılandırmalar bozulmaz.
- **Otomatik çalışmaya hazır**: Otomatik yürütme için `--noconfirm`, `-y` ve benzer bayrakları kullanır.
- **Güvenli**: Tek bir paket hatasının tüm scripti iptal etmemesi için `set -uo pipefail` ve koşullu korumalar kullanır.

---

## 📄 Lisans

Bu depo kişisel ve topluluk otomasyon iş akışları için sürdürülmektedir. Donanımınız ve dağıtım kurulumunuza göre fork edebilir, uyarlayabilir ve özelleştirebilirsiniz.
