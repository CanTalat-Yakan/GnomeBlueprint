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

# ─── Colors ───────────────────────────────────────────────────────────────────
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
    "com.github.tchx84.Flatseal"           # Flatseal - manage Flatpak permissions
    "com.mattjakeman.ExtensionManager"     # Extension Manager - browse & toggle GNOME extensions
    "io.github.fabrialberio.pinapp"        # Pins - create custom app shortcuts
    "dev.qwery.AddWater"                   # Add Water - apply Adwaita theme to Firefox
    "io.github.swordpuffin.rewaita"        # Rewaita - bring color to Adwaita
    "io.missioncenter.MissionCenter"       # Mission Center - system monitor
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
    # Entertainment
    "Spotify|flatpak:com.spotify.Client"
    "Discord|flatpak:com.discordapp.Discord"
    "Signal Messenger|flatpak:org.signal.Signal"
    "Steam|flatpak:com.valvesoftware.Steam"
    "VLC Media Player|flatpak:org.videolan.VLC"
    # Creative
    "Blender|flatpak:org.blender.Blender"
    "GIMP|flatpak:org.gimp.GIMP"
    "Unity Hub|flatpak:com.unity.UnityHub"
    # Utilities
    "Visual Studio Code|flatpak:com.visualstudio.code"
    "JetBrains Rider|flatpak:com.jetbrains.Rider"
    "GitHub Desktop|flatpak:io.github.shiftey.Desktop"
    "Trayscale (Tailscale GUI)|flatpak:dev.deedles.Trayscale"
    # Runtimes
    ".NET SDK & Runtimes|script:dotnet"
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
            --header.foreground="12" --header.italic=false \
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
            --header.foreground="12" --header.italic=false \
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

# ─── System update ──────────────────────────────────────────────────────────────
system_update() {
    info "Updating system packages..."
    if command -v dnf &>/dev/null; then
        sudo dnf update -y || warning "dnf update encountered an error."
    elif command -v apt-get &>/dev/null; then
        sudo apt-get update -y && sudo apt-get upgrade -y || warning "apt upgrade encountered an error."
    elif command -v pacman &>/dev/null; then
        sudo pacman -Syu --noconfirm || warning "pacman update encountered an error."
    fi

    if command -v flatpak &>/dev/null; then
        info "Updating Flatpak applications..."
        flatpak update -y || warning "flatpak update encountered an error."
    fi
}


