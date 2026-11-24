#!/usr/bin/env bash
set -uo pipefail
export LC_NUMERIC=C

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
PURPLE='\033[0;35m'
CYAN='\033[1;36m'
GRAY='\033[0;90m'
BOLD='\033[1m'
RESET='\033[0m'

AUR_RPC_URL="https://aur.archlinux.org/rpc/v5"
AUR_GIT_URL="https://aur.archlinux.org"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/aur_helper"

log()     { echo -e "${BLUE}[*]${RESET} $1"; }
success() { echo -e "${GREEN}[✓]${RESET} $1"; }
warn()    { echo -e "${YELLOW}[!]${RESET} $1"; }
error()   { echo -e "${RED}[✗]${RESET} $1"; }

header() {
  echo -e "\n${BOLD}${BLUE}======================================================================${RESET}"
  echo -e "${BOLD}${BLUE} $1${RESET}"
  echo -e "${BOLD}${BLUE}======================================================================${RESET}"
}

banner() {
  echo -e "${BOLD}${CYAN}"
  cat << "EOF"
    ___   __  ______     __  __     __                  
   /   | / / / / __ \   / / / /__  / /___  ___  _____   
  / /| |/ / / / /_/ /  / /_/ / _ \/ / __ \/ _ \/ ___/   
 / ___ / /_/ / _, _/  / __  /  __/ / /_/ /  __/ /       
/_/  |_\____/_/ |_|  /_/ /_/\___/_/ .___/\___/_/        
                                 /_/                    
EOF
  echo -e "${RESET}${GRAY}Arch User Repository (AUR) Automated Package Search & Install Tool${RESET}\n"
}

check_root() {
  if [[ $EUID -eq 0 ]]; then
    error "This script must not be run as root!"
    warn "makepkg does not allow building packages as root for security reasons."
    warn "Please run as a regular user. sudo will be requested when needed."
    exit 1
  fi
}

