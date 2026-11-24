#!/usr/bin/env bash
set -uo pipefail
export LC_NUMERIC=C

KIRMIZI='\033[0;31m'
YESIL='\033[0;32m'
SARI='\033[1;33m'
MAVI='\033[0;36m'
MOR='\033[0;35m'
CYAN='\033[1;36m'
GRI='\033[0;90m'
KALIN='\033[1m'
RESET='\033[0m'

AUR_RPC_URL="https://aur.archlinux.org/rpc/v5"
AUR_GIT_URL="https://aur.archlinux.org"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/aur_helper"

log()    { echo -e "${MAVI}[*]${RESET} $1"; }
basari() { echo -e "${YESIL}[✓]${RESET} $1"; }
uyari()  { echo -e "${SARI}[!]${RESET} $1"; }
hata()   { echo -e "${KIRMIZI}[✗]${RESET} $1"; }
bilgi()  { echo -e "${CYAN}[i]${RESET} $1"; }

baslik() {
  echo -e "\n${KALIN}${MAVI}======================================================================${RESET}"
  echo -e "${KALIN}${MAVI} $1${RESET}"
  echo -e "${KALIN}${MAVI}======================================================================${RESET}"
}

banner() {
  echo -e "${KALIN}${CYAN}"
  cat << "EOF"
    ___   __  ______     __  __     __                  
   /   | / / / / __ \   / / / /__  / /___  ___  _____   
  / /| |/ / / / /_/ /  / /_/ / _ \/ / __ \/ _ \/ ___/   
 / ___ / /_/ / _, _/  / __  /  __/ / /_/ /  __/ /       
/_/  |_\____/_/ |_|  /_/ /_/\___/_/ .___/\___/_/        
                                 /_/                    
EOF
  echo -e "${RESET}${GRI}Arch User Repository (AUR) Otomatik Paket Arama & Kurulum Aracı${RESET}\n"
}

check_root() {
  if [[ $EUID -eq 0 ]]; then
    hata "Bu script 'root' olarak çalıştırılmamalıdır!"
    uyari "makepkg güvenlik nedeniyle root yetkisiyle paket derlemeye izin vermez."
    uyari "Lütfen normal kullanıcı olarak çalıştırınız. Gereken yerde sudo istenecektir."
    exit 1
  fi
}