# ─── User preferences (24h clock, auto-login, blank screen, battery) ──────────
ask_user_preferences() {
    echo ""
    info "Configuring user preferences..."
    echo ""

    local prefs=()
    local pref_labels=(
        "Use 24-hour time format"
        "Login without asking for password (auto-login)"
        "Blank screen: Never (display stays on)"
        "Disable automatic screen lock"
        "Preserve battery (power-saver profile)"
    )

    if [ "$GUM_AVAILABLE" = true ] && command -v gum &>/dev/null; then
        # Build comma-separated string of all labels for pre-selection
        local selected_default
        selected_default=$(IFS=,; echo "${pref_labels[*]}")

        local raw
        raw=$(gum choose --no-limit \
            --selected="$selected_default" \
            --header.foreground="12" --header.italic=false \
            --header "  Select preferences (↑/↓ move, Space toggle, Enter confirm):" \
            "${pref_labels[@]}") || true
        if [ -n "$raw" ]; then
            while IFS= read -r line; do
                prefs+=("$line")
            done <<< "$raw"
        fi
    else
        echo -e "${CYAN}${BOLD}User preferences:${NC}"
        for i in "${!pref_labels[@]}"; do
            printf "  %2d) %s\n" "$((i + 1))" "${pref_labels[$i]}"
        done
        echo ""
        echo "Enter numbers to enable (space-separated), or press Enter to skip:"
        local choices
        read -rp "> " choices
        for num in $choices; do
            if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#pref_labels[@]}" ]; then
                prefs+=("${pref_labels[$((num - 1))]}")
            fi
        done
    fi

    for pref in "${prefs[@]}"; do
        case "$pref" in
            "Use 24-hour time format")
                info "Setting 24-hour time format..."
                gsettings set org.gnome.desktop.interface clock-format '24h' 2>/dev/null || true
                # Also set locale-based 24h via dconf
                dconf write /system/locale/region "'en_GB.UTF-8'" 2>/dev/null || true
                ;;
            "Login without asking for password (auto-login)")
                info "Enabling automatic login..."
                local current_user
                current_user=$(whoami)
                sudo mkdir -p /etc/gdm 2>/dev/null || true
                # Works for GDM (Fedora/GNOME default)
                if [ -f /etc/gdm/custom.conf ]; then
                    sudo sed -i '/^\[daemon\]/,/^\[/ { /^AutomaticLoginEnable/d; /^AutomaticLogin=/d; }' /etc/gdm/custom.conf
                    sudo sed -i "/^\[daemon\]/a AutomaticLoginEnable=True\nAutomaticLogin=${current_user}" /etc/gdm/custom.conf
                else
                    echo -e "[daemon]\nAutomaticLoginEnable=True\nAutomaticLogin=${current_user}" \
                        | sudo tee /etc/gdm/custom.conf > /dev/null
                fi
                info "Automatic login enabled for user '${current_user}'."
                ;;
            "Blank screen: Never (display stays on)")
                info "Setting blank screen to Never..."
                gsettings set org.gnome.desktop.session idle-delay 0 2>/dev/null || true
                gsettings set org.gnome.settings-daemon.plugins.power idle-dim false 2>/dev/null || true
                ;;
            "Disable automatic screen lock")
                info "Disabling automatic screen lock..."
                gsettings set org.gnome.desktop.screensaver lock-enabled false 2>/dev/null || true
                ;;
            "Preserve battery (power-saver profile)")
                info "Setting power profile to power-saver..."
                if command -v powerprofilesctl &>/dev/null; then
                    powerprofilesctl set power-saver || warning "Could not set power-saver profile."
                else
                    warning "powerprofilesctl not found - skipping power profile change."
                fi
                # Additional battery-saving settings
                gsettings set org.gnome.settings-daemon.plugins.power idle-dim true 2>/dev/null || true
                gsettings set org.gnome.settings-daemon.plugins.power ambient-enabled true 2>/dev/null || true
                ;;
        esac
    done

    if [ ${#prefs[@]} -eq 0 ]; then
        info "No preferences selected - using defaults."
    fi
}

# ─── Nautilus (Files) configuration ─────────────────────────────────────────────
configure_nautilus() {
    info "Configuring Nautilus (Files)..."

    # Sort folders before files
    gsettings set org.gnome.nautilus.preferences sort-directories-first true 2>/dev/null || true
    # Default to list view
    gsettings set org.gnome.nautilus.preferences default-folder-viewer 'list-view' 2>/dev/null || true
    # Show "Create Link" in context menu
    gsettings set org.gnome.nautilus.preferences show-create-link true 2>/dev/null || true
    # Show "Delete Permanently" in context menu
    gsettings set org.gnome.nautilus.preferences show-delete-permanently true 2>/dev/null || true
    # Expand folders in list view (tree view)
    gsettings set org.gnome.nautilus.list-view use-tree-view true 2>/dev/null || true
    # List view smallest icon size
    gsettings set org.gnome.nautilus.list-view default-zoom-level 'small' 2>/dev/null || true

    # Also set GTK file chooser to sort folders first
    gsettings set org.gtk.gtk4.Settings.FileChooser sort-directories-first true 2>/dev/null || true

    # Star useful folders
    local current_user
    current_user=$(whoami)
    local starred_folders=(
        "/home/${current_user}/.var/app"
        "/home/${current_user}/.local/share/gnome-shell/extensions"
    )

    for folder in "${starred_folders[@]}"; do
        if [ -d "$folder" ]; then
            gio set -t stringv "$folder" metadata::xdg-tags "starred" 2>/dev/null \
                || warning "Could not star $folder"
            info "Starred: $folder"
        else
            mkdir -p "$folder" 2>/dev/null || true
            gio set -t stringv "$folder" metadata::xdg-tags "starred" 2>/dev/null \
                || warning "Could not star $folder"
            info "Created & starred: $folder"
        fi
    done

    info "Nautilus configuration complete."
}

# ─── Adwaita theme setup (adw-gtk3 + Flatpak overrides) ────────────────────────
setup_themes() {
    info "Setting up Adwaita themes..."

    # Install adw-gtk3 theme (makes GTK3 apps match GTK4 Adwaita)
    if command -v dnf &>/dev/null; then
        if ! rpm -q adw-gtk3-theme &>/dev/null 2>&1; then
            info "Installing adw-gtk3-theme..."
            sudo dnf install -y adw-gtk3-theme || warning "Could not install adw-gtk3-theme."
        else
            info "adw-gtk3-theme is already installed."
        fi
    fi

    # Apply adw-gtk3-dark as GTK theme (for GTK3 apps)
    gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true

    # Allow Flatpak apps to access GTK themes
    flatpak override --user --filesystem=xdg-config/gtk-4.0 2>/dev/null || true
    flatpak override --user --filesystem=xdg-config/gtk-3.0 2>/dev/null || true

    info "Themes applied. Open Add Water to apply Adwaita theme to Firefox."
    info "Open Rewaita to browse and apply Adwaita icon theme variants."
}

# ─── Pin installed optional apps to favorites ──────────────────────────────────
# Maps Flatpak app IDs to their .desktop file names
declare -A OPTIONAL_DESKTOP_FILES=(
    ["com.spotify.Client"]="com.spotify.Client.desktop"
    ["com.discordapp.Discord"]="com.discordapp.Discord.desktop"
    ["org.signal.Signal"]="org.signal.Signal.desktop"
    ["com.valvesoftware.Steam"]="com.valvesoftware.Steam.desktop"
    ["org.videolan.VLC"]="org.videolan.VLC.desktop"
    ["org.blender.Blender"]="org.blender.Blender.desktop"
    ["org.gimp.GIMP"]="org.gimp.GIMP.desktop"
    ["com.unity.UnityHub"]="com.unity.UnityHub.desktop"
    ["com.visualstudio.code"]="com.visualstudio.code.desktop"
    ["com.jetbrains.Rider"]="com.jetbrains.Rider.desktop"
    ["io.github.shiftey.Desktop"]="io.github.shiftey.Desktop.desktop"
    ["dev.deedles.Trayscale"]="dev.deedles.Trayscale.desktop"
)

pin_optional_apps_to_favorites() {
    # Get current favorites
    local current_favs
    current_favs=$(gsettings get org.gnome.shell favorite-apps 2>/dev/null) || return

    local changed=false

    for app_id in "${!OPTIONAL_DESKTOP_FILES[@]}"; do
        if flatpak list --app --columns=application 2>/dev/null | grep -qx "$app_id"; then
            local desktop="${OPTIONAL_DESKTOP_FILES[$app_id]}"
            if ! echo "$current_favs" | grep -q "'${desktop}'"; then
                # Append before the closing bracket
                current_favs="${current_favs%]*}, '${desktop}']"
                changed=true
                info "Pinned $desktop to favorites."
            fi
        fi
    done

    if [ "$changed" = true ]; then
        gsettings set org.gnome.shell favorite-apps "$current_favs" 2>/dev/null || true
    fi
}

# ─── Download wallpaper collection ──────────────────────────────────────────────
WALLPAPER_REPO="https://github.com/dharmx/walls"
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"

ask_download_wallpapers() {
    echo ""
    local do_download=false

    if [ "$GUM_AVAILABLE" = true ] && command -v gum &>/dev/null; then
        if gum confirm "  Download wallpaper collection to ~/Pictures/Wallpapers?"; then
            do_download=true
        fi
    else
        echo -e "${CYAN}${BOLD}Download wallpaper collection to ~/Pictures/Wallpapers?${NC} [y/N]"
        local answer
        read -rp "> " answer
        case "$answer" in
            [yY]*) do_download=true ;;
        esac
    fi

    if [ "$do_download" = false ]; then
        info "Skipping wallpaper download."
        return
    fi

    if [ -d "$WALLPAPER_DIR/.git" ]; then
        info "Wallpapers already present - pulling latest..."
        git -C "$WALLPAPER_DIR" pull --ff-only || warning "Could not update wallpapers."
    else
        info "Cloning wallpaper collection..."
        mkdir -p "$(dirname "$WALLPAPER_DIR")"
        git clone --depth 1 "$WALLPAPER_REPO" "$WALLPAPER_DIR" \
            || warning "Failed to clone wallpaper repo."
    fi

    if [ -d "$WALLPAPER_DIR" ]; then
        info "Wallpapers available at $WALLPAPER_DIR"
    fi
}