check_dependencies() {
  local missing=()
  local required=("curl" "jq" "git" "makepkg" "pacman")

  for cmd in "${required[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
      missing+=("$cmd")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    warn "Missing required dependencies: ${missing[*]}"
    if confirm "Install missing dependencies with pacman?" "Y"; then
      sudo pacman -S --needed --noconfirm "${missing[@]}" || {
        error "Failed to install dependencies. Please install manually: sudo pacman -S ${missing[*]}"
        exit 1
      }
    else
      error "Cannot proceed without required dependencies."
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
  local question="$1"
  local default="${2:-Y}"
  local answer=""
  local options="[Y/n]"

  [[ "$default" =~ ^[Nn]$ ]] && options="[y/N]"
  local prompt_str
  prompt_str="$(echo -e "${BOLD}${YELLOW}?${RESET} ${question} ${options}: ")"

  if [[ -t 0 ]]; then
    read -r -p "$prompt_str" answer
  else
    if ! read -r answer; then
      if [[ -r /dev/tty ]]; then
        read -r -p "$prompt_str" answer </dev/tty || answer="$default"
      else
        answer="$default"
      fi
    fi
  fi

  answer="${answer:-$default}"
  case "$answer" in
    [yY][eE][sS]|[yY]) return 0 ;;
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
  name=$(jq -r '.results[0].Name // "Unknown"' <<< "$pkg_json")
  version=$(jq -r '.results[0].Version // "Unknown"' <<< "$pkg_json")
  desc=$(jq -r '.results[0].Description // "No description available."' <<< "$pkg_json")
  url=$(jq -r '.results[0].URL // "-"' <<< "$pkg_json")
  maintainer=$(jq -r '.results[0].Maintainer // "Orphaned (No maintainer)"' <<< "$pkg_json")
  votes=$(jq -r '.results[0].NumVotes // 0' <<< "$pkg_json")
  pop=$(jq -r '.results[0].Popularity // 0' <<< "$pkg_json")
  license=$(jq -r '(.results[0].License // []) | join(", ")' <<< "$pkg_json")
  out_of_date=$(jq -r '.results[0].OutOfDate // empty' <<< "$pkg_json")
  depends=$(jq -r '(.results[0].Depends // []) | join(" ")' <<< "$pkg_json")
  makedepends=$(jq -r '(.results[0].MakeDepends // []) | join(" ")' <<< "$pkg_json")

  local installed_ver
  installed_ver=$(get_installed_version "$name")

  header "Package Details: ${name}"
  echo -e "  ${BOLD}Package Name    :${RESET} ${GREEN}${name}${RESET}"
  echo -e "  ${BOLD}Version         :${RESET} ${YELLOW}${version}${RESET}"

  if [[ -n "$installed_ver" ]]; then
    if [[ "$installed_ver" == provider:* ]]; then
      local prov_name prov_ver
      prov_name=$(cut -d: -f2 <<< "$installed_ver")
      prov_ver=$(cut -d: -f3 <<< "$installed_ver")
      echo -e "  ${BOLD}Install Status  :${RESET} ${CYAN}[Provided by: ${prov_name} (${prov_ver})]${RESET}"
    elif [[ "$installed_ver" == "$version" ]]; then
      echo -e "  ${BOLD}Install Status  :${RESET} ${GREEN}[Installed & Up to Date: ${installed_ver}]${RESET}"
    else
      echo -e "  ${BOLD}Install Status  :${RESET} ${PURPLE}[Installed: ${installed_ver} -> AUR: ${version}]${RESET}"
    fi
  else
    echo -e "  ${BOLD}Install Status  :${RESET} ${GRAY}[Not Installed]${RESET}"
  fi

  if [[ -n "$out_of_date" ]]; then
    echo -e "  ${BOLD}Freshness       :${RESET} ${RED}[OUT OF DATE]${RESET}"
  else
    echo -e "  ${BOLD}Freshness       :${RESET} ${GREEN}[Up to Date]${RESET}"
  fi

  echo -e "  ${BOLD}Popularity/Votes:${RESET} ${BLUE}Pop: ${pop}${RESET} | ${CYAN}Votes: ${votes}${RESET}"
  echo -e "  ${BOLD}Maintainer      :${RESET} ${maintainer}"
  echo -e "  ${BOLD}License         :${RESET} ${license:-Not specified}"
  echo -e "  ${BOLD}Website         :${RESET} ${url}"
  [[ -n "$depends" ]] && echo -e "  ${BOLD}Dependencies    :${RESET} ${depends}"
  [[ -n "$makedepends" ]] && echo -e "  ${BOLD}Build Deps      :${RESET} ${makedepends}"
  echo -e "  ${BOLD}Description     :${RESET} ${desc}"
  echo -e "${BOLD}${BLUE}----------------------------------------------------------------------${RESET}"
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

  log "Fetching AUR info for '$pkgname'..."
  local pkg_json
  pkg_json=$(fetch_pkg_info "$pkgname")

  local count
  count=$(jq -r '.resultcount // 0' <<< "$pkg_json")
  if [[ "$count" -eq 0 ]]; then
    error "No AUR package found with name '$pkgname'!"
    return 1
  fi

  show_package_details "$pkg_json"

  if [[ "$skip_confirm" != "true" ]]; then
    if ! confirm "Download and install '${pkgname}'?" "Y"; then
      warn "Operation cancelled. '${pkgname}' will not be downloaded."
      return 0
    fi
  fi

  log "Checking dependencies..."
  local aur_deps
  read -r -a aur_deps <<< "$(find_missing_aur_deps "$pkg_json")"

  if [[ ${#aur_deps[@]} -gt 0 ]]; then
    warn "AUR dependencies required for building: ${aur_deps[*]}"
    if confirm "These AUR dependencies need to be installed first. Continue?" "Y"; then
      for dep_pkg in "${aur_deps[@]}"; do
        log "Installing AUR dependency: $dep_pkg"
        install_aur_package "$dep_pkg" "false" || {
          error "Dependency ($dep_pkg) failed. Aborting '${pkgname}' installation."
          return 1
        }
      done
    else
      error "Cannot build '${pkgname}' without required dependencies."
      return 1
    fi
  fi

  mkdir -p "$CACHE_DIR"
  local pkg_dir="${CACHE_DIR}/${pkgname}"

  header "Downloading Sources: ${pkgname}"
  if [[ -d "$pkg_dir/.git" ]]; then
    log "Updating existing local repo: $pkg_dir"
    if ! git -C "$pkg_dir" pull --ff-only; then
      warn "Local repo has conflicts, cloning fresh copy..."
      rm -rf "$pkg_dir"
      git clone --depth=1 "${AUR_GIT_URL}/${pkgname}.git" "$pkg_dir" || {
        error "Failed to clone: ${AUR_GIT_URL}/${pkgname}.git"
        return 1
      }
    fi
  else
    log "Cloning from AUR: ${AUR_GIT_URL}/${pkgname}.git"
    git clone --depth=1 "${AUR_GIT_URL}/${pkgname}.git" "$pkg_dir" || {
      error "Failed to clone: ${AUR_GIT_URL}/${pkgname}.git"
      return 1
    }
  fi

  if [[ ! -f "$pkg_dir/PKGBUILD" ]]; then
    error "PKGBUILD not found in '${pkgname}' directory!"
    return 1
  fi

  if confirm "Would you like to review the PKGBUILD?" "N"; then
    if [[ -t 0 ]] && command -v less &>/dev/null; then
      less "$pkg_dir/PKGBUILD"
    elif [[ -t 0 ]] && command -v nano &>/dev/null; then
      nano -v "$pkg_dir/PKGBUILD"
    else
      echo -e "\n${BOLD}--- PKGBUILD CONTENTS ---${RESET}"
      cat "$pkg_dir/PKGBUILD"
      echo -e "${BOLD}--- END OF CONTENTS ---${RESET}\n"
    fi

    if ! confirm "PKGBUILD reviewed. Proceed with build and installation?" "Y"; then
      warn "Installation cancelled by user."
      return 0
    fi
  fi

  log "Verifying sudo privileges..."
  sudo -v || {
    error "Failed to obtain sudo privileges."
    return 1
  }

  header "Building and Installing (makepkg)"
  log "Directory: $pkg_dir"
  log "Command: makepkg -si --needed"

  (
    cd "$pkg_dir" || exit 1
    makepkg -si --needed
  )
  local makepkg_status=$?

  if [[ $makepkg_status -eq 0 ]]; then
    local new_ver
    new_ver=$(get_installed_version "$pkgname")
    success "'${pkgname}' (${new_ver:-OK}) installed successfully!"
    return 0
  else
    error "Failed to build or install '${pkgname}' (Exit Code: ${makepkg_status})."
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

  log "Searching AUR for '$query'..."
  local encoded_query
  encoded_query=$(url_encode "$query")

  local response
  response=$(curl -sSf "${AUR_RPC_URL}/search/${encoded_query}" 2>/dev/null || true)

  if [[ -z "$response" ]]; then
    error "Could not connect to AUR server. Please check your internet connection."
    return 1
  fi

  local error_msg
  error_msg=$(jq -r '.error // empty' <<< "$response" 2>/dev/null || true)
  if [[ -n "$error_msg" ]]; then
    error "AUR RPC Error: $error_msg"
    return 1
  fi

  local count
  count=$(jq -r '.resultcount // 0' <<< "$response" 2>/dev/null || echo 0)

  if [[ "$count" -eq 0 ]]; then
    warn "No AUR packages found matching '$query'."
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
    "\(.Name)\t\(.Version)\t\(.Popularity // 0)\t\(.NumVotes // 0)\t\(.OutOfDate // 0)\t\(.Description // "No description.")"
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

  header "AUR Packages Found: '$query' (${total_results} packages)"

  for ((i=0; i<total_results; i++)); do
    local p_name="${pkg_names[$i]}"
    local p_ver="${pkg_versions[$i]}"
    local p_pop="${pkg_pops[$i]}"
    local p_vote="${pkg_votes[$i]}"
    local p_ood="${pkg_ood[$i]}"
    local p_desc="${pkg_descs[$i]}"

    local inst_ver
    inst_ver=$(get_installed_version "$p_name")
    local status_badge="${GRAY}[Not Installed]${RESET}"
    if [[ -n "$inst_ver" ]]; then
      if [[ "$inst_ver" == provider:* ]]; then
        local prov_name prov_ver
        prov_name=$(cut -d: -f2 <<< "$inst_ver")
        prov_ver=$(cut -d: -f3 <<< "$inst_ver")
        status_badge="${CYAN}[Provider: ${prov_name} ${prov_ver}]${RESET}"
      elif [[ "$inst_ver" == "$p_ver" ]]; then
        status_badge="${GREEN}[Installed: ${inst_ver}]${RESET}"
      else
        status_badge="${PURPLE}[Installed: ${inst_ver} -> ${p_ver}]${RESET}"
      fi
    fi

    local ood_badge=""
    if [[ "$p_ood" != "0" && "$p_ood" != "null" ]]; then
      ood_badge=" ${RED}[OUT OF DATE]${RESET}"
    fi

    printf "  ${BOLD}${GREEN}• %-26s${RESET} ${YELLOW}%-18s${RESET} %b%b ${BLUE}(Pop: %.2f | +%s)${RESET}\n" \
      "$p_name" "$p_ver" "$status_badge" "$ood_badge" "$p_pop" "$p_vote"
    printf "    ${GRAY}%s${RESET}\n" "$p_desc"
  done

  echo -e "${BOLD}${BLUE}----------------------------------------------------------------------${RESET}"

  while true; do
    local selection=""
    read_prompt "$(echo -e "${BOLD}${CYAN}?${RESET} Enter the package name to install ${BOLD}[Enter: ${default_pkg}, q: Cancel]${RESET}: ")" selection
    selection=$(echo "$selection" | xargs)

    if [[ "$selection" =~ ^[qQ]$ ]]; then
      log "Search cancelled."
      return 0
    fi

    [[ -z "$selection" ]] && selection="$default_pkg"

    local selected_pkg
    selected_pkg=$(resolve_package_selection "$selection" "${pkg_names[@]}" || true)

    if [[ -z "$selected_pkg" ]]; then
      local direct_json
      direct_json=$(fetch_pkg_info "$selection")
      if [[ $(jq -r '.resultcount // 0' <<< "$direct_json") -eq 1 ]]; then
        selected_pkg="$selection"
      fi
    fi

    if [[ -n "$selected_pkg" ]]; then
      log "Package selected: $selected_pkg"
      install_aur_package "$selected_pkg" "false"
      return $?
    else
      warn "'$selection' was not found in the list or AUR. Please check the name or type 'q' to quit."
    fi
  done
}

find_and_install_package() {
  local query="$1"
  query=$(echo "$query" | xargs)

  if [[ -z "$query" ]]; then
    warn "Please enter a package name or search term."
    return 1
  fi

  if [[ ${#query} -lt 2 ]]; then
    warn "Package name must be at least 2 characters."
    return 1
  fi

  if pacman -Si "$query" &>/dev/null; then
    local repo_info
    repo_info=$(pacman -Si "$query" 2>/dev/null | grep -E "^(Repository|Version|Description)" | sed 's/^/  /' || true)
    success "'${query}' is available in the official Arch/CachyOS repositories!"
    [[ -n "$repo_info" ]] && echo -e "${GRAY}${repo_info}${RESET}"
    if confirm "Install '${query}' from official repos with pacman?" "Y"; then
      sudo pacman -S --needed "$query"
      return $?
    else
      log "Official repo install skipped. Searching AUR..."
    fi
  fi

  log "Checking AUR: '$query'..."
  local exact_json
  exact_json=$(fetch_pkg_info "$query")
  local exact_count
  exact_count=$(jq -r '.resultcount // 0' <<< "$exact_json" 2>/dev/null || echo 0)

  if [[ "$exact_count" -eq 1 ]]; then
    success "'${query}' found directly on AUR!"
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
    warn "'fzf' is not installed. Falling back to standard search..."
    search_aur "${1:-}"
    return $?
  fi

  local query="${1:-}"
  if [[ -z "$query" ]]; then
    read_prompt "$(echo -e "${BOLD}${CYAN}?${RESET} Enter package name for fzf search: ")" query
  fi

  query=$(echo "$query" | xargs)
  [[ -z "$query" ]] && return 0

  log "Preparing AUR results for fzf..."
  local encoded_query
  encoded_query=$(url_encode "$query")

  local response
  response=$(curl -sSf "${AUR_RPC_URL}/search/${encoded_query}" 2>/dev/null || true)
  local count
  count=$(jq -r '.resultcount // 0' <<< "$response" 2>/dev/null || echo 0)

  if [[ "$count" -eq 0 ]]; then
    warn "No AUR packages found matching '$query'."
    return 0
  fi

  local fzf_input
  fzf_input=$(jq -r '
    .results | sort_by(-.Popularity)[] |
    "\(.Name)\t\(.Version)\t\(.NumVotes)\t\(.Popularity)\t\(.Description // "No description")"
  ' <<< "$response")

  local selected_line
  selected_line=$(echo "$fzf_input" | fzf \
    --delimiter=$'\t' \
    --with-nth=1,2,5 \
    --preview="echo -e 'Package: {1}\nVersion: {2}\nVotes: {3} | Pop: {4}\n\nDescription:\n{5}'" \
    --preview-window=right:50%:wrap \
    --prompt="AUR Select > " \
    --header="ENTER: Select | ESC: Exit") || true

  if [[ -n "$selected_line" ]]; then
    local selected_pkg
    selected_pkg=$(awk -F$'\t' '{print $1}' <<< "$selected_line")
    install_aur_package "$selected_pkg" "false"
  else
    log "No selection made."
  fi
}

update_aur_packages() {
  header "AUR Package Update Check"
  log "Scanning foreign (AUR) packages on the system..."

  local foreign_pkgs
  foreign_pkgs=$(pacman -Qm 2>/dev/null || true)

  if [[ -z "$foreign_pkgs" ]]; then
    success "No AUR packages installed on this system."
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

  log "Querying ${total_foreign} packages via AUR RPC..."
  local multi_json
  multi_json=$(curl -sSf "${AUR_RPC_URL}/info?${args#&}" 2>/dev/null || echo '{"results":[]}')

  local updates=()
  local up_to_date=0

  while IFS=$'\t' read -r pkg aur_ver; do
    [[ -z "$pkg" || -z "$aur_ver" ]] && continue
    local local_ver="${local_versions["$pkg"]:-}"
    if [[ -n "$local_ver" ]]; then
      local cmp
      cmp=$(vercmp "$local_ver" "$aur_ver" 2>/dev/null || echo 0)
      if [[ "$cmp" -lt 0 ]]; then
        updates+=("${pkg}|${local_ver}|${aur_ver}")
      else
        ((up_to_date++))
      fi
    fi
  done < <(jq -r '.results[] | "\(.Name)\t\(.Version)"' <<< "$multi_json")

  if [[ ${#updates[@]} -eq 0 ]]; then
    success "All AUR packages are up to date! (${up_to_date} packages checked)"
    return 0
  fi

  header "AUR Packages with Available Updates (${#updates[@]})"
  for item in "${updates[@]}"; do
    local p l a
    IFS='|' read -r p l a <<< "$item"
    echo -e "  ${BOLD}${GREEN}${p}${RESET}: ${RED}${l}${RESET} -> ${GREEN}${a}${RESET}"
  done
  echo -e "${BOLD}${BLUE}----------------------------------------------------------------------${RESET}"

  if confirm "Update these packages?" "Y"; then
    for item in "${updates[@]}"; do
      local p l a
      IFS='|' read -r p l a <<< "$item"
      log "Updating: $p ($l -> $a)"
      install_aur_package "$p" "true" || warn "$p failed to update, continuing..."
    done
    success "AUR update process completed."
  else
    log "Update skipped by user."
  fi
}

clean_cache() {
  header "Build Cache Cleanup"
  if [[ -d "$CACHE_DIR" ]]; then
    local size
    size=$(du -sh "$CACHE_DIR" 2>/dev/null | awk '{print $1}')
    log "Cache Directory: $CACHE_DIR (${size})"
    if confirm "Delete the entire build cache?" "Y"; then
      rm -rf "$CACHE_DIR"
      success "Cache cleaned successfully."
    else
      log "Cleanup cancelled."
    fi
  else
    success "No cache to clean ($CACHE_DIR does not exist)."
  fi
}

show_help() {
  banner
  echo -e "${BOLD}USAGE:${RESET}"
  echo -e "  $0 [options] [package_name|search_term]\n"
  echo -e "${BOLD}DESCRIPTION:${RESET}"
  echo -e "  When run without arguments, prompts for a package name directly."
  echo -e "  No index numbers required; type the package name directly to install.\n"
  echo -e "${BOLD}OPTIONS:${RESET}"
  echo -e "  ${GREEN}<package_name>${RESET}            Search by name, install directly if exact match found"
  echo -e "  ${GREEN}-s, --search <term>${RESET}      Search AUR and select by typing the package name"
  echo -e "  ${GREEN}-i, --install <package>${RESET}   Download and install the specified package with confirmation"
  echo -e "  ${GREEN}-u, --update${RESET}              Check and update all installed AUR packages"
  echo -e "  ${GREEN}-c, --clean${RESET}               Clean the package build cache (${CACHE_DIR})"
  echo -e "  ${GREEN}-f, --fzf [term]${RESET}          Interactive fuzzy search using fzf"
  echo -e "  ${GREEN}-h, --help${RESET}                Show this help message\n"
  echo -e "${BOLD}EXAMPLES:${RESET}"
  echo -e "  $0                       (Interactive package name prompt)"
  echo -e "  $0 spotify               (Find and install spotify directly)"
  echo -e "  $0 -u                    (Update all AUR packages)\n"
}

main() {
  check_root
  check_dependencies

  if [[ $# -eq 0 ]]; then
    banner
    while true; do
      local search_term=""
      read_prompt "$(echo -e "\n${BOLD}${BLUE}?${RESET} Enter the package name to search or install ${BOLD}[q: Quit]${RESET}: ")" search_term

      search_term=$(echo "$search_term" | xargs)
      [[ -z "$search_term" ]] && continue
      [[ "$search_term" =~ ^[qQ]$ ]] && { log "Goodbye."; exit 0; }

      find_and_install_package "$search_term"
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
        error "Please enter a search term. E.g.: $0 -s spotify"
        exit 1
      fi
      find_and_install_package "$*"
      ;;
    -i|--install)
      shift
      if [[ $# -eq 0 ]]; then
        error "Please enter a package name. E.g.: $0 -i google-chrome"
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
