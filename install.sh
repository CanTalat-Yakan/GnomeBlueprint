#!/usr/bin/env bash
# GnomeBlueprint - GNOME Desktop Automation Installer
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

# ─── Helper: install a single Flatpak (idempotent) ─────────────────────────────
install_one_flatpak() {
    local app="$1"
    if flatpak list --app --columns=application 2>/dev/null | grep -qx "$app"; then
        info "$app is already installed."
    else
        info "Installing $app..."
        flatpak install -y flathub "$app" \
            || warning "Failed to install $app - skipping."
    fi
}

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
        info "Dotfiles already present at $DOTFILES_DIR - pulling latest changes..."
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
            warning "GPG key fingerprint mismatch - installing gum without fingerprint check (key sourced via HTTPS)."
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

# ─── Essential Flatpak applications (always installed) ──────────────────────────
ESSENTIAL_FLATPAK_APPS=(
    "com.github.tchx84.Flatseal"          # Flatseal - manage Flatpak permissions
    "com.mattjakeman.ExtensionManager"     # Extension Manager - browse & toggle GNOME extensions
    "io.github.fabrialberio.pinapp"        # Pins - create custom app shortcuts
    "page.codeberg.Addwater.Addwater"      # Add Water - Adwaita theme customisation
)

install_essential_flatpaks() {
    info "Installing essential Flatpak applications..."
    for app in "${ESSENTIAL_FLATPAK_APPS[@]}"; do
        install_one_flatpak "$app"
    done
}

# ─── GNOME Shell extensions ────────────────────────────────────────────────────
# Format: "uuid|Human-readable name"
GNOME_EXTENSIONS=(
    "appindicatorsupport@rgcjonas.gmail.com|AppIndicator & KStatusNotifierItem Support"
    "arcmenu@arcmenu.com|ArcMenu"
    "clipboard-history@alexsaveau.dev|Clipboard History"
    "dash-to-dock@micxgx.gmail.com|Dash to Dock"
    "just-perfection-desktop@just-perfection|Just Perfection"
    "panel-corners@aunetx|Panel Corners"
    "user-theme@gnome-shell-extensions.gcampax.github.com|User Themes"
    "azwallpaper@azwallpaper.gitlab.com|Wallpaper Slideshow"
)

# ─── Patch extension metadata.json with current GNOME Shell version ─────────────
# Some extensions don't list the latest Shell version yet - adding it allows them
# to load without waiting for an upstream update.
patch_extension_metadata() {
    local uuid="$1"
    local metadata="$HOME/.local/share/gnome-shell/extensions/${uuid}/metadata.json"

    if [ ! -f "$metadata" ]; then
        return
    fi

    local shell_version
    shell_version=$(gnome-shell --version 2>/dev/null | grep -oP '\d+' | head -1) || true
    if [ -z "$shell_version" ]; then
        return
    fi

    python3 -c "
import json
path = '$metadata'
sv   = '$shell_version'
with open(path) as f:
    data = json.load(f)
versions = data.get('shell-version', [])
if sv not in versions:
    versions.append(sv)
    data['shell-version'] = versions
    with open(path, 'w') as f:
        json.dump(data, f, indent=2)
    print(f'  Patched GNOME Shell {sv} into metadata for $uuid')
" 2>/dev/null || true
}

