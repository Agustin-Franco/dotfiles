#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$SCRIPT_DIR"
BACKUP_DIR="${HOME}/.dotfiles.bak"

DRY_RUN=false
CONFIRM=true
DO_BACKUP=true
ONLY_PACKAGES=()

print_usage() {
  cat <<'EOF'
Uso: bootstrap.sh [opciones]

Opciones:
  --dry-run              Muestra acciones sin ejecutar
  --yes                  No pedir confirmacion
  --no-backup            No crea backups en ~/.dotfiles.bak
  --packages "p1 p2"     Solo procesa esos paquetes
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --yes) CONFIRM=false; shift ;;
    --no-backup) DO_BACKUP=false; shift ;;
    --packages) shift; IFS=' ' read -r -a ONLY_PACKAGES <<< "${1:-}"; shift ;;
    -h|--help) print_usage; exit 0 ;;
    *) echo "Opcion invalida: $1"; print_usage; exit 1 ;;
  esac
done

log() { echo "[*] $*"; }
warn() { echo "[!] $*" >&2; }
die() { echo "[x] $*" >&2; exit 1; }

command -v stow >/dev/null 2>&1 || die "stow no esta instalado. Instala stow y reintenta."

mkdir -p "$DOTFILES_DIR"
$DO_BACKUP && mkdir -p "$BACKUP_DIR"

confirm() {
  $CONFIRM || return 0
  read -r -p "$1 [y/N] " ans
  [[ "$ans" == "y" || "$ans" == "Y" ]]
}

in_only_packages() {
  local pkg="$1"
  [[ ${#ONLY_PACKAGES[@]} -eq 0 ]] && return 0
  for p in "${ONLY_PACKAGES[@]}"; do
    [[ "$p" == "$pkg" ]] && return 0
  done
  return 1
}

is_managed_symlink() {
  local src="$1"
  if [[ -L "$HOME/$src" ]]; then
    local target
    target="$(readlink "$HOME/$src")" || return 1
    [[ "$target" == "$DOTFILES_DIR"/* ]]
    return $?
  fi
  return 1
}

backup_item() {
  local src="$1"
  local bak="$BACKUP_DIR/$src"
  mkdir -p "$(dirname "$bak")"
  log "Backup $HOME/$src -> $bak"
  $DRY_RUN && return 0
  cp -a "$HOME/$src" "$bak"
}

move_item() {
  local src="$1"
  local pkg="$2"
  local dest="$DOTFILES_DIR/$pkg/$src"

  [[ -e "$HOME/$src" ]] || return 0

  if is_managed_symlink "$src"; then
    log "Ya gestionado: $src"
    return 0
  fi

  if [[ -e "$dest" ]]; then
    warn "Destino ya existe: $dest"
    return 0
  fi

  log "Mover $HOME/$src -> $dest"
  $DRY_RUN && return 0

  mkdir -p "$(dirname "$dest")"
  $DO_BACKUP && backup_item "$src"
  mv "$HOME/$src" "$dest"
}

declare -A PACKAGE_MAP=()
PACKAGE_MAP[bash]=".bashrc .bash_profile .bash_logout .bash_aliases .inputrc"
PACKAGE_MAP[zsh]=".zshrc .zprofile .zshenv .zlogin .zlogout"
PACKAGE_MAP[git]=".gitconfig .gitignore .gitmessage .config/git"
PACKAGE_MAP[tmux]=".tmux.conf"
PACKAGE_MAP[nvim]=".config/nvim"
PACKAGE_MAP[vim]=".vimrc .vim"
PACKAGE_MAP[hypr]=".config/hypr"
PACKAGE_MAP[waybar]=".config/waybar"
PACKAGE_MAP[wofi]=".config/wofi"
PACKAGE_MAP[alacritty]=".config/alacritty"
PACKAGE_MAP[btop]=".config/btop"
PACKAGE_MAP[gtk]=".config/gtk-3.0 .config/gtk-4.0"
PACKAGE_MAP[fontconfig]=".config/fontconfig"
PACKAGE_MAP[starship]=".config/starship.toml"
PACKAGE_MAP[opencode]=".config/opencode"
PACKAGE_MAP[ssh]=".ssh/config"
PACKAGE_MAP[zsh_plugins]=".config/zsh"
PACKAGE_MAP[vscodium]=".config/VSCodium"
PACKAGE_MAP[mpv]=".config/mpv"
PACKAGE_MAP[vlc]=".config/vlc"
PACKAGE_MAP[thunar]=".config/Thunar"
PACKAGE_MAP[pavucontrol]=".config/pavucontrol.ini"
PACKAGE_MAP[xsettingsd]=".config/xsettingsd"
PACKAGE_MAP[nwglook]=".config/nwg-look"
PACKAGE_MAP[kvantum]=".config/Kvantum"
PACKAGE_MAP[xdg]=".config/mimeapps.list .config/user-dirs.dirs .config/user-dirs.locale"

log "Preparando dotfiles en $DOTFILES_DIR"
for pkg in "${!PACKAGE_MAP[@]}"; do
  in_only_packages "$pkg" || continue

  items="${PACKAGE_MAP[$pkg]}"
  log "Paquete: $pkg -> $items"

  for item in $items; do
    if [[ -e "$HOME/$item" ]]; then
      if confirm "Mover $HOME/$item al paquete '$pkg'?"; then
        move_item "$item" "$pkg"
      else
        log "Saltado $item"
      fi
    fi
  done
done

log "Aplicando stow por paquetes"
for pkg in "${!PACKAGE_MAP[@]}"; do
  in_only_packages "$pkg" || continue
  if [[ -d "$DOTFILES_DIR/$pkg" ]]; then
    log "stow $pkg"
    if $DRY_RUN; then
      stow -n -d "$DOTFILES_DIR" -t "$HOME" "$pkg"
    else
      stow -d "$DOTFILES_DIR" -t "$HOME" "$pkg"
    fi
  fi
done

log "Listo. Backup en $BACKUP_DIR"