check_dependencies() {
  local eksikler=()
  local gerekli_paketler=("curl" "jq" "git" "makepkg" "pacman")

  for komut in "${gerekli_paketler[@]}"; do
    if ! command -v "$komut" &>/dev/null; then
      eksikler+=("$komut")
    fi
  done

  if [[ ${#eksikler[@]} -gt 0 ]]; then
    uyari "Gerekli bazı bağımlılıklar eksik: ${eksikler[*]}"
    if confirm "Eksik bağımlılıklar pacman ile kurulsun mu?" "E"; then
      sudo pacman -S --needed --noconfirm "${eksikler[@]}" || {
        hata "Bağımlılıklar kurulamadı. Lütfen manuel olarak kurun: sudo pacman -S ${eksikler[*]}"
        exit 1
      }
    else
      hata "Gereksinimler karşılanmadan script çalışamaz."
      exit 1
    fi
  fi
}

read_prompt() {
  local prompt_msg="$1"
  local var_name="$2"
  local val=""

  if [[ -t 0 ]]; then
    read -r -p "$prompt_msg" val
  else
    if ! read -r val; then
      if [[ -r /dev/tty ]]; then
        read -r -p "$prompt_msg" val </dev/tty || val=""
      else
        val=""
      fi
    fi
  fi
  printf -v "$var_name" '%s' "$val"
}

confirm() {
  local soru="$1"
  local varsayilan="${2:-E}" # E veya H
  local yanit=""
  local secenek_metni="[E/h]"

  [[ "$varsayilan" =~ ^[Hh]$ ]] && secenek_metni="[e/H]"
  local prompt_str
  prompt_str="$(echo -e "${KALIN}${SARI}?${RESET} ${soru} ${secenek_metni}: ")"

  if [[ -t 0 ]]; then
    read -r -p "$prompt_str" yanit
  else
    if ! read -r yanit; then
      if [[ -r /dev/tty ]]; then
        read -r -p "$prompt_str" yanit </dev/tty || yanit="$varsayilan"
      else
        yanit="$varsayilan"
      fi
    fi
  fi

  yanit="${yanit:-$varsayilan}"
  case "$yanit" in
    [eE][vV][eE][tT]|[eE]|[yY][eE][sS]|[yY]) return 0 ;;
    *) return 1 ;;
  esac
}

url_encode() {
  jq -nr --arg q "$1" '$q|@uri'
}

get_installed_version() {
  local pkg="$1"
  local line
  line=$(pacman -Q "$pkg" 2>/dev/null || true)
  if [[ -n "$line" ]]; then
    local installed_name installed_ver
    installed_name=$(awk '{print $1}' <<< "$line")
    installed_ver=$(awk '{print $2}' <<< "$line")
    if [[ "$installed_name" == "$pkg" ]]; then
      echo "$installed_ver"
    else
      echo "provider:${installed_name}:${installed_ver}"
    fi
  fi
}

fetch_pkg_info() {
  local pkgname="$1"
  local encoded_pkg
  encoded_pkg=$(url_encode "$pkgname")

  local response
  response=$(curl -sSf "${AUR_RPC_URL}/info/${encoded_pkg}" 2>/dev/null || echo '{"resultcount":0,"results":[]}')
  echo "$response"
}

show_package_details() {
  local pkg_json="$1"
  
  local name version desc url maintainer votes pop license out_of_date depends makedepends
  name=$(jq -r '.results[0].Name // "Bilinmiyor"' <<< "$pkg_json")
  version=$(jq -r '.results[0].Version // "Bilinmiyor"' <<< "$pkg_json")
  desc=$(jq -r '.results[0].Description // "Açıklama bulunmuyor."' <<< "$pkg_json")
  url=$(jq -r '.results[0].URL // "-"' <<< "$pkg_json")
  maintainer=$(jq -r '.results[0].Maintainer // "Öksüz (Maintainer yok)"' <<< "$pkg_json")
  votes=$(jq -r '.results[0].NumVotes // 0' <<< "$pkg_json")
  pop=$(jq -r '.results[0].Popularity // 0' <<< "$pkg_json")
  license=$(jq -r '(.results[0].License // []) | join(", ")' <<< "$pkg_json")
  out_of_date=$(jq -r '.results[0].OutOfDate // empty' <<< "$pkg_json")
  depends=$(jq -r '(.results[0].Depends // []) | join(" ")' <<< "$pkg_json")
  makedepends=$(jq -r '(.results[0].MakeDepends // []) | join(" ")' <<< "$pkg_json")

  local kurulu_surum
  kurulu_surum=$(get_installed_version "$name")

  baslik "Paket Bilgileri: ${name}"
  echo -e "  ${KALIN}Paket Adı       :${RESET} ${YESIL}${name}${RESET}"
  echo -e "  ${KALIN}Sürüm           :${RESET} ${SARI}${version}${RESET}"

  if [[ -n "$kurulu_surum" ]]; then
    if [[ "$kurulu_surum" == provider:* ]]; then
      local prov_name prov_ver
      prov_name=$(cut -d: -f2 <<< "$kurulu_surum")
      prov_ver=$(cut -d: -f3 <<< "$kurulu_surum")
      echo -e "  ${KALIN}Kurulum Durumu  :${RESET} ${CYAN}[Farklı Paket Sağlıyor: ${prov_name} (${prov_ver})]${RESET}"
    elif [[ "$kurulu_surum" == "$version" ]]; then
      echo -e "  ${KALIN}Kurulum Durumu  :${RESET} ${YESIL}[Kurulu ve Güncel: ${kurulu_surum}]${RESET}"
    else
      echo -e "  ${KALIN}Kurulum Durumu  :${RESET} ${MOR}[Kurulu: ${kurulu_surum} -> AUR: ${version}]${RESET}"
    fi
  else
    echo -e "  ${KALIN}Kurulum Durumu  :${RESET} ${GRI}[Kurulu Değil]${RESET}"
  fi

  if [[ -n "$out_of_date" ]]; then
    echo -e "  ${KALIN}Güncellik       :${RESET} ${KIRMIZI}[GÜNCEL DEĞİL - Out of Date]${RESET}"
  else
    echo -e "  ${KALIN}Güncellik       :${RESET} ${YESIL}[Güncel]${RESET}"
  fi

  echo -e "  ${KALIN}Popülerlik / Oy :${RESET} ${MAVI}Pop: ${pop}${RESET} | ${CYAN}Oy: ${votes}${RESET}"
  echo -e "  ${KALIN}Bakımcı         :${RESET} ${maintainer}"
  echo -e "  ${KALIN}Lisans          :${RESET} ${license:-Belirtilmemiş}"
  echo -e "  ${KALIN}Web Sitesi      :${RESET} ${url}"
  [[ -n "$depends" ]] && echo -e "  ${KALIN}Bağımlılıklar   :${RESET} ${depends}"
  [[ -n "$makedepends" ]] && echo -e "  ${KALIN}Derleme Bağ.    :${RESET} ${makedepends}"
  echo -e "  ${KALIN}Açıklama        :${RESET} ${desc}"
  echo -e "${KALIN}${MAVI}----------------------------------------------------------------------${RESET}"
}

find_missing_aur_deps() {
  local pkg_json="$1"
  local deps_list
  deps_list=$(jq -r '((.results[0].Depends // []) + (.results[0].MakeDepends // []))[]' <<< "$pkg_json" 2>/dev/null || true)

  local missing_aur=()
  while IFS= read -r raw_dep; do
    [[ -z "$raw_dep" ]] && continue
    local clean_dep="${raw_dep%%[<>=]*}"

    if ! pacman -Qi "$clean_dep" &>/dev/null && ! pacman -Si "$clean_dep" &>/dev/null; then
      local chk
      chk=$(curl -sSf "${AUR_RPC_URL}/info/$(url_encode "$clean_dep")" 2>/dev/null || echo '{"resultcount":0}')
      local count
      count=$(jq -r '.resultcount // 0' <<< "$chk")
      if [[ "$count" -gt 0 ]]; then
        missing_aur+=("$clean_dep")
      fi
    fi
  done <<< "$deps_list"

  echo "${missing_aur[@]}"
}

install_aur_package() {
  local pkgname="$1"
  local skip_confirm="${2:-false}"

  log "'$pkgname' paketi için AUR bilgileri alınıyor..."
  local pkg_json
  pkg_json=$(fetch_pkg_info "$pkgname")

  local count
  count=$(jq -r '.resultcount // 0' <<< "$pkg_json")
  if [[ "$count" -eq 0 ]]; then
    hata "'$pkgname' adında bir AUR paketi bulunamadı!"
    return 1
  fi

  show_package_details "$pkg_json"

  if [[ "$skip_confirm" != "true" ]]; then
    if ! confirm "'${pkgname}' paketi indirilip kurulsun mu?" "E"; then
      uyari "İşlem iptal edildi. '${pkgname}' indirilmeyecek."
      return 0
    fi
  fi

  log "Bağımlılıklar denetleniyor..."
  local aur_deps
  read -r -a aur_deps <<< "$(find_missing_aur_deps "$pkg_json")"

  if [[ ${#aur_deps[@]} -gt 0 ]]; then
    uyari "Paketin derlenebilmesi için gereken AUR bağımlılıkları tespit edildi: ${aur_deps[*]}"
    if confirm "Bu AUR bağımlılıklarının önce kurulması gerekiyor. Devam edilsin mi?" "E"; then
      for dep_pkg in "${aur_deps[@]}"; do
        log "AUR bağımlılığı kuruluyor: $dep_pkg"
        install_aur_package "$dep_pkg" "false" || {
          hata "Bağımlılık ($dep_pkg) kurulamadığı için '${pkgname}' kurulumu durduruldu."
          return 1
        }
      done
    else
      hata "Gerekli bağımlılıklar kurulmadan '${pkgname}' derlenemez."
      return 1
    fi
  fi

  mkdir -p "$CACHE_DIR"
  local pkg_dir="${CACHE_DIR}/${pkgname}"

  baslik "2. Kaynak Kodları İndiriliyor: ${pkgname}"
  if [[ -d "$pkg_dir/.git" ]]; then
    log "Mevcut yerel depo güncelleniyor: $pkg_dir"
    if ! git -C "$pkg_dir" pull --ff-only; then
      uyari "Yerel depoda çakışma var, temiz kopya çekiliyor..."
      rm -rf "$pkg_dir"
      git clone --depth=1 "${AUR_GIT_URL}/${pkgname}.git" "$pkg_dir" || {
        hata "Git deposu klonlanamadı: ${AUR_GIT_URL}/${pkgname}.git"
        return 1
      }
    fi
  else
    log "AUR'dan klonlanıyor: ${AUR_GIT_URL}/${pkgname}.git"
    git clone --depth=1 "${AUR_GIT_URL}/${pkgname}.git" "$pkg_dir" || {
      hata "Git deposu klonlanamadı: ${AUR_GIT_URL}/${pkgname}.git"
      return 1
    }
  fi

  if [[ ! -f "$pkg_dir/PKGBUILD" ]]; then
    hata "HATA: '${pkgname}' dizininde PKGBUILD dosyası bulunamadı!"
    return 1
  fi

  if confirm "PKGBUILD dosyasını incelemek ister misiniz?" "H"; then
    if [[ -t 0 ]] && command -v less &>/dev/null; then
      less "$pkg_dir/PKGBUILD"
    elif [[ -t 0 ]] && command -v nano &>/dev/null; then
      nano -v "$pkg_dir/PKGBUILD"
    else
      echo -e "\n${KALIN}--- PKGBUILD İÇERİĞİ ---${RESET}"
      cat "$pkg_dir/PKGBUILD"
      echo -e "${KALIN}--- İÇERİK SONU ---${RESET}\n"
    fi

    if ! confirm "PKGBUILD incelendi. Derleme ve kuruluma devam edilsin mi?" "E"; then
      uyari "Kurulum kullanıcı tarafından durduruldu."
      return 0
    fi
  fi

  log "Kurulum adımı için sudo yetkisi doğrulanıyor..."
  sudo -v || {
    hata "Sudo yetkisi alınamadı."
    return 1
  }

  baslik "3. Paket Derleniyor ve Kuruluyor (makepkg)"
  log "Dizin: $pkg_dir"
  log "Komut: makepkg -si --needed"

  (
    cd "$pkg_dir" || exit 1
    makepkg -si --needed
  )
  local makepkg_status=$?

  if [[ $makepkg_status -eq 0 ]]; then
    local yeni_surum
    yeni_surum=$(get_installed_version "$pkgname")
    basari "'${pkgname}' (${yeni_surum:-başarılı}) başarıyla kuruldu!"
    return 0
  else
    hata "'${pkgname}' paketinin derlenmesi veya kurulması başarısız oldu (Hata Kodu: ${makepkg_status})."
    return 1
  fi
}

resolve_package_selection() {
  local input="$1"
  shift
  local available_pkgs=("$@")

  input=$(echo "$input" | xargs)
  [[ -z "$input" ]] && return 1

  if [[ "$input" =~ ^[0-9]+$ ]] && (( input >= 1 && input <= ${#available_pkgs[@]} )); then
    echo "${available_pkgs[$((input - 1))]}"
    return 0
  fi

  local lower_input
  lower_input=$(echo "$input" | tr '[:upper:]' '[:lower:]')
  for p in "${available_pkgs[@]}"; do
    local lower_p
    lower_p=$(echo "$p" | tr '[:upper:]' '[:lower:]')
    if [[ "$lower_p" == "$lower_input" ]]; then
      echo "$p"
      return 0
    fi
  done

  if [[ ${#lower_input} -ge 2 ]]; then
    for p in "${available_pkgs[@]}"; do
      local lower_p
      lower_p=$(echo "$p" | tr '[:upper:]' '[:lower:]')
      if [[ "$lower_p" == "$lower_input"* ]]; then
        echo "$p"
        return 0
      fi
    done
  fi

  if [[ ${#lower_input} -ge 3 ]]; then
    for p in "${available_pkgs[@]}"; do
      local lower_p
      lower_p=$(echo "$p" | tr '[:upper:]' '[:lower:]')
      if [[ "$lower_p" == *"$lower_input"* ]]; then
        echo "$p"
        return 0
      fi
    done
  fi

  return 1
}

search_and_select_package() {
  local query="$1"

  log "AUR'da aranıyor: '$query'..."
  local encoded_query
  encoded_query=$(url_encode "$query")

  local response
  response=$(curl -sSf "${AUR_RPC_URL}/search/${encoded_query}" 2>/dev/null || true)

  if [[ -z "$response" ]]; then
    hata "AUR sunucusuna bağlanılamadı. Lütfen internet bağlantınızı kontrol ediniz."
    return 1
  fi

  local error_msg
  error_msg=$(jq -r '.error // empty' <<< "$response" 2>/dev/null || true)
  if [[ -n "$error_msg" ]]; then
    hata "AUR RPC Hatası: $error_msg"
    return 1
  fi

  local count
  count=$(jq -r '.resultcount // 0' <<< "$response" 2>/dev/null || echo 0)

  if [[ "$count" -eq 0 ]]; then
    uyari "'$query' ile eşleşen hiçbir AUR paketi bulunamadı."
    return 0
  fi

  local sorted_packages
  sorted_packages=$(jq -r --arg q "$query" '
    .results | sort_by([
      (if (.Name | ascii_downcase) == ($q | ascii_downcase) then 0
       elif (.Name | ascii_downcase | startswith($q | ascii_downcase)) then 1
       elif (.Name | ascii_downcase | contains($q | ascii_downcase)) then 2
       else 3 end),
      -(.Popularity // 0)
    ]) | .[0:25][] |
    "\(.Name)\t\(.Version)\t\(.Popularity // 0)\t\(.NumVotes // 0)\t\(.OutOfDate // 0)\t\(.Description // "Açıklama yok.")"
  ' <<< "$response")

  local pkg_names=()
  local pkg_versions=()
  local pkg_pops=()
  local pkg_votes=()
  local pkg_ood=()
  local pkg_descs=()

  while IFS=$'\t' read -r name version pop votes ood desc; do
    [[ -z "$name" ]] && continue
    pkg_names+=("$name")
    pkg_versions+=("$version")
    pkg_pops+=("$pop")
    pkg_votes+=("$votes")
    pkg_ood+=("$ood")
    pkg_descs+=("$desc")
  done <<< "$sorted_packages"

  local total_results=${#pkg_names[@]}
  local default_pkg="${pkg_names[0]}"

  baslik "AUR'da Bulunan Paketler: '$query' (${total_results} paket)"

  for ((i=0; i<total_results; i++)); do
    local p_name="${pkg_names[$i]}"
    local p_ver="${pkg_versions[$i]}"
    local p_pop="${pkg_pops[$i]}"
    local p_vote="${pkg_votes[$i]}"
    local p_ood="${pkg_ood[$i]}"
    local p_desc="${pkg_descs[$i]}"

    local inst_ver
    inst_ver=$(get_installed_version "$p_name")
    local status_badge="${GRI}[Kurulu Değil]${RESET}"
    if [[ -n "$inst_ver" ]]; then
      if [[ "$inst_ver" == provider:* ]]; then
        local prov_name prov_ver
        prov_name=$(cut -d: -f2 <<< "$inst_ver")
        prov_ver=$(cut -d: -f3 <<< "$inst_ver")
        status_badge="${CYAN}[Sağlayıcı: ${prov_name} ${prov_ver}]${RESET}"
      elif [[ "$inst_ver" == "$p_ver" ]]; then
        status_badge="${YESIL}[Kurulu: ${inst_ver}]${RESET}"
      else
        status_badge="${MOR}[Kurulu: ${inst_ver} -> ${p_ver}]${RESET}"
      fi
    fi

    local ood_badge=""
    if [[ "$p_ood" != "0" && "$p_ood" != "null" ]]; then
      ood_badge=" ${KIRMIZI}[GÜNCEL DEĞİL]${RESET}"
    fi

    printf "  ${KALIN}${YESIL}• %-26s${RESET} ${SARI}%-18s${RESET} %b%b ${MAVI}(Pop: %.2f | +%s)${RESET}\n" \
      "$p_name" "$p_ver" "$status_badge" "$ood_badge" "$p_pop" "$p_vote"
    printf "    ${GRI}%s${RESET}\n" "$p_desc"
  done

  echo -e "${KALIN}${MAVI}----------------------------------------------------------------------${RESET}"

  while true; do
    local secim=""
    read_prompt "$(echo -e "${KALIN}${CYAN}?${RESET} Kurmak istediğiniz paketin adını girin ${KALIN}[Enter: ${default_pkg}, q: İptal]${RESET}: ")" secim
    secim=$(echo "$secim" | xargs)

    if [[ "$secim" =~ ^[qQ]$ ]]; then
      log "Arama iptal edildi."
      return 0
    fi

    [[ -z "$secim" ]] && secim="$default_pkg"

    local secilen_paket
    secilen_paket=$(resolve_package_selection "$secim" "${pkg_names[@]}" || true)

    if [[ -z "$secilen_paket" ]]; then
      local direct_json
      direct_json=$(fetch_pkg_info "$secim")
      if [[ $(jq -r '.resultcount // 0' <<< "$direct_json") -eq 1 ]]; then
        secilen_paket="$secim"
      fi
    fi

    if [[ -n "$secilen_paket" ]]; then
      log "Paket seçildi: $secilen_paket"
      install_aur_package "$secilen_paket" "false"
      return $?
    else
      uyari "'$secim' adında bir paket listede veya AUR'da bulunamadı. Lütfen paket adını kontrol edin veya 'q' ile çıkın."
    fi
  done
}

find_and_install_package() {
  local query="$1"
  query=$(echo "$query" | xargs)

  if [[ -z "$query" ]]; then
    uyari "Lütfen bir paket adı veya arama terimi giriniz."
    return 1
  fi

  if [[ ${#query} -lt 2 ]]; then
    uyari "Paket adı en az 2 karakter olmalıdır."
    return 1
  fi

  if pacman -Si "$query" &>/dev/null; then
    local repo_info
    repo_info=$(pacman -Si "$query" 2>/dev/null | grep -E "^(Repository|Version|Description)" | sed 's/^/  /' || true)
    basari "'${query}' resmi Arch/CachyOS depolarında mevcut!"
    [[ -n "$repo_info" ]] && echo -e "${GRI}${repo_info}${RESET}"
    if confirm "'${query}' paketi resmi depodan pacman ile kurulsun mu?" "E"; then
      sudo pacman -S --needed "$query"
      return $?
    else
      log "Resmi depo kurulumu atlandı. AUR aranıyor..."
    fi
  fi

  log "AUR kontrol ediliyor: '$query'..."
  local exact_json
  exact_json=$(fetch_pkg_info "$query")
  local exact_count
  exact_count=$(jq -r '.resultcount // 0' <<< "$exact_json" 2>/dev/null || echo 0)

  if [[ "$exact_count" -eq 1 ]]; then
    basari "'${query}' paketi AUR'da doğrudan bulundu!"
    install_aur_package "$query" "false"
    return $?
  fi

  search_and_select_package "$query"
}

search_aur() {
  find_and_install_package "$@"
}

fzf_search() {
  if ! command -v fzf &>/dev/null; then
    uyari "'fzf' aracı sisteminizde kurulu değil. Normal arama moduna geçiliyor..."
    search_aur "${1:-}"
    return $?
  fi

  local query="${1:-}"
  if [[ -z "$query" ]]; then
    read_prompt "$(echo -e "${KALIN}${CYAN}?${RESET} fzf ile aranacak paket adını girin: ")" query
  fi

  query=$(echo "$query" | xargs)
  [[ -z "$query" ]] && return 0

  log "AUR listesi fzf için hazırlanıyor..."
  local encoded_query
  encoded_query=$(url_encode "$query")

  local response
  response=$(curl -sSf "${AUR_RPC_URL}/search/${encoded_query}" 2>/dev/null || true)
  local count
  count=$(jq -r '.resultcount // 0' <<< "$response" 2>/dev/null || echo 0)

  if [[ "$count" -eq 0 ]]; then
    uyari "'$query' ile eşleşen hiçbir AUR paketi bulunamadı."
    return 0
  fi

  local fzf_input
  fzf_input=$(jq -r '
    .results | sort_by(-.Popularity)[] |
    "\(.Name)\t\(.Version)\t\(.NumVotes)\t\(.Popularity)\t\(.Description // "Açıklama yok")"
  ' <<< "$response")

  local secilen_satir
  secilen_satir=$(echo "$fzf_input" | fzf \
    --delimiter=$'\t' \
    --with-nth=1,2,5 \
    --preview="echo -e 'Paket: {1}\nSürüm: {2}\nOylar: {3} | Pop: {4}\n\nAçıklama:\n{5}'" \
    --preview-window=right:50%:wrap \
    --prompt="AUR Paket Seç > " \
    --header="ENTER: Seç | ESC: Çıkış") || true

  if [[ -n "$secilen_satir" ]]; then
    local secilen_paket
    secilen_paket=$(awk -F$'\t' '{print $1}' <<< "$secilen_satir")
    install_aur_package "$secilen_paket" "false"
  else
    log "Seçim yapılmadı, çıkıldı."
  fi
}

update_aur_packages() {
  baslik "Kurulu AUR Paketleri Güncelleme Kontrolü"
  log "Sistemdeki yabancı (AUR) paketler taranıyor..."

  local foreign_pkgs
  foreign_pkgs=$(pacman -Qm 2>/dev/null || true)

  if [[ -z "$foreign_pkgs" ]]; then
    basari "Sisteminizde AUR üzerinden kurulmuş hiçbir paket bulunmuyor."
    return 0
  fi

  declare -A local_versions
  local args=""
  local total_foreign=0

  while read -r pkg local_ver; do
    [[ -z "$pkg" ]] && continue
    local_versions["$pkg"]="$local_ver"
    args="${args}&arg[]=$(url_encode "$pkg")"
    ((total_foreign++))
  done <<< "$foreign_pkgs"

  log "${total_foreign} paket AUR RPC üzerinden sorgulanıyor..."
  local multi_json
  multi_json=$(curl -sSf "${AUR_RPC_URL}/info?${args#&}" 2>/dev/null || echo '{"results":[]}')

  local guncellenecekler=()
  local guncel_sayisi=0

  while IFS=$'\t' read -r pkg aur_ver; do
    [[ -z "$pkg" || -z "$aur_ver" ]] && continue
    local local_ver="${local_versions["$pkg"]:-}"
    if [[ -n "$local_ver" ]]; then
      local cmp
      cmp=$(vercmp "$local_ver" "$aur_ver" 2>/dev/null || echo 0)
      if [[ "$cmp" -lt 0 ]]; then
        guncellenecekler+=("${pkg}|${local_ver}|${aur_ver}")
      else
        ((guncel_sayisi++))
      fi
    fi
  done < <(jq -r '.results[] | "\(.Name)\t\(.Version)"' <<< "$multi_json")

  if [[ ${#guncellenecekler[@]} -eq 0 ]]; then
    basari "Tüm AUR paketleriniz güncel! (${guncel_sayisi} paket kontrol edildi)"
    return 0
  fi

  baslik "Güncellemesi Bulunan AUR Paketleri (${#guncellenecekler[@]} adet)"
  for item in "${guncellenecekler[@]}"; do
    local p l a
    IFS='|' read -r p l a <<< "$item"
    echo -e "  ${KALIN}${YESIL}${p}${RESET}: ${KIRMIZI}${l}${RESET} -> ${YESIL}${a}${RESET}"
  done
  echo -e "${KALIN}${MAVI}----------------------------------------------------------------------${RESET}"

  if confirm "Bu paketler güncellensin mi?" "E"; then
    for item in "${guncellenecekler[@]}"; do
      local p l a
      IFS='|' read -r p l a <<< "$item"
      log "Güncelleniyor: $p ($l -> $a)"
      install_aur_package "$p" "true" || uyari "$p güncellenemedi, diğerine geçiliyor."
    done
    basari "AUR güncelleme işlemleri tamamlandı."
  else
    log "Güncelleme kullanıcı tarafından atlandı."
  fi
}

clean_cache() {
  baslik "Derleme Önbelleği Temizliği"
  if [[ -d "$CACHE_DIR" ]]; then
    local boyut
    boyut=$(du -sh "$CACHE_DIR" 2>/dev/null | awk '{print $1}')
    log "Önbellek Dizini: $CACHE_DIR (${boyut})"
    if confirm "Derleme önbelleği tamamen silinsin mi?" "E"; then
      rm -rf "$CACHE_DIR"
      basari "Önbellek başarıyla temizlendi."
    else
      log "Temizlik işlemi iptal edildi."
    fi
  else
    basari "Temizlenecek önbellek bulunamadı ($CACHE_DIR mevcut değil)."
  fi
}

show_help() {
  banner
  echo -e "${KALIN}KULLANIM:${RESET}"
  echo -e "  $0 [seçenekler] [paket_adı|arama_terimi]\n"
  echo -e "${KALIN}AÇIKLAMA:${RESET}"
  echo -e "  Parametresiz çalıştırıldığında script içinden doğrudan paket adını sorar."
  echo -e "  İndeks numarası zorunluluğu yoktur; paket adını doğrudan yazarak kurabilirsiniz.\n"
  echo -e "${KALIN}SEÇENEKLER:${RESET}"
  echo -e "  ${YESIL}<paket_adı>${RESET}              Paket adını doğrudan arar, eşleşirse hemen onaylayıp kurar"
  echo -e "  ${YESIL}-s, --search <terim>${RESET}     AUR'da paket arar ve doğrudan paket adı girişiyle seçim sunar"
  echo -e "  ${YESIL}-i, --install <paket>${RESET}    Belirtilen paketi onay ile doğrudan indirir ve kurar"
  echo -e "  ${YESIL}-u, --update${RESET}             Sistemdeki tüm AUR paketlerini kontrol eder ve günceller"
  echo -e "  ${YESIL}-c, --clean${RESET}              İndirilmiş paket önbelleğini temizler (${CACHE_DIR})"
  echo -e "  ${YESIL}-f, --fzf [terim]${RESET}        fzf kullanarak etkileşimli fuzzy arama yapar"
  echo -e "  ${YESIL}-h, --help${RESET}               Bu yardım ekranını gösterir\n"
  echo -e "${KALIN}ÖRNEKLER:${RESET}"
  echo -e "  $0                       (Script içinden doğrudan paket adı girme)"
  echo -e "  $0 spotify               (spotify paketini doğrudan bul ve sor)"
  echo -e "  $0 -u                    (Tüm AUR paketlerini güncelle)\n"
}

main() {
  check_root
  check_dependencies

  if [[ $# -eq 0 ]]; then
    banner
    while true; do
      local arama_kelimesi=""
      read_prompt "$(echo -e "\n${KALIN}${MAVI}?${RESET} Kurmak veya aramak istediğiniz paket adını girin ${KALIN}[q: Çıkış]${RESET}: ")" arama_kelimesi

      arama_kelimesi=$(echo "$arama_kelimesi" | xargs)
      [[ -z "$arama_kelimesi" ]] && continue
      [[ "$arama_kelimesi" =~ ^[qQ]$ ]] && { log "Çıkış yapıldı."; exit 0; }

      find_and_install_package "$arama_kelimesi"
    done
  fi

  case "$1" in
    -h|--help)
      show_help
      exit 0
      ;;
    -s|--search)
      shift
      if [[ $# -eq 0 ]]; then
        hata "Lütfen aranacak bir kelime girin. Örn: $0 -s spotify"
        exit 1
      fi
      find_and_install_package "$*"
      ;;
    -i|--install)
      shift
      if [[ $# -eq 0 ]]; then
        hata "Lütfen kurulacak paket adını girin. Örn: $0 -i google-chrome"
        exit 1
      fi
      install_aur_package "$1" "false"
      ;;
    -u|--update)
      update_aur_packages
      ;;
    -c|--clean)
      clean_cache
      ;;
    -f|--fzf)
      shift
      fzf_search "${1:-}"
      ;;
    *)
      find_and_install_package "$*"
      ;;
  esac
}

main "$@"
