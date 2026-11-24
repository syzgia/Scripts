# Update & Maintenance Scripts

Automated Bash scripts for full-system maintenance, package updates, mirror ranking, and cleanup across CachyOS/Arch Linux, Fedora, and Debian GNU/Linux.

---

## 📁 Directory Structure

```text
update/
├── update_cachyos.sh   # CachyOS / Arch Linux system update & maintenance
├── update_fedora.sh    # Fedora Linux system update & maintenance
├── update_debian.sh    # Debian GNU/Linux system update & maintenance
└── README.md           # This file
```

---

## 🚀 Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/syzgia/Scripts.git ~/Scripts
cd ~/Scripts/update
```

### 2. Make Scripts Executable

```bash
chmod +x *.sh
```

### 3. Run the Script for Your Distribution

All scripts must be run as a **regular user with `sudo` privileges** (never as root). Administrative access is requested automatically when needed.

```bash
# CachyOS / Arch Linux
./update_cachyos.sh

# Fedora Linux
./update_fedora.sh

# Debian GNU/Linux
./update_debian.sh
```

---

## 🔄 What Each Script Does

### Common Maintenance Steps (all distributions)
- **Mirror optimization**: Ranks and selects the fastest geographically appropriate package mirrors.
- **Native repository updates**: Updates packages via the distribution package manager (`pacman`, `dnf`, or `apt`).
- **Orphaned package removal**: Detects and removes unneeded dependencies left behind after package removals.
- **Package cache cleanup**: Cleans obsolete package archives to free disk space.

### Distribution-Specific Steps

#### `update_cachyos.sh` — CachyOS / Arch Linux
- Optimizes mirrors with `cachyos-rate-mirrors`, `rate-mirrors`, or `reflector`
- Updates Pacman and AUR packages with `yay -Syu` (or `pacman -Syu` if `yay` is absent)
- Removes orphaned packages and cleans the Pacman cache with `paccache`
- Updates Flatpak applications and removes unused runtimes
- Refreshes Snap packages
- Updates Nix channels and environments
- Upgrades all Pipx-installed CLI tools
- Upgrades Distrobox containers (`distrobox-upgrade` or background Debian container update)
- Checks for hardware firmware updates with `fwupdmgr`

#### `update_fedora.sh` — Fedora Linux
- Updates packages via `dnf upgrade`
- Cleans the DNF cache
- Updates Flatpak and Snap packages
- Upgrades Pipx tools and Distrobox containers

#### `update_debian.sh` — Debian GNU/Linux
- Updates package indexes and upgrades packages via `apt upgrade` and `apt full-upgrade`
- Removes unused dependencies with `apt autoremove`
- Cleans the APT cache with `apt clean`
- Updates Flatpak and Snap packages
- Upgrades Pipx tools and Distrobox containers

---

## ⚙️ Design Principles

- **Non-root execution**: Scripts refuse to run as `root` and use `sudo` only where required.
- **Idempotent**: Safe to re-run; existing configurations are not broken.
- **Unattended-ready**: Uses `-y`, `--noconfirm`, and similar flags for automated execution.
- **Fail-safe**: Uses `set -uo pipefail` and conditional guards so a single component failure does not abort the whole script.

---

## 📄 License

This repository is maintained for personal and community automation workflows. Feel free to fork, adapt, and customize according to your hardware and distribution setup.

---

## 📄 Türkçe Dokümantasyon

### 📁 Dizin Yapısı

```text
update/
├── update_cachyos.sh   # CachyOS / Arch Linux sistem güncelleme ve bakım
├── update_fedora.sh    # Fedora Linux sistem güncelleme ve bakım
├── update_debian.sh    # Debian GNU/Linux sistem güncelleme ve bakım
└── README.md           # Bu dosya
```

---

### 🚀 Başlangıç

#### 1. Depoyu Klonlayın

```bash
git clone https://github.com/syzgia/Scripts.git ~/Scripts
cd ~/Scripts/update
```

#### 2. Scriptleri Çalıştırılabilir Yapın

```bash
chmod +x *.sh
```

#### 3. Dağıtımınıza Göre Scripti Çalıştırın

Tüm scriptler **root olmayan bir kullanıcı ile `sudo` yetkisine sahip şekilde çalıştırılmalıdır** (asla root olarak çalıştırılmamalıdır). Gerekli yerlerde yönetici erişimi otomatik olarak istenir.

```bash
# CachyOS / Arch Linux
./update_cachyos.sh

