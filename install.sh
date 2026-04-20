#!/usr/bin/env bash
# 02Gnome (ZeroToGnome) - GNOME Desktop Automation Installer
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Usage (one-liner):
#   curl -fsSL https://raw.githubusercontent.com/CanTalat-Yakan/02Gnome/main/install.sh | bash

set -euo pipefail

REPO_URL="https://github.com/CanTalat-Yakan/02Gnome"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
GUM_AVAILABLE=true
USE_OLED=false
INSTALLED_DOCKER_SERVICES=()
IS_ATOMIC=false

# ─── Source all module scripts from the cloned repo ────────────────────────────
_source_modules() {
    local script_dir="$DOTFILES_DIR/scripts"
    if [ ! -d "$script_dir" ]; then
        error "Scripts directory not found at $script_dir"
        exit 1
    fi

    source "$script_dir/01-common.sh"
    source "$script_dir/02-bootstrap.sh"
    source "$script_dir/03-docker.sh"
    source "$script_dir/04-extensions.sh"
    source "$script_dir/05-apps.sh"
    source "$script_dir/06-gnome.sh"
    source "$script_dir/07-themes.sh"
    source "$script_dir/08-cleanup.sh"
}

# ─── Minimal bootstrap (needed before modules are available) ───────────────────
_CYAN='\033[0;36m'
_BOLD='\033[1m'
_NC='\033[0m'
_YELLOW='\033[1;33m'
_RED='\033[0;31m'

info()    { echo -e "${_CYAN}[INFO]${_NC}  $*"; }
warning() { echo -e "${_YELLOW}[WARN]${_NC}  $*"; }
error()   { echo -e "${_RED}[ERROR]${_NC} $*" >&2; }

_early_detect_atomic() {
    if [ -f /run/ostree-booted ] || command -v rpm-ostree &>/dev/null; then
        IS_ATOMIC=true
        info "Detected atomic/immutable Fedora (rpm-ostree). Adapting installation accordingly."
    fi
}

_early_install_git() {
    if command -v git &>/dev/null; then return; fi
    info "Installing git..."
    if [ "$IS_ATOMIC" = true ]; then
        rpm-ostree install --idempotent --allow-inactive -y git 2>/dev/null || true
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y git
    elif command -v apt-get &>/dev/null; then
        sudo apt-get update -y && sudo apt-get install -y git
    elif command -v pacman &>/dev/null; then
        sudo pacman -Sy --noconfirm git
    else
        error "Cannot install git. Please install it manually and re-run."
        exit 1
    fi
}

_early_clone_repo() {
    if [ -d "$DOTFILES_DIR/.git" ]; then
        git -C "$DOTFILES_DIR" pull --ff-only -q
    else
        git clone -q "$REPO_URL" "$DOTFILES_DIR"
    fi
}

# ─── Main ──────────────────────────────────────────────────────────────────────
main() {
    echo ""
    echo -e "${_CYAN}${_BOLD}"
    cat << 'BANNER'
 ██████╗ ██████╗      ██████╗ ███╗   ██╗ ██████╗ ███╗   ███╗███████╗
██╔═████╗╚════██╗    ██╔════╝ ████╗  ██║██╔═══██╗████╗ ████║██╔════╝
██║██╔██║ █████╔╝    ██║  ███╗██╔██╗ ██║██║   ██║██╔████╔██║█████╗  
████╔╝██║██╔═══╝     ██║   ██║██║╚██╗██║██║   ██║██║╚██╔╝██║██╔══╝  
╚██████╔╝███████╗    ╚██████╔╝██║ ╚████║╚██████╔╝██║ ╚═╝ ██║███████╗
 ╚═════╝ ╚══════╝     ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝
BANNER
    echo -e "${_NC}"

    # 0. Detect atomic/immutable Fedora
    _early_detect_atomic

    # 1. Bootstrap: git + clone (before modules can be sourced)
    _early_install_git
    _early_clone_repo

    # 2. Source user configuration, then all modules
    source "$DOTFILES_DIR/config.sh"
    _source_modules

    # 3. Bootstrap tooling (gum TUI)
    install_gum

    # 4. Show info & ask user before starting
    echo ""
    info "Repository cloned to ${BOLD}${DOTFILES_DIR}${NC}"
    echo ""
    info "Customise your installation by editing:"
    info "  ${BOLD}${DOTFILES_DIR}/config.sh${NC}"
    info "  ${BOLD}${DOTFILES_DIR}/gnome/<profile>/${NC}"
    echo ""
    info "  config.sh arrays you can edit:"
    info "    ESSENTIAL_FLATPAK_APPS, OPTIONAL_APPS,"
    info "    GNOME_EXTENSIONS, GNOME_EXTENSIONS_DISABLED," 
    info "    GNOME_BLOAT_APPS, OPTIONAL_PIN_ORDER, DOCKER_SERVICES"
    echo ""

    local do_continue=true
    if [ "$GUM_AVAILABLE" = true ] && command -v gum &>/dev/null; then
        if ! gum confirm --default=yes "  Start installation?"; then
            do_continue=false
        fi
    else
        echo -e "${_CYAN}${_BOLD}Start installation?${_NC} [Y/n]"
        local answer
        read -rp "> " answer
        case "$answer" in
            [nN]*) do_continue=false ;;
        esac
    fi

    if [ "$do_continue" = false ]; then
        info "Installation cancelled. Edit config.sh, then re-run this script."
        exit 0
    fi

    # 5. Profile selection
    local profile
    profile=$(select_profile)
    info "Selected profile: ${BOLD}${profile}${NC}"

    # 6. System update (dnf + flatpak)
    system_update

    # 7. Core setup
    install_flatpak
    install_docker
    install_tailscale
    install_fastfetch

    # 7. Apply profile-specific dconf settings (base layer)
    import_gnome_settings "$profile"
    run_profile "$profile"

    # 8. Essential Flatpaks & GNOME extensions
    install_essential_flatpaks
    install_gnome_extensions
    restart_gnome_shell

    # Re-apply dconf settings after extensions are installed
    sleep 3
    import_gnome_settings "$profile"

    # 9. Adwaita theme setup
    setup_themes

    # 10. Install Rewaita custom themes
    install_rewaita_themes

    # 11. Ask Oled preference
    ask_oled_preference

    # 12. Configure Add Water & Firefox
    configure_addwater
    configure_firefox

    # 13. User preferences
    ask_user_preferences

    # 14. Nautilus configuration
    configure_nautilus

    # 15. Templates
    setup_templates

    # 16. App defaults
    configure_app_defaults

    # 17. Download wallpaper collection
    ask_download_wallpapers

    # 18. Ask to uninstall GNOME bloat
    ask_uninstall_bloat

    # 19. Optional applications
    select_and_install_optional_apps

    # 20. Docker Compose services
    select_and_install_docker_services

    # 21. Create web app shortcuts
    create_docker_web_apps

    # 22. Pin optional apps to dock favorites
    pin_optional_apps_to_favorites

    # 23. Register OpenCode shortcut
    register_opencode_shortcut

    # 24. Reset app grid
    reset_app_grid

    # 25. Detect & install NVIDIA drivers
    install_nvidia_drivers

    # 26. Final system cleanup & update
    final_cleanup

    # 27. Ask to reboot
    echo ""
    info "Installation complete!"
    ask_reboot
}


main "$@"
