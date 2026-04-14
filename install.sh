#!/usr/bin/env bash
# GnomeBlueprint — GNOME Desktop Automation Installer
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Usage (one-liner):
#   bash <(curl -fsSL https://raw.githubusercontent.com/CanTalat-Yakan/GnomeBlueprint/main/install.sh)

set -euo pipefail

REPO_URL="https://github.com/CanTalat-Yakan/GnomeBlueprint"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
GUM_AVAILABLE=true

# ─── Colours ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warning() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ─── Install git ───────────────────────────────────────────────────────────────
install_git() {
    if command -v git &>/dev/null; then
        info "git is already installed."
        return
    fi

    info "Installing git..."
    if command -v apt-get &>/dev/null; then
        sudo apt-get update -y && sudo apt-get install -y git
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y git
    elif command -v pacman &>/dev/null; then
        sudo pacman -Sy --noconfirm git
    else
        error "Unsupported package manager. Please install git manually and re-run this script."
        exit 1
    fi
}

# ─── Clone / update repository ─────────────────────────────────────────────────
clone_repo() {
    if [ -d "$DOTFILES_DIR/.git" ]; then
        info "Dotfiles already present at $DOTFILES_DIR — pulling latest changes..."
        git -C "$DOTFILES_DIR" pull --ff-only
    else
        info "Cloning GnomeBlueprint to $DOTFILES_DIR..."
        git clone "$REPO_URL" "$DOTFILES_DIR"
    fi
}

# ─── Install gum (Charmbracelet TUI toolkit) ───────────────────────────────────
install_gum() {
    if command -v gum &>/dev/null; then
        info "gum is already installed."
        return
    fi

    info "Installing gum (Charmbracelet)..."

    if command -v apt-get &>/dev/null; then
        # Expected Charm GPG key fingerprint (verify at https://charm.sh/gpg-key)
        local CHARM_KEY_FINGERPRINT="F3B551E9AB7AD7FE"
        local tmp_key
        tmp_key=$(mktemp)
        curl -fsSL https://repo.charm.sh/apt/gpg.key -o "$tmp_key"
        # Verify the key fingerprint before trusting it
        if ! gpg --no-default-keyring --keyring "gnupg-ring:${tmp_key}" \
                --fingerprint 2>/dev/null | grep -qi "$CHARM_KEY_FINGERPRINT"; then
            warning "GPG key fingerprint mismatch — installing gum without fingerprint check (key sourced via HTTPS)."
        fi
        sudo mkdir -p /etc/apt/keyrings
        gpg --dearmor "$tmp_key" | sudo tee /etc/apt/keyrings/charm.gpg > /dev/null
        rm -f "$tmp_key"
        echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" \
            | sudo tee /etc/apt/sources.list.d/charm.list > /dev/null
        sudo apt-get update -y && sudo apt-get install -y gum

    elif command -v dnf &>/dev/null; then
        echo '[charm]
name=Charm
baseurl=https://repo.charm.sh/yum/
enabled=1
gpgcheck=1
gpgkey=https://repo.charm.sh/yum/gpg.key' | sudo tee /etc/yum.repos.d/charm.repo > /dev/null
        sudo dnf install -y gum

    elif command -v pacman &>/dev/null; then
        if command -v yay &>/dev/null; then
            yay -S --noconfirm gum
        elif command -v paru &>/dev/null; then
            paru -S --noconfirm gum
        else
            warning "gum is not in the official Arch repos. Install an AUR helper (yay/paru) to get gum."
            warning "Falling back to plain-text profile selection."
            GUM_AVAILABLE=false
            return
        fi

    else
        warning "Could not install gum automatically. Falling back to plain-text profile selection."
        GUM_AVAILABLE=false
        return
    fi
}

