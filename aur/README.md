# AUR Helper

Standalone Arch User Repository (AUR) search, inspect, and automated installation tool for Arch Linux and CachyOS.

Türkçe için aşağıya inin → [Türkçe Dokümantasyon](#türkçe-dokümantasyon)

---

## 📖 English Documentation

### 📁 Directory Structure

```text
aur/
├── aur_helper.sh      # Main AUR helper script (bilingual UI: Turkish/English)
├── aur_helper_en.sh   # English UI variant
├── aur_helper_tr.sh   # Turkish UI variant
└── README.md          # This file
```

---

### 🚀 Getting Started

#### 1. Clone the Repository

```bash
git clone https://github.com/syzgia/Scripts.git ~/Scripts
cd ~/Scripts/aur
```

#### 2. Make the Script Executable

```bash
chmod +x aur_helper.sh
```

#### 3. Run the Script

The script must be run as a **regular user with `sudo` privileges** (never as root). Administrative access is requested automatically when needed.

```bash
# Interactive mode: enter a package name when prompted
./aur_helper.sh

# Search and install a specific package directly
./aur_helper.sh spotify

# Install a package by name with confirmation
./aur_helper.sh -i google-chrome

# Search AUR for a term and select from results
./aur_helper.sh -s spotify

# Update all installed AUR packages
./aur_helper.sh -u

# Clean the build cache (~/.cache/aur_helper)
./aur_helper.sh -c

# Interactive fuzzy search with fzf
./aur_helper.sh -f
./aur_helper.sh -f spotify

# Show help
./aur_helper.sh -h
```

---

### ⚙️ Features

- **Fast Package Discovery**: Live search against the AUR RPC v5 API, sorting matches by relevancy (exact match, prefix, popularity, votes).
- **Interactive & Guarded Installation**: Detailed package inspection card (version, license, upstream URL, maintainer, popularity, installed status) with confirmation prompts.
- **PKGBUILD Security Review**: Preview the `PKGBUILD` before compilation and choose whether to proceed.
- **AUR Dependency Resolution**: Detects nested AUR dependencies and resolves them prior to building the target package.
- **Batch AUR Updates (`-u`)**: One-shot multiinfo RPC query comparing all local foreign packages (`pacman -Qm`) with upstream AUR releases using `vercmp`.
- **Fuzzy Search Integration (`-f`)**: Optional interactive fuzzy filtering with live package info preview via `fzf`.
- **Cache Management (`-c`)**: Built-in cleanup tool for the `~/.cache/aur_helper` build directory.
- **Official Repo Fallback**: Checks official Arch/CachyOS repositories first (`pacman -Si`) before falling back to AUR.
- **Flexible Package Matching**: Accepts package name, numeric index, prefix match, or partial name match.

### 🔧 Required Dependencies

The script checks for and can optionally install: `curl`, `jq`, `git`, `makepkg`, `pacman`.

### 🛡️ Design Principles

- **Non-root execution**: Refuses to run as `root` because `makepkg` does not allow building packages as root.
- **Idempotent**: Safe to re-run; existing configurations are not broken.
- **Fail-safe**: Uses `set -uo pipefail` and conditional guards.
- **Transparent**: Lets you inspect `PKGBUILD` before building.

---

## 📄 Türkçe Dokümantasyon

### 📁 Dizin Yapısı

```text
aur/
├── aur_helper.sh      # Ana AUR yardımcı scripti (çift dilli arayüz: Türkçe/İngilizce)
├── aur_helper_en.sh   # İngilizce arayüz varyantı
├── aur_helper_tr.sh   # Türkçe arayüz varyantı
└── README.md          # Bu dosya
```

---

### 🚀 Başlangıç

#### 1. Depoyu Klonlayın

```bash
git clone https://github.com/syzgia/Scripts.git ~/Scripts
cd ~/Scripts/aur
```

#### 2. Scripti Çalıştırılabilir Yapın

```bash
chmod +x aur_helper.sh
```

#### 3. Scripti Çalıştırın

Script, **root olmayan bir kullanıcı ile `sudo` yetkisine sahip şekilde çalıştırılmalıdır** (asla root olarak çalıştırılmamalıdır). Gerekli yerlerde yönetici erişimi otomatik olarak istenir.

```bash
# Etkileşimli mod: istendiğinde paket adını girin
./aur_helper.sh

# Belirli bir paketi doğrudan ara ve kurun
./aur_helper.sh spotify

# Paket adını belirterek onayla ve kurun
./aur_helper.sh -i google-chrome

# AUR'da bir terim ara ve sonuçlardan seçin
./aur_helper.sh -s spotify

# Tüm kurulu AUR paketlerini güncelleyin
./aur_helper.sh -u

# Derleme önbelleğini temizleyin (~/.cache/aur_helper)
./aur_helper.sh -c

# fzf ile etkileşimli kılafat arama
./aur_helper.sh -f
./aur_helper.sh -f spotify

# Yardım ekranını gösterin
./aur_helper.sh -h
```

---

### ⚙️ Özellikler

- **Hızlı Paket Keşfi**: AUR RPC v5 API üzerinden canlı arama; eşleşmeler alakalılığa (tam eşleşme, önek, popülerlik, oylar) göre sıralanır.
- **Etkileşimli ve Korumalı Kurulum**: Sürüm, lisans, upstream URL, bakıcı, popülerlik, kurulum durumu içeren detaylı paket inceleme kartı ve onay istemleri.
- **PKGBUILD Güvenliği İnceleme**: Derlemeden önce `PKGBUILD`'ı önizleyin ve devam etmeyi seçin.
- **AUR Bağımlılık Çözümü**: İç içe geçen AUR bağımlılıklarını tespit eder ve hedef paketi derlemeden önce çözer.
- **Toplu AUR Güncelleme (`-u`)**: Tüm yerel yabancı paketler (`pacman -Qm`) ile AUR üzerindeki yeni sürümleri `vercmp` kullanarak karşılaştıran tek seferlik multiinfo RPC sorgusu.
- **Kısa Arama Entegrasyonu (`-f`)**: `fzf` üzerinden canlı paket bilgisi önizlemesiyleste seçimli kısmi arama.
- **Önbellek Yönetimi (`-c`)**: `~/.cache/aur_helper` derleme dizini için yerleşik temizleme aracı.
- **Resmi Depo Yedeği**: AUR'a geri dönmeden önce önce resmi Arch/CachyOS depolarını kontrol eder (`pacman -Si`).
- **Esnek Paket Eşleştirme**: Paket adı, sayısal indeks, önek eşleşmesi veya kısmi isim eşleşmesini kabul eder.

### 🔧 Gerekli Bağımlılıklar

Script şunları kontrol eder ve isteğe bağlı olarak kurar: `curl`, `jq`, `git`, `makepkg`, `pacman`.

### 🛡️ Tasarım İlkeleri

- **Root olarak çalıştırılmaz**: `makepkg` güvenlik nedeniyle root olarak paket derlemeye izin vermez olduğu için script root olarak çalıştırılmayı reddeder.
- **Idsempotent**: Tekrar çalıştırılması güvenlidir; mevcut yapılandırmalar bozulmaz.
- **Güvenli**: `set -uo pipefail` ve koşullu korumalar kullanır.
- **Şeffaf**: Derlemeden önce `PKGBUILD`'ı incelemenize izin verir.

---

## 📄 License

This repository is maintained for personal and community automation workflows. Feel free to fork, adapt, and customize according to your hardware and distro setup.

Bu depo kişisel ve topluluk otomasyon iş akışları için sürdürülmektedir. Donanımınız ve dağıtım kurulumunuza göre fork edebilir, uyarlayabilir ve özelleştirebilirsiniz.