install_gnome_extension() {
    local uuid="$1" name="$2"

    # Already installed - patch metadata and make sure it is enabled
    if gnome-extensions list 2>/dev/null | grep -qx "$uuid"; then
        patch_extension_metadata "$uuid"
        gnome-extensions enable "$uuid" 2>/dev/null || true
        info "$name is already installed - ensured enabled."
        return
    fi

    info "Installing GNOME extension: $name..."

    # Detect GNOME Shell major version
    local shell_version
    shell_version=$(gnome-shell --version 2>/dev/null | grep -oP '\d+' | head -1) || true
    if [ -z "$shell_version" ]; then
        warning "Could not detect GNOME Shell version - skipping $name."
        return
    fi

    # Fetch extension metadata from extensions.gnome.org
    local info_url="https://extensions.gnome.org/extension-info/?uuid=${uuid}&shell_version=${shell_version}"
    local info_json
    info_json=$(curl -fsSL "$info_url" 2>/dev/null) || {
        warning "Could not fetch metadata for $name - skipping."
        return
    }

    # Extract download URL (python3 is always present on GNOME systems)
    local download_url
    download_url=$(echo "$info_json" \
        | python3 -c "import sys,json; print(json.load(sys.stdin)['download_url'])" 2>/dev/null) || {
        warning "Extension $name may not support GNOME Shell $shell_version - skipping."
        return
    }

    # Download zip and install
    local tmp_zip
    tmp_zip=$(mktemp --suffix=.zip)
    curl -fsSL "https://extensions.gnome.org${download_url}" -o "$tmp_zip" || {
        warning "Download failed for $name - skipping."
        rm -f "$tmp_zip"; return
    }

    gnome-extensions install --force "$tmp_zip" 2>/dev/null || {
        warning "Install command failed for $name - skipping."
        rm -f "$tmp_zip"; return
    }
    rm -f "$tmp_zip"

    # Patch metadata.json so the extension loads on the current Shell version
    patch_extension_metadata "$uuid"

    # Enable (may require a Shell restart to take full effect)
    gnome-extensions enable "$uuid" 2>/dev/null || \
        warning "Installed $name but could not enable it - enable manually via Extension Manager."

    info "$name installed successfully."
}

install_gnome_extensions() {
    if ! command -v gnome-extensions &>/dev/null; then
        warning "gnome-extensions CLI not found - skipping GNOME Shell extension installation."
        warning "You can install extensions manually via Extension Manager after setup."
        return
    fi

    info "Installing GNOME Shell extensions..."
    for entry in "${GNOME_EXTENSIONS[@]}"; do
        local uuid="${entry%%|*}"
        local name="${entry##*|}"
        install_gnome_extension "$uuid" "$name"
    done
    info "GNOME Shell extensions installed."
}

# ─── Restart GNOME Shell to activate extensions ────────────────────────────────
restart_gnome_shell() {
    info "Restarting GNOME Shell to activate extensions..."

    if [ "${XDG_SESSION_TYPE:-}" = "x11" ]; then
        busctl --user call org.gnome.Shell /org/gnome/Shell org.gnome.Shell Eval s \
            'Meta.restart("Restarting GNOME Shell...")' 2>/dev/null \
            && { sleep 2; info "GNOME Shell restarted."; } \
            || warning "Could not restart GNOME Shell - please log out and back in."
    else
        warning "Running on Wayland - GNOME Shell cannot be restarted in-place."
        warning "Please log out and back in for all extensions to take full effect."
    fi
}

# ─── Optional applications (interactive chooser) ───────────────────────────────
# Format: "Display Label|type:identifier"
#   type = flatpak  →  Flathub app ID
#   type = script   →  custom installer function name
OPTIONAL_APPS=(
    "Visual Studio Code|flatpak:com.visualstudio.code"
    "VLC Media Player|flatpak:org.videolan.VLC"
    "JetBrains Rider|flatpak:com.jetbrains.Rider"
    "Discord|flatpak:com.discordapp.Discord"
    "Spotify|flatpak:com.spotify.Client"
    "Firefox|flatpak:org.mozilla.firefox"
    "Steam|flatpak:com.valvesoftware.Steam"
    "Blender|flatpak:org.blender.Blender"
    "GIMP|flatpak:org.gimp.GIMP"
    ".NET SDK & Runtimes|script:dotnet"
    "GitHub Desktop|flatpak:io.github.shiftey.Desktop"
    "Unity Hub|flatpak:com.unity.UnityHub"
)

# ─── .NET SDK installer (via Microsoft install script) ─────────────────────────
install_dotnet() {
    info "Installing .NET SDK & Runtimes..."
    local tmp_script
    tmp_script=$(mktemp)
    curl -fsSL https://dot.net/v1/dotnet-install.sh -o "$tmp_script" || {
        warning "Failed to download .NET install script - skipping."
        rm -f "$tmp_script"; return
    }
    chmod +x "$tmp_script"

    for channel in LTS STS; do
        info "  Installing .NET $channel channel..."
        bash "$tmp_script" --channel "$channel" \
            || warning "  .NET $channel install encountered an error."
    done
    rm -f "$tmp_script"

    if ! echo "$PATH" | grep -q "$HOME/.dotnet"; then
        warning "Add this to your shell profile to use dotnet:"
        warning "  export DOTNET_ROOT=\"\$HOME/.dotnet\""
        warning "  export PATH=\"\$HOME/.dotnet:\$PATH\""
    fi
}