# ─── Ensure Flatpak + Flathub are available ────────────────────────────────────
install_flatpak() {
    if ! command -v flatpak &>/dev/null; then
        info "Installing flatpak..."
        if command -v apt-get &>/dev/null; then
            sudo apt-get install -y flatpak
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y flatpak
        elif command -v pacman &>/dev/null; then
            sudo pacman -Sy --noconfirm flatpak
        else
            error "Unsupported package manager. Please install flatpak manually."
            exit 1
        fi
    else
        info "flatpak is already installed."
    fi

    info "Adding Flathub remote (if not already present)..."
    flatpak remote-add --if-not-exists flathub \
        https://dl.flathub.org/repo/flathub.flatpakrepo || true
}

# ─── Common Flatpak applications ───────────────────────────────────────────────
FLATPAK_APPS=(
    "com.visualstudio.code"      # Visual Studio Code
    "com.discordapp.Discord"     # Discord
    "org.mozilla.firefox"        # Firefox
    "org.gnome.Extensions"       # GNOME Extensions manager
    "com.spotify.Client"         # Spotify
    "org.videolan.VLC"           # VLC media player
)

install_flatpak_apps() {
    info "Installing common Flatpak applications..."
    for app in "${FLATPAK_APPS[@]}"; do
        if flatpak list --app --columns=application 2>/dev/null | grep -qx "$app"; then
            info "$app is already installed."
        else
            info "Installing $app..."
            flatpak install -y flathub "$app" \
                || warning "Failed to install $app — skipping."
        fi
    done
}

# ─── Import GNOME settings via dconf ───────────────────────────────────────────
import_gnome_settings() {
    local profile="$1"
    local dconf_file="$DOTFILES_DIR/gnome-settings/${profile}.dconf"

    if [ ! -f "$dconf_file" ]; then
        warning "No dconf file found at $dconf_file — skipping GNOME settings import."
        return
    fi

    if ! command -v dconf &>/dev/null; then
        warning "dconf not found — skipping GNOME settings import."
        return
    fi

    info "Importing GNOME settings for profile '${profile}'..."
    dconf load / < "$dconf_file"
    info "GNOME settings imported successfully."
}

# ─── Profile selection (gum TUI or plain-text fallback) ────────────────────────
select_profile() {
    local profile

    if [ "$GUM_AVAILABLE" = true ] && command -v gum &>/dev/null; then
        profile=$(gum choose \
            --header.foreground="212" \
            --header "  Select a GnomeBlueprint profile:" \
            "Desktop" \
            "Laptop" \
            | tr '[:upper:]' '[:lower:]')
    else
        echo ""
        echo -e "${CYAN}${BOLD}Select a profile:${NC}"
        echo "  1) Desktop"
        echo "  2) Laptop"
        local choice
        read -rp "Enter choice [1-2]: " choice
        case "$choice" in
            1) profile="desktop" ;;
            2) profile="laptop"  ;;
            *) warning "Invalid choice — defaulting to 'desktop'."; profile="desktop" ;;
        esac
    fi

    # Guard against empty selection (e.g. user pressed Ctrl-C in gum)
    if [ -z "$profile" ]; then
        warning "No profile selected — defaulting to 'desktop'."
        profile="desktop"
    fi

    echo "$profile"
}

# ─── Run profile-specific setup script ─────────────────────────────────────────
run_profile() {
    local profile="$1"
    local script="$DOTFILES_DIR/profiles/${profile}/setup.sh"

    if [ ! -f "$script" ]; then
        warning "No setup script found at $script — skipping profile setup."
        return
    fi

    info "Running ${profile} profile setup..."
    chmod +x "$script"
    bash "$script"
}

# ─── Main ──────────────────────────────────────────────────────────────────────
main() {
    echo ""
    echo -e "${CYAN}${BOLD}"
    echo "  ╔═══════════════════════════════════════╗"
    echo "  ║       GnomeBlueprint Installer        ║"
    echo "  ╚═══════════════════════════════════════╝"
    echo -e "${NC}"

    install_git
    clone_repo
    install_gum
    install_flatpak
    install_flatpak_apps

    local profile
    profile=$(select_profile)
    info "Selected profile: ${BOLD}${profile}${NC}"

    import_gnome_settings "$profile"
    run_profile "$profile"

    echo ""
    info "Installation complete! Log out and back in for all changes to take effect."
    echo ""
}

main "$@"