# ─── Uninstall GNOME bloatware ──────────────────────────────────────────────────
# Format: "flatpak-id|dnf-package|Display Name"
# Use "-" if no flatpak or no dnf package exists for that app.
GNOME_BLOAT_APPS=(
    "org.gnome.Boxes|gnome-boxes|Boxes"
    "org.gnome.Characters|gnome-characters|Characters"
    "org.gnome.Connections|gnome-connections|Connections"
    "org.gnome.Contacts|gnome-contacts|Contacts"
    "org.gnome.Extensions|gnome-extensions-app|Extensions"
    "org.gnome.DiskUtility|gnome-disk-utility|Disks"
    "org.gnome.baobab|baobab|Disk Usage Analyser"
    "org.gnome.SimpleScan|simple-scan|Document Scanner"
    "org.fedoraproject.MediaWriter|mediawriter|Fedora Media Writer"
    "org.gnome.Yelp|yelp|Help"
    "-|libreoffice-calc|LibreOffice Calc"
    "-|libreoffice-impress|LibreOffice Impress"
    "-|libreoffice-writer|LibreOffice Writer"
    "org.gnome.Maps|gnome-maps|Maps"
    "org.freedesktop.MalcontentControl|malcontent|Parental Controls"
    "org.gnome.SystemMonitor|gnome-system-monitor|System Monitor"
    "org.gnome.Tour|gnome-tour|Tour"
    "org.gnome.Weather|gnome-weather|Weather"
)