# Fedora Linux
./update_fedora.sh

# Debian GNU/Linux
./update_debian.sh
```

---

### 🔄 Her Script Ne İşe Yarar

#### Tüm Dağıtımlar İçin Ortak Bakım Adımları
- **Ayna optimizasyonu**: En hızlı coğrafi olarak uygun paket aynalarını sıralar ve seçer.
- **Resmi depoları günceller**: Dağıtım paket yöneticisi (`pacman`, `dnf` veya `apt`) ile paketleri günceller.
- **Yetim paketleri kaldırır**: Paket kaldırmalarından sonra kalan gereksiz bağımlılıkları tespit eder ve kaldırır.
- **Paket önbelleği temizliği**: Disk alanını boşaltmak için eski paket arşivlerini temizler.

#### Dağıtım Özgü Adımlar

#### `update_cachyos.sh` — CachyOS / Arch Linux
- `cachyos-rate-mirrors`, `rate-mirrors` veya `reflector` ile aynaları optimize eder
- `yay -Syu` ile Pacman ve AUR paketlerini günceller (`yay` yoksa `pacman -Syu`)
- Yetim paketleri kaldırır ve Pacman önbelleğini `paccache` ile temizler
- Flatpak uygulamalarını günceller ve kullanılmayan çalışma zamanlarını kaldırır
- Snap paketlerini yeniler
- Nix kanallarını ve ortamlarını günceller
- Tüm Pipx ile kurulan CLI araçlarını yükseltir
- Distrobox konteynerlerini yükseltir (`distrobox-upgrade` veya arkaplanda Debian konteyner güncellemesi)
- Donanım yazılımı güncellemelerini `fwupdmgr` ile kontrol eder

#### `update_fedora.sh` — Fedora Linux
- Paketleri `dnf upgrade` ile günceller
- DNF önbelleğini temizler
- Flatpak ve Snap paketlerini günceller
- Pipx araçlarını ve Distrobox konteynerlerini yükseltir

#### `update_debian.sh` — Debian GNU/Linux
- Paket dizinlerini günceller ve `apt upgrade` ile `apt full-upgrade` ile paketleri yükseltir
- `apt autoremove` ile kullanılmayan bağımlılıkları kaldırır
- `apt clean` ile APT önbelleğini temizler
- Flatpak ve Snap paketlerini günceller
- Pipx araçlarını ve Distrobox konteynerlerini yükseltir

---

### ⚙️ Tasarım İlkeleri

- **Root olarak çalıştırılmaz**: Scriptler `root` olarak çalışmayı reddeder ve `sudo`'yu yalnızca gereken yerlerde kullanır.
- **Idsempotent**: Tekrar çalıştırılması güvenlidir; mevcut yapılandırmalar bozulmaz.
- **Otomatik çalışmaya hazır**: Otomatik yürütme için `-y`, `--noconfirm` ve benzer bayrakları kullanır.
- **Güvenli**: Tek bir bileşen hatasının tüm scripti iptal etmemesi için `set -uo pipefail` ve koşullu korumalar kullanır.

---

## 📄 Lisans

Bu depo kişisel ve topluluk otomasyon iş akışları için sürdürülmektedir. Donanımınız ve dağıtım kurulumunuza göre fork edebilir, uyarlayabilir ve özelleştirebilirsiniz.

---

## 🤖 Otomatik Güncelleme

Haftalık otomatik güncelleme, günlük e-posta ve masaüstü bildirimi için ayrı
[Auup](https://github.com/syzgia/Auup) reposunu kullanın.
