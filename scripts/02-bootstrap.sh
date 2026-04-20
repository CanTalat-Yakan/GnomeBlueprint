#!/usr/bin/env bash
# 02Gnome - Bootstrap: git, gum, flatpak, system update, repo clone
# Sourced by install.sh — do not run directly.

# ─── Install git ───────────────────────────────────────────────────────────────
install_git() {
    if command -v git &>/dev/null; then
        info "git is already installed."
        return
    fi

    info "Installing git..."
    if [ "$IS_ATOMIC" = true ]; then
        pkg_install git
    elif command -v apt-get &>/dev/null; then
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
        info "Dotfiles already present at $DOTFILES_DIR."
        info "Pulling latest changes..."
        git -C "$DOTFILES_DIR" pull --ff-only
    else
        info "Cloning 02Gnome to $DOTFILES_DIR..."
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
        local CHARM_KEY_FINGERPRINT="F3B551E9AB7AD7FE"
        local tmp_key
        tmp_key=$(mktemp)
        curl -fsSL https://repo.charm.sh/apt/gpg.key -o "$tmp_key"
        if ! gpg --no-default-keyring --keyring "gnupg-ring:${tmp_key}" \
                --fingerprint 2>/dev/null | grep -qi "$CHARM_KEY_FINGERPRINT"; then
            warning "GPG key fingerprint mismatch - installing gum without fingerprint check (key sourced via HTTPS)."
        fi
        sudo mkdir -p /etc/apt/keyrings
        gpg --dearmor "$tmp_key" | sudo tee /etc/apt/keyrings/charm.gpg > /dev/null
        rm -f "$tmp_key"
        echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" \
            | sudo tee /etc/apt/sources.list.d/charm.list > /dev/null
        sudo apt-get update -y && sudo apt-get install -y gum

    elif [ "$IS_ATOMIC" = true ]; then
        local gum_ver="0.14.5"
        local gum_url="https://github.com/charmbracelet/gum/releases/download/v${gum_ver}/gum_${gum_ver}_Linux_x86_64.tar.gz"
        local tmp_gum
        tmp_gum=$(mktemp -d)
        curl -fsSL "$gum_url" -o "$tmp_gum/gum.tar.gz" && {
            tar -xzf "$tmp_gum/gum.tar.gz" -C "$tmp_gum"
            mkdir -p "$HOME/.local/bin"
            cp -f "$tmp_gum/gum" "$HOME/.local/bin/gum" 2>/dev/null \
                || cp -f "$tmp_gum/gum_${gum_ver}_Linux_x86_64/gum" "$HOME/.local/bin/gum" 2>/dev/null
            chmod +x "$HOME/.local/bin/gum"
            export PATH="$HOME/.local/bin:$PATH"
            info "gum installed to ~/.local/bin"
        } || {
            warning "Could not download gum binary. Falling back to plain-text selection."
            GUM_AVAILABLE=false
        }
        rm -rf "$tmp_gum"
        return

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
            warning "Falling back to plain-text selection."
            GUM_AVAILABLE=false
            return
        fi

    else
        warning "Could not install gum automatically. Falling back to plain-text selection."
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

# ─── System update ──────────────────────────────────────────────────────────────
system_update() {
    info "Updating system packages..."
    if [ "$IS_ATOMIC" = true ]; then
        info "Upgrading base image via rpm-ostree..."
        rpm-ostree upgrade || warning "rpm-ostree upgrade encountered an error."
    elif command -v dnf &>/dev/null; then
        sudo dnf update -y || warning "dnf update encountered an error."
    elif command -v apt-get &>/dev/null; then
        sudo apt-get update -y && sudo apt-get upgrade -y || warning "apt upgrade encountered an error."
    elif command -v pacman &>/dev/null; then
        sudo pacman -Syu --noconfirm || warning "pacman update encountered an error."
    fi

    if command -v flatpak &>/dev/null; then
        info "Updating Flatpak applications..."
        flatpak update -y --noninteractive || warning "flatpak update encountered an error."
    fi
}

# ─── Install fastfetch ─────────────────────────────────────────────────────────
install_fastfetch() {
    if command -v fastfetch &>/dev/null; then
        info "fastfetch is already installed."
        return
    fi

    info "Installing fastfetch..."
    if [ "$IS_ATOMIC" = true ]; then
        pkg_install fastfetch
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y fastfetch || warning "Could not install fastfetch."
    elif command -v apt-get &>/dev/null; then
        sudo apt-get install -y fastfetch || warning "Could not install fastfetch."
    elif command -v pacman &>/dev/null; then
        sudo pacman -Sy --noconfirm fastfetch || warning "Could not install fastfetch."
    else
        warning "Unsupported package manager - skipping fastfetch install."
    fi
}