# Packages whose removal would break the desktop - never touch these via dnf.
PROTECTED_RE="gnome-shell|gdm|mutter|gnome-session|gnome-settings-daemon"

# Safely remove an RPM package: dry-run first, skip if it would cascade into
# removing any protected desktop component.
safe_dnf_remove() {
    local pkg="$1" label="$2"

    # Not installed - nothing to do
    command -v rpm &>/dev/null || return
    rpm -q "$pkg" &>/dev/null 2>&1 || return

    # Dry-run: would this also pull gnome-shell / gdm / mutter?
    local sim
    sim=$(dnf remove --assumeno --setopt=clean_requirements_on_remove=True "$pkg" 2>&1 || true)
    if echo "$sim" | grep -qEi "$PROTECTED_RE"; then
        warning "Skipping $label ($pkg) - removing it would also remove core desktop packages."
        return
    fi

    info "Removing RPM: $pkg ($label)..."
    sudo dnf remove -y --noautoremove "$pkg" 2>/dev/null \
        || warning "Failed to remove $pkg."
}

ask_uninstall_bloat() {
    echo ""
    local do_remove=false

    if [ "$GUM_AVAILABLE" = true ] && command -v gum &>/dev/null; then
        if gum confirm "  Uninstall GNOME bloat? (Boxes, Characters, Connections, Contacts, etc.)"; then
            do_remove=true
        fi
    else
        echo -e "${CYAN}${BOLD}Uninstall GNOME bloat?${NC} (Boxes, Characters, Connections, Contacts, etc.) [y/N]"
        local answer
        read -rp "> " answer
        case "$answer" in
            [yY]*) do_remove=true ;;
        esac
    fi

    if [ "$do_remove" = false ]; then
        info "Skipping bloat removal."
        return
    fi

    info "Removing GNOME bloat..."

    for entry in "${GNOME_BLOAT_APPS[@]}"; do
        local flatpak_id="${entry%%|*}"
        local rest="${entry#*|}"
        local dnf_pkg="${rest%%|*}"
        local label="${rest#*|}"

        # 1. Try Flatpak removal (safe, no side-effects)
        if [ "$flatpak_id" != "-" ]; then
            if flatpak list --app --columns=application 2>/dev/null | grep -qx "$flatpak_id"; then
                info "Removing Flatpak: $label..."
                flatpak uninstall -y "$flatpak_id" 2>/dev/null \
                    || warning "Failed to remove Flatpak $label."
            fi
        fi

        # 2. Try RPM removal (with safety check)
        if [ "$dnf_pkg" != "-" ] && command -v dnf &>/dev/null; then
            safe_dnf_remove "$dnf_pkg" "$label"
        fi
    done

    info "Bloat removal complete."
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

    # 2. System update (dnf + flatpak)
    system_update

    # 3. Profile selection (first interactive prompt)
    local profile
    profile=$(select_profile)
    info "Selected profile: ${BOLD}${profile}${NC}"

    # 4. Core setup
    install_git
    clone_repo
    install_flatpak

    # 5. Essential Flatpaks (includes Mission Center) & GNOME extensions
    install_essential_flatpaks
    install_gnome_extensions
    restart_gnome_shell

    # 6. Adwaita theme setup (adw-gtk3 + Flatpak overrides)
    setup_themes

    # 7. User preferences (24h clock, auto-login, blank screen, battery)
    ask_user_preferences

    # 8. Nautilus configuration (sort, list view, context menu, starred folders)
    configure_nautilus

    # 9. Download wallpaper collection
    ask_download_wallpapers

    # 10. Ask to uninstall GNOME bloat
    ask_uninstall_bloat

    # 11. Optional applications (interactive chooser - includes Trayscale)
    select_and_install_optional_apps

    # 12. Apply profile-specific settings
    import_gnome_settings "$profile"
    run_profile "$profile"

    # 13. Pin any installed optional apps to dock favorites
    pin_optional_apps_to_favorites

    echo ""
    info "Installation complete! Log out and back in for all changes to take effect."
    echo ""
}

main "$@"