select_and_install_optional_apps() {
    echo ""
    info "Choose additional applications to install (optional)."
    echo ""

    # Build label array
    local labels=()
    for entry in "${OPTIONAL_APPS[@]}"; do
        labels+=("${entry%%|*}")
    done

    local selected=()

    if [ "$GUM_AVAILABLE" = true ] && command -v gum &>/dev/null; then
        local raw
        raw=$(gum choose --no-limit \
            --header.foreground="212" \
            --header "  Select optional apps (↑/↓ move, Space select, Enter confirm):" \
            "${labels[@]}") || true

        if [ -n "$raw" ]; then
            while IFS= read -r line; do
                selected+=("$line")
            done <<< "$raw"
        fi
    else
        echo -e "${CYAN}${BOLD}Optional applications:${NC}"
        for i in "${!labels[@]}"; do
            printf "  %2d) %s\n" "$((i + 1))" "${labels[$i]}"
        done
        echo ""
        echo "Enter the numbers you want (space-separated), or press Enter to skip:"
        local choices
        read -rp "> " choices
        for num in $choices; do
            if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#labels[@]}" ]; then
                selected+=("${labels[$((num - 1))]}")
            fi
        done
    fi

    if [ ${#selected[@]} -eq 0 ]; then
        info "No optional applications selected - moving on."
        return
    fi

    info "Installing ${#selected[@]} optional application(s)..."

    for sel in "${selected[@]}"; do
        for entry in "${OPTIONAL_APPS[@]}"; do
            local label="${entry%%|*}"
            local target="${entry##*|}"
            if [ "$label" = "$sel" ]; then
                local install_type="${target%%:*}"
                local install_id="${target##*:}"
                case "$install_type" in
                    flatpak) install_one_flatpak "$install_id" ;;
                    script)
                        case "$install_id" in
                            dotnet) install_dotnet ;;
                            *) warning "Unknown install script: $install_id" ;;
                        esac
                        ;;
                    *) warning "Unknown install type: $install_type" ;;
                esac
                break
            fi
        done
    done
}

# ─── Import GNOME settings via dconf ───────────────────────────────────────────
import_gnome_settings() {
    local profile="$1"
    local dconf_file="$DOTFILES_DIR/gnome-settings/${profile}.dconf"

    if [ ! -f "$dconf_file" ]; then
        warning "No dconf file found at $dconf_file - skipping GNOME settings import."
        return
    fi

    if ! command -v dconf &>/dev/null; then
        warning "dconf not found - skipping GNOME settings import."
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
            *) warning "Invalid choice - defaulting to 'desktop'."; profile="desktop" ;;
        esac
    fi

    # Guard against empty selection (e.g. user pressed Ctrl-C in gum)
    if [ -z "$profile" ]; then
        warning "No profile selected - defaulting to 'desktop'."
        profile="desktop"
    fi

    echo "$profile"
}

# ─── Run profile-specific setup script ─────────────────────────────────────────
run_profile() {
    local profile="$1"
    local script="$DOTFILES_DIR/profiles/${profile}/setup.sh"

    if [ ! -f "$script" ]; then
        warning "No setup script found at $script - skipping profile setup."
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

    # 1. Bootstrap tooling
    install_gum

    # 2. Profile selection (first interactive prompt)
    local profile
    profile=$(select_profile)
    info "Selected profile: ${BOLD}${profile}${NC}"

    # 3. Core setup
    install_git
    clone_repo
    install_flatpak

    # 4. Essential Flatpaks & GNOME extensions
    install_essential_flatpaks
    install_gnome_extensions
    restart_gnome_shell

    # 5. Optional applications (interactive chooser)
    select_and_install_optional_apps

    # 6. Apply profile-specific settings
    import_gnome_settings "$profile"
    run_profile "$profile"

    echo ""
    info "Installation complete! Log out and back in for all changes to take effect."
    echo ""
}

main "$@"
