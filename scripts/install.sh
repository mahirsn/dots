#!/usr/bin/env bash
# ============================================================
# dots/install.sh  -  restore your working environment on a
#                     FRESH Arch Linux install
# ------------------------------------------------------------
# - Does NOT require root; uses sudo only where needed.
# - NEVER overwrites existing files blindly: everything is
#   backed up to ~/.config/dots-backup-<timestamp> first.
# - Does NOT install CachyOS specific packages.
# - Read-only on your old system; this runs on the new one.
# ============================================================
set -uo pipefail

DOTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="$HOME/.config/dots-backup-$(date +%Y%m%d-%H%M%S)"
PKGS_DIR="$DOTS_DIR/packages"
CONFIGS_DIR="$DOTS_DIR/configs"
HOME_FILES_DIR="$DOTS_DIR/home"

BOLD="\033[1m"; DIM="\033[2m"; RED="\033[31m"; YEL="\033[33m"; GRN="\033[32m"; RST="\033[0m"
info() { printf "${BOLD}[dots]${RST} %s\n" "$*"; }
warn() { printf "${YEL}[dots!]${RST} %s\n" "$*"; }
err()  { printf "${RED}[dots!]${RST} %s\n" "$*"; }
ok()   { printf "${GRN}[dots ✓]${RST} %s\n" "$*"; }

is_installed() { command -v "$1" >/dev/null 2>&1; }

# ------------------------------------------------------------
# 0. Sanity checks
# ------------------------------------------------------------
if [[ "$(whoami)" == "root" ]]; then
    err "Do NOT run as root. Run as your normal user (sudo is used per-command)."
    exit 1
fi

if [[ ! -f /etc/os-release ]] || ! grep -qi '^ID=arch' /etc/os-release; then
    warn "This does not look like clean Arch. /etc/os-release: $(grep '^ID=' /etc/os-release 2>/dev/null || echo '?')"
fi

if [[ $# -gt 0 ]]; then
    case "$1" in
        --packages)    MODE=packages ;;
        --configs)     MODE=configs ;;
        --home)        MODE=home ;;
        --all|"")      MODE=all ;;
        --dry-run|--check) MODE=dry ;;
        *) err "Unknown option: $1 (use --packages | --configs | --home | --all | --dry-run)"; exit 1 ;;
    esac
else
    MODE=all
fi

# ------------------------------------------------------------
# 1. AUR helper (only used with --packages / --all)
# ------------------------------------------------------------
pick_aur_helper() {
    if is_installed paru; then echo paru
    elif is_installed yay; then echo yay
    else return 1; fi
}

# ------------------------------------------------------------
# 2. Packages
# ------------------------------------------------------------
install_packages() {
    info "Checking pacman list..."
    [[ -s "$PKGS_DIR/arch-repo.txt" ]] || { err "packages/arch-repo.txt missing"; return 1; }

    local pkglist_text pkglist
    pkglist_text="$(grep -vE '^\s*(#|$)' "$PKGS_DIR/arch-repo.txt")"

    info "Installing $(( $(echo "$pkglist_text" | wc -l) )) pacman packages with sudo..."
    sudo pacman -S --needed --noconfirm $pkglist_text || {
        warn "pacman step failed (some packages may be renamed/removed). Review the error above.";
    }

    # --- AUR ---
    local aur_helper
    if aur_helper="$(pick_aur_helper)"; then
        info "Using AUR helper: $aur_helper"
        if [[ -s "$PKGS_DIR/aur.txt" ]]; then
            grep -vE '^\s*(#|$)' "$PKGS_DIR/aur.txt" | "$aur_helper" -S --needed --noconfirm - || \
                warn "AUR step partially failed; review errors above."
        fi
    else
        warn "No AUR helper found (paru/yay). Install one first, then re-run:"
        cat <<'EOF'
    # Fedora-style Arch AUR helpers can be built manually:
    #   sudo pacman -S --needed base-devel git
    #   git clone https://aur.archlinux.org/paru.git /tmp/paru
    #   cd /tmp/paru && makepkg -si
    # Then: paru -S --needed - < "$PKGS_DIR/aur.txt"
EOF
        return 1
    fi

    info "Flatpak: not used on this device (flatpak.txt is documentation only)."
}

# ------------------------------------------------------------
# 3. Restore a directory/tree into ~/.config, backing up first
# ------------------------------------------------------------
backup_existing() {
    local dest="$1"
    if [[ -e "$dest" ]]; then
        local rel="${dest#$HOME/}"
        mkdir -p "$BACKUP_DIR"
        mv "$dest" "$BACKUP_DIR/$rel" && warn "backed up existing $rel -> $BACKUP_DIR/$rel"
    fi
}

restore_config() {
    local src="$1" name
    name="$(basename "$src")"
    local dest="$HOME/.config/$name"

    if [[ ! -d "$src" ]]; then
        warn "skipping $name (missing in repo)"
        return
    fi

    if [[ -e "$dest" ]]; then
        printf "${DIM}[dots]${RST}  %s exists -> what to do? [o]verwrite-with-backup / [s]kip (default) : " "$name"
        read -r ans
        case "${ans,,}" in
            o|y) backup_existing "$dest" ;;
            *) ok "skipped $name" ; return ;;
        esac
    fi

    cp -r --preserve=mode "$src" "$dest"
    ok "restored ~/.config/$name ($(du -sh "$src" | cut -f1))"
}

restore_home() {
    local f
    for path in "$HOME_FILES_DIR"/*; do
        [[ -e "$path" ]] || continue
        f="$(basename "$path")"
        local dest="$HOME/.$f"   # home/zshrc -> ~/.zshrc
        if [[ -e "$dest" ]]; then
            printf "${DIM}[dots]${RST}  ~/.%s exists -> [o]verwrite-with-backup / [s]kip (default) : " "$f"
            read -r ans
            case "${ans,,}" in o|y) backup_existing "$dest" ;; *) ok "skipped ~/.$f" ; continue ;; esac
        fi
        cp --preserve=mode "$path" "$dest"
        ok "restored ~/.$f"
    done
}

# ------------------------------------------------------------
# 4. Configs
# ------------------------------------------------------------
install_configs() {
    info "Restoring dotfiles/configs into ~/.config (existing dirs are backed up)..."
    local d
    for d in "$CONFIGS_DIR"/*/; do
        restore_config "${d%/}"
    done
    restore_home

    # optional system unit / asus config reminder (copied under system/)
    cat <<'EOF'

${DIM}--- next steps (system-level, needs sudo) ---${RST}
  * Review system/ dir in this repo. Nothing from there is auto-applied.
  * See system/enabled-services.txt and system/running-services.txt for service reference.
  * ASUS: copy system/asusd/*.ron to /etc/asusd/ and system/supergfxd.conf to /etc/ if this is an ASUS TUF A16.
  * amd-pstate-reset.service lives in system/systemd/ - reinstall manually if still needed.
EOF
}

# ------------------------------------------------------------
# 5. Manual steps summary
# ------------------------------------------------------------
print_manual_steps() {
    cat <<'EOF'

================= MANUAL STEPS (must still be done) =================
  1. Bootloader/snapper (limine-snapper-sync) & kernels are CachyOS-choices;
     on Arch use: sudo pacman -S linux linux-headers linux-lts linux-lts-headers
     (or linux-zen) and your preferred bootloader (systemd-boot/GRUB/Limine).
  2. mkinitcpio for NVIDIA: add to /etc/mkinitcpio.conf.d/50-nvidia.conf:
        MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
     then: sudo mkinitcpio -P   (see system/mkinitcpio/conf.d/10-chwd.conf)
  3. /etc/modprobe.d/nvidia.conf:  options nvidia-drm modeset=1
  4. Enable user services / re-check systemd services from system/enabled-services.txt
  5. The hypr shell (quickshell 'ii' + noctalia + matugen) is provided by AUR:
     illogical-impulse-* packages. Custom overrides live in ~/.config/hypr/custom/
     and were restored above. If icons missing, reinstall illogical-impulse-fonts-themes.
  6. dotfiles refer to machine-specific paths/logos (e.g. ~/Downloads/angle.jpg
     in .zshrc, fastfetch images). Adjust after restore.
=====================================================================
EOF
}

# ------------------------------------------------------------
# 6. Run
# ------------------------------------------------------------
case "$MODE" in
    packages) install_packages ;;
    configs)  install_configs ;;
    home)     restore_home ;;
    all)      install_packages; echo; install_configs; print_manual_steps ;;
    dry)
        info "DRY-RUN: packages to install:"
        grep -vE '^\s*(#|$)' "$PKGS_DIR/arch-repo.txt" 2>/dev/null | nl
        info "AUR:"
        grep -vE '^\s*(#|$)' "$PKGS_DIR/aur.txt" 2>/dev/null | nl
        info "README next steps:"
        print_manual_steps
        ;;
esac

ok "Done."
echo "${DIM}Backed-up originals (if any) are in: $BACKUP_DIR${RST}"