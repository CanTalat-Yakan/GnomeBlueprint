#!/usr/bin/env bash
# GnomeBlueprint - GNOME Desktop Automation Installer
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Usage (one-liner):
#   curl -fsSL https://raw.githubusercontent.com/CanTalat-Yakan/GnomeBlueprint/main/install.sh | bash

set -euo pipefail

REPO_URL="https://github.com/CanTalat-Yakan/GnomeBlueprint"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
GUM_AVAILABLE=true
USE_OLED=false
INSTALLED_DOCKER_SERVICES=()
IS_ATOMIC=false

# ─── Detect immutable / atomic Fedora (Silverblue, Bazzite, Kinoite, etc.) ────
detect_atomic() {
    if [ -f /run/ostree-booted ] || command -v rpm-ostree &>/dev/null; then
        IS_ATOMIC=true
        info "Detected atomic/immutable Fedora (rpm-ostree). Adapting installation accordingly."
    fi
}

# ─── Helpers: install / remove system packages (atomic-aware) ─────────────────
# On atomic systems, rpm-ostree layering is used instead of dnf.
# rpm-ostree install is idempotent (already-layered packages are skipped).
pkg_install() {
    local pkg="$1"
    if [ "$IS_ATOMIC" = true ]; then
        info "Layering $pkg via rpm-ostree..."
        rpm-ostree install --idempotent --allow-inactive -y "$pkg" 2>/dev/null \
            || warning "Could not layer $pkg via rpm-ostree."
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y "$pkg" 2>/dev/null \
            || warning "Could not install $pkg via dnf."
    elif command -v apt-get &>/dev/null; then
        sudo apt-get install -y "$pkg" 2>/dev/null \
            || warning "Could not install $pkg via apt."
    elif command -v pacman &>/dev/null; then
        sudo pacman -Sy --noconfirm "$pkg" 2>/dev/null \
            || warning "Could not install $pkg via pacman."
    else
        warning "No supported package manager found to install $pkg."
    fi
}

pkg_remove() {
    local pkg="$1" label="${2:-$1}"
    if [ "$IS_ATOMIC" = true ]; then
        # Check if the package is layered (user-installed)
        if rpm-ostree status 2>/dev/null | grep -q "LayeredPackages:.*$pkg"; then
            info "Removing layered package: $pkg ($label)..."
            rpm-ostree uninstall -y "$pkg" 2>/dev/null \
                || warning "Could not remove $pkg via rpm-ostree."
        elif rpm -q "$pkg" &>/dev/null 2>&1; then
            # Package is in the base image — use override remove
            info "Overriding base package: $pkg ($label)..."
            rpm-ostree override remove "$pkg" 2>/dev/null \
                || warning "Could not override-remove $pkg (may be required by base image)."
        fi
    elif command -v dnf &>/dev/null; then
        safe_dnf_remove "$pkg" "$label"
    elif command -v pacman &>/dev/null; then
        safe_pacman_remove "$pkg" "$label"
    fi
}

# ─── Colors ───────────────────────────────────────────────────────────────────
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
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

    elif [ "$IS_ATOMIC" = true ]; then
        # On atomic Fedora, avoid layering packages when possible.
        # Try to install gum via a pre-built binary instead.
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

# ─── Install Docker ────────────────────────────────────────────────────────────
install_docker() {
    if command -v docker &>/dev/null; then
        info "Docker is already installed."
        return
    fi

    info "Installing Docker..."

    if [ "$IS_ATOMIC" = true ]; then
        # On atomic Fedora, prefer installing Docker via rpm-ostree layering
        # Remove conflicting packages first
        rpm-ostree uninstall -y podman-docker 2>/dev/null || true

        # Add Docker CE repo
        local docker_repo="https://download.docker.com/linux/fedora/docker-ce.repo"
        sudo curl -fsSL "$docker_repo" -o /etc/yum.repos.d/docker-ce.repo 2>/dev/null || {
            warning "Could not add Docker repo - skipping."
            return
        }

        # Fix $releasever for atomic variants
        local fedora_ver
        fedora_ver=$(rpm -E %fedora 2>/dev/null) || true
        if [ -n "$fedora_ver" ] && [ -f /etc/yum.repos.d/docker-ce.repo ]; then
            sudo sed -i "s|\$releasever|${fedora_ver}|g" /etc/yum.repos.d/docker-ce.repo 2>/dev/null || true
        fi

        rpm-ostree install --idempotent --allow-inactive -y \
            docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
            || { warning "Docker layering failed - skipping."; return; }

        # Enable Docker service (will start after reboot when layers are applied)
        sudo systemctl enable docker 2>/dev/null || true
        sudo usermod -aG docker "$(whoami)" 2>/dev/null || true
        info "Docker layered via rpm-ostree. A reboot is required to activate."
        return

    elif command -v dnf &>/dev/null; then
        # Remove old/conflicting packages
        sudo dnf remove -y docker docker-client docker-client-latest \
            docker-common docker-latest docker-latest-logrotate \
            docker-logrotate docker-engine podman-docker 2>/dev/null || true

        # Add Docker CE repo - use Fedora base for Fedora derivatives
        local docker_repo="https://download.docker.com/linux/fedora/docker-ce.repo"
        sudo dnf config-manager addrepo --from-repofile="$docker_repo" \
            2>/dev/null || sudo dnf config-manager --add-repo "$docker_repo" \
            2>/dev/null || { warning "Could not add Docker repo - skipping."; return; }

        # Fix $releasever for non-Fedora derivatives
        # Docker only publishes repos for actual Fedora versions
        if [ -f /etc/yum.repos.d/docker-ce.repo ]; then
            local fedora_ver
            fedora_ver=$(rpm -E %fedora 2>/dev/null) || true
            if [ -n "$fedora_ver" ]; then
                sudo sed -i "s|\$releasever|${fedora_ver}|g" /etc/yum.repos.d/docker-ce.repo 2>/dev/null || true
            fi
        fi

        sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
            || { warning "Docker install failed - skipping."; return; }

    elif command -v apt-get &>/dev/null; then
        curl -fsSL https://get.docker.com | bash \
            || { warning "Docker install failed - skipping."; return; }

    elif command -v pacman &>/dev/null; then
        sudo pacman -Sy --noconfirm docker docker-compose \
            || { warning "Docker install failed - skipping."; return; }
    else
        warning "Unsupported package manager - skipping Docker install."
        return
    fi

    # Enable and start Docker service
    sudo systemctl enable --now docker 2>/dev/null || true

    # Add current user to docker group (avoids needing sudo for docker commands)
    sudo usermod -aG docker "$(whoami)" 2>/dev/null || true

    info "Docker installed. Log out and back in for group membership to take effect."
}

# ─── Install Tailscale ──────────────────────────────────────────────────────────

install_tailscale() {
    if command -v tailscale &>/dev/null; then
        info "Tailscale is already installed."
        return
    fi

    info "Installing Tailscale..."

    curl -fsSL https://tailscale.com/install.sh | bash \
        || { warning "Tailscale install failed - skipping."; return; }

    sudo systemctl enable --now tailscaled 2>/dev/null || true
    sudo tailscale up

    info "Tailscale installed and started."
}

# ─── Docker Compose services (interactive chooser) ─────────────────────────────

DOCKER_SERVICES=(
    "Immich|immich"
    "Ollama + Open WebUI|ollama"
    "ZeroTier One|zerotierone"
)

select_and_install_docker_services() {
    echo ""
    info "Choose Docker Compose services to deploy (optional)."
    echo ""

    local labels=()
    for entry in "${DOCKER_SERVICES[@]}"; do
        labels+=("${entry%%|*}")
    done

    local selected=()

    if [ "$GUM_AVAILABLE" = true ] && command -v gum &>/dev/null; then
        local raw
        raw=$(gum choose --no-limit --height=${#labels[@]} \
            --header.foreground="12" --header.italic=false \
            --header "  Select Docker services (↑/↓ move, Space select, Enter confirm):" \
            "${labels[@]}") || true

        if [ -n "$raw" ]; then
            while IFS= read -r line; do
                selected+=("$line")
            done <<< "$raw"
        fi
    else
        echo -e "${CYAN}${BOLD}Docker Compose services:${NC}"
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
        info "No Docker services selected - moving on."
        return
    fi

    info "Deploying ${#selected[@]} Docker service(s)..."

    for sel in "${selected[@]}"; do
        for entry in "${DOCKER_SERVICES[@]}"; do
            local label="${entry%%|*}"
            local dir_name="${entry##*|}"
            if [ "$sel" = "$label" ]; then
                local target_dir="$HOME/$dir_name"
                info "Setting up ${label} in ${target_dir}..."

                mkdir -p "$target_dir"
                cp "$DOTFILES_DIR/docker/$dir_name/docker-compose.yml" "$target_dir/"
                cp "$DOTFILES_DIR/docker/$dir_name/README.md" "$target_dir/" 2>/dev/null || true

                # Copy env file if present (stored without dot prefix to avoid .gitignore)
                if [ -f "$DOTFILES_DIR/docker/$dir_name/env" ]; then
                    # Only copy if user doesn't already have one (preserve existing config)
                    if [ ! -f "$target_dir/.env" ]; then
                        cp "$DOTFILES_DIR/docker/$dir_name/env" "$target_dir/.env"
                        # Generate a random DB password to replace the placeholder
                        if grep -q 'please-change-me' "$target_dir/.env" 2>/dev/null; then
                            local random_pw
                            random_pw=$(openssl rand -base64 42 | tr -d '\n')
                            sed -i "s|please-change-me|${random_pw}|g" "$target_dir/.env"
                        fi
                    fi
                fi

                # Remove NVIDIA GPU reservation if no NVIDIA GPU is present
                if ! lspci | grep -qi 'nvidia'; then
                    sed -i '/deploy:/,/capabilities: \[gpu\]/d' "$target_dir/docker-compose.yml" 2>/dev/null || true
                fi


                # Start the service
                info "Starting ${label}..."
                (cd "$target_dir" && docker compose up -d) \
                    || warning "${label} failed to start - you can start it manually later."

                info "${label} deployed. See ${target_dir}/README.md for usage."
                INSTALLED_DOCKER_SERVICES+=("$dir_name")
                break
            fi
        done
    done
}

# ─── Create web app shortcuts for Docker services ───────────────────────────────
create_docker_web_apps() {
    local created=false

    # Tailscale web app (always created if tailscale is installed)
    if command -v tailscale &>/dev/null; then
        _create_web_app_desktop "Tailscale" "https://tailscale.com/" "tailscale"
        created=true
    fi

    for svc in "${INSTALLED_DOCKER_SERVICES[@]+"${INSTALLED_DOCKER_SERVICES[@]}"}"; do
        case "$svc" in
            immich)
                _create_web_app_desktop "Immich" "http://localhost:2283" "immich"
                created=true
                ;;
            ollama)
                _create_web_app_desktop "Open WebUI" "http://localhost:3000" "open-webui"
                created=true
                ;;
            zerotierone)
                _create_web_app_desktop "ZeroTier" "https://central.zerotier.com" "zerotier"
                created=true
                ;;
        esac
    done

    if [ "$created" = true ]; then
        info "Web app shortcuts created. You can also manage them in Web App Hub."
    fi
}

_create_web_app_desktop() {
    local name="$1" url="$2" icon_name="$3"
    local app_id
    app_id=$(echo "$name" | tr '[:upper:]' '[:lower:]-')

    # Install icon to local icon directory
    local icon_dir="$HOME/.local/share/icons/hicolor/256x256/apps"
    mkdir -p "$icon_dir"

    local src_icon=""
    case "$icon_name" in
        immich)    src_icon="$DOTFILES_DIR/icons/immich.png" ;;
        open-webui) src_icon="$DOTFILES_DIR/icons/open-webui-light.png" ;;
        zerotier)  src_icon="$DOTFILES_DIR/icons/zerotier.png" ;;
        tailscale) src_icon="$DOTFILES_DIR/icons/tailscale-light.png" ;;
    esac

    if [ -n "$src_icon" ] && [ -f "$src_icon" ]; then
        cp -f "$src_icon" "$icon_dir/${icon_name}.png"
        gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
    fi

    local desktop_file="$HOME/.local/share/applications/webapp-${app_id}.desktop"
    mkdir -p "$HOME/.local/share/applications"

    cat > "$desktop_file" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Terminal=false
Name=${name}
Exec=xdg-open ${url}
Icon=${icon_name}
Categories=Network;WebBrowser;
StartupNotify=true
EOF

    info "Created web app shortcut: ${name} → ${url}"
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

# ─── Essential Flatpak applications (always installed) ──────────────────────────
ESSENTIAL_FLATPAK_APPS=(
    "com.mattjakeman.ExtensionManager"     # Extension Manager - browse & toggle GNOME extensions
    "com.github.tchx84.Flatseal"           # Flatseal - manage Flatpak permissions
    "io.github.fabrialberio.pinapp"        # Pins - create custom app shortcuts
    "dev.qwery.AddWater"                   # Add Water - apply Adwaita theme to Firefox
    "io.github.swordpuffin.rewaita"        # Rewaita - bring color to Adwaita
    "io.missioncenter.MissionCenter"       # Mission Center - system monitor
    "org.pvermeer.WebAppHub"               # Web App Hub - manage web applications
)

install_essential_flatpaks() {
    info "Installing essential Flatpak applications..."
    for app in "${ESSENTIAL_FLATPAK_APPS[@]}"; do
        install_one_flatpak "$app"
    done

    # Install Firefox if not already present (prefer RPM over Flatpak; on atomic use Flatpak)
    if ! command -v firefox &>/dev/null && ! flatpak list 2>/dev/null | grep -q org.mozilla.firefox; then
        info "Installing Firefox..."
        if [ "$IS_ATOMIC" = true ]; then
            # On atomic systems, Firefox is best installed as a Flatpak
            install_one_flatpak "org.mozilla.firefox"
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y firefox \
                || warning "Could not install Firefox via dnf."
        elif command -v pacman &>/dev/null; then
            sudo pacman -Sy --noconfirm firefox \
                || warning "Could not install Firefox via pacman."
        elif command -v apt-get &>/dev/null; then
            sudo apt-get install -y firefox \
                || warning "Could not install Firefox via apt."
        else
            warning "Could not determine package manager to install Firefox."
        fi
    fi

    # Install GNOME Tweaks (system package, not available as Flatpak)
    info "Installing GNOME Tweaks..."
    if [ "$IS_ATOMIC" = true ]; then
        rpm -q gnome-tweaks &>/dev/null 2>&1 \
            || pkg_install gnome-tweaks
    elif command -v dnf &>/dev/null; then
        rpm -q gnome-tweaks &>/dev/null 2>&1 \
            || sudo dnf install -y gnome-tweaks \
            || warning "Could not install gnome-tweaks."
    elif command -v pacman &>/dev/null; then
        pacman -Qi gnome-tweaks &>/dev/null 2>&1 \
            || sudo pacman -Sy --noconfirm gnome-tweaks \
            || warning "Could not install gnome-tweaks."
    elif command -v apt-get &>/dev/null; then
        dpkg -s gnome-tweaks &>/dev/null 2>&1 \
            || sudo apt-get install -y gnome-tweaks \
            || warning "Could not install gnome-tweaks."
    fi
}

# ─── GNOME Shell extensions ────────────────────────────────────────────────────
# Format: "uuid|Human-readable name"
GNOME_EXTENSIONS=(
    "appindicatorsupport@rgcjonas.gmail.com|AppIndicator & KStatusNotifierItem Support"
    "arcmenu@arcmenu.com|ArcMenu"
    "clipboard-history@alexsaveau.dev|Clipboard History"
    "dash-to-dock@micxgx.gmail.com|Dash to Dock"
    "gtk4-ding@smedius.gitlab.com|Gtk4 Desktop Icons NG (DING)"
    "just-perfection-desktop@just-perfection|Just Perfection"
    "logomenu@aryan_k|Logo Menu"
    "panel-corners@aunetx|Panel Corners"
    "pip-on-top@rafostar.github.com|PiP on top"
    "quick-settings-audio-panel@rayzeq.github.io|Quick Settings Audio Panel"
    "restartto@tiagoporsch.github.io|Restart To"
    "user-theme@gnome-shell-extensions.gcampax.github.com|User Themes"
    "azwallpaper@azwallpaper.gitlab.com|Wallpaper Slideshow"
)

# Extensions to install but keep disabled by default
# Format: "uuid|Human-readable name"
GNOME_EXTENSIONS_DISABLED=(
    "rounded-window-corners@fxgn|Rounded Window Corners Reborn"
    "Vitals@CoreCoding.com|Vitals"
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
    local uuid="$1" name="$2" enable_after="${3:-true}"

    # Already installed - patch metadata and ensure correct state
    if gnome-extensions list 2>/dev/null | grep -qx "$uuid"; then
        patch_extension_metadata "$uuid"
        if [ "$enable_after" = "true" ]; then
            gnome-extensions enable "$uuid" 2>/dev/null || true
            info "$name is already installed - ensured enabled."
        else
            info "$name is already installed."
        fi
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

    # Enable or disable based on preference
    if [ "$enable_after" = "true" ]; then
        gnome-extensions enable "$uuid" 2>/dev/null || \
            warning "Installed $name but could not enable it - enable manually via Extension Manager."
    else
        gnome-extensions disable "$uuid" 2>/dev/null || true
        info "$name installed (disabled by default)."
    fi

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
        install_gnome_extension "$uuid" "$name" true
    done
    for entry in "${GNOME_EXTENSIONS_DISABLED[@]}"; do
        local uuid="${entry%%|*}"
        local name="${entry##*|}"
        install_gnome_extension "$uuid" "$name" false
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

# ─── RPM Fusion setup ────────────────────────────────────────────────────────────
ensure_rpmfusion() {
    if ! command -v dnf &>/dev/null && [ "$IS_ATOMIC" != true ]; then
        return 1
    fi
    if dnf repolist 2>/dev/null | grep -q rpmfusion; then
        return 0
    fi
    info "Enabling RPM Fusion repositories..."
    local fedora_ver
    fedora_ver=$(rpm -E %fedora 2>/dev/null) || return 1
    if [ "$IS_ATOMIC" = true ]; then
        rpm-ostree install --idempotent --allow-inactive -y \
            "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora_ver}.noarch.rpm" \
            "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora_ver}.noarch.rpm" \
            || { warning "Could not enable RPM Fusion via rpm-ostree."; return 1; }
    else
        sudo dnf install -y \
            "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora_ver}.noarch.rpm" \
            "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora_ver}.noarch.rpm" \
            || { warning "Could not enable RPM Fusion."; return 1; }
    fi
}

# ─── Install a single RPM package (enables RPM Fusion if needed) ────────────────
install_one_rpm() {
    local pkg="$1"
    if rpm -q "$pkg" &>/dev/null; then
        info "$pkg is already installed."
        return
    fi
    if [ "$IS_ATOMIC" = true ]; then
        info "Installing $pkg via rpm-ostree..."
        ensure_rpmfusion
        pkg_install "$pkg"
    else
        info "Installing $pkg via RPM..."
        # Try direct install first; if it fails, enable RPM Fusion and retry
        if ! sudo dnf install -y "$pkg" 2>/dev/null; then
            ensure_rpmfusion
            sudo dnf install -y "$pkg" || warning "Could not install $pkg via dnf."
        fi
    fi
}

# ─── Optional applications (interactive chooser) ───────────────────────────────
# Format: "Display Label|type:identifier"
#   type = flatpak  →  Flathub app ID
#   type = script   →  custom installer function name
#   type = rpm      →  RPM package name (enables RPM Fusion if needed)
OPTIONAL_APPS=(
    # Entertainment
    "Steam|rpm:steam"
    "Discord|flatpak:com.discordapp.Discord"
    "Signal|flatpak:org.signal.Signal"
    "VLC|flatpak:org.videolan.VLC"
    # Creative
    "Blender|flatpak:org.blender.Blender"
    "GIMP|flatpak:org.gimp.GIMP"
    "Unity Hub|flatpak:com.unity.UnityHub"
    # Utilities
    "Visual Studio Code|flatpak:com.visualstudio.code"
    "JetBrains Rider|flatpak:com.jetbrains.Rider"
    "GitHub Desktop|flatpak:io.github.shiftey.Desktop"
    "Trayscale (Tailscale GUI)|flatpak:dev.deedles.Trayscale"
    # Developer Tools
    "OpenCode (AI coding agent)|script:opencode"
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


# ─── OpenCode installer (AI coding agent) ──────────────────────────────────────
install_opencode() {
    if command -v opencode &>/dev/null; then
        info "OpenCode is already installed."
        return
    fi

    info "Installing OpenCode..."
    curl -fsSL https://opencode.ai/install | bash \
        || warning "OpenCode install encountered an error."

    if command -v opencode &>/dev/null; then
        info "OpenCode installed successfully."
    else
        warning "OpenCode binary not found on PATH after install."
        warning "You may need to restart your shell or add ~/.local/bin to PATH."
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
        raw=$(gum choose --no-limit --height=${#labels[@]} \
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
                    flatpak)
                        install_one_flatpak "$install_id"
                        # Post-install hooks for specific Flatpaks
                        if [ "$install_id" = "org.signal.Signal" ]; then
                            info "Configuring Signal to use GNOME Keyring..."
                            flatpak override --user --env=SIGNAL_PASSWORD_STORE=gnome-libsecret org.signal.Signal 2>/dev/null || true
                        fi
                        ;;
                    script)
                        case "$install_id" in
                            dotnet) install_dotnet ;;
                            opencode) install_opencode ;;
                            *) warning "Unknown install script: $install_id" ;;
                        esac
                        ;;
                    rpm)
                        install_one_rpm "$install_id"
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
    local dconf_file="$DOTFILES_DIR/gnome/${profile}.dconf"

    if [ ! -f "$dconf_file" ]; then
        warning "No dconf file found at $dconf_file - skipping GNOME settings import."
        return
    fi

    if ! command -v dconf &>/dev/null; then
        warning "dconf not found - skipping GNOME settings import."
        return
    fi

    info "Importing GNOME settings for profile '${profile}'..."
    sed "s|DOTFILES_DIR|${DOTFILES_DIR}|g" "$dconf_file" | dconf load /
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
        "Hide weekday in clock"
        "Login without asking for password (auto-login)"
        "Blank screen: Never (display stays on)"
        "Disable automatic screen lock"
        "Start with Bluetooth off"
        "Set regional formats from timezone"
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
                ;;
            "Hide weekday in clock")
                info "Hiding weekday in clock..."
                gsettings set org.gnome.desktop.interface clock-show-weekday false 2>/dev/null || true
                ;;
            "Login without asking for password (auto-login)")
                info "Enabling automatic login..."
                local current_user
                current_user=$(whoami)
                # Find GDM config file (varies by distro)
                local gdm_conf=""
                for f in /etc/gdm/custom.conf /etc/gdm3/custom.conf; do
                    if [ -f "$f" ]; then gdm_conf="$f"; break; fi
                done
                if [ -z "$gdm_conf" ]; then
                    # Create default location
                    sudo mkdir -p /etc/gdm 2>/dev/null || true
                    gdm_conf="/etc/gdm/custom.conf"
                fi
                if [ -f "$gdm_conf" ]; then
                    sudo sed -i '/^\[daemon\]/,/^\[/ { /^AutomaticLoginEnable/d; /^AutomaticLogin=/d; }' "$gdm_conf"
                    sudo sed -i "/^\[daemon\]/a AutomaticLoginEnable=True\nAutomaticLogin=${current_user}" "$gdm_conf"
                else
                    echo -e "[daemon]\nAutomaticLoginEnable=True\nAutomaticLogin=${current_user}" \
                        | sudo tee "$gdm_conf" > /dev/null
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
            "Start with Bluetooth off")
                info "Disabling Bluetooth on startup..."
                sudo systemctl disable bluetooth 2>/dev/null || true
                sudo rfkill block bluetooth 2>/dev/null || true
                ;;
            "Set regional formats from timezone")
                info "Detecting timezone and setting regional formats..."
                local tz=""
                tz=$(timedatectl show --property=Timezone --value 2>/dev/null) || true
                if [ -z "$tz" ]; then
                    tz=$(cat /etc/timezone 2>/dev/null) || true
                fi
                if [ -z "$tz" ]; then
                    warning "Could not detect timezone - skipping regional format."
                else
                    # Look up 2-letter country code from zone.tab
                    local cc=""
                    cc=$(awk -v tz="$tz" '$3 == tz { print $1; exit }' /usr/share/zoneinfo/zone.tab 2>/dev/null) || true
                    if [ -z "$cc" ]; then
                        warning "Could not determine country for timezone $tz - skipping."
                    else
                        # Find a UTF-8 locale matching _CC (e.g. DE → de_DE.UTF-8)
                        local region_locale=""
                        region_locale=$(locale -a 2>/dev/null \
                            | grep -i "_${cc}\." \
                            | grep -i 'utf' \
                            | head -1) || true
                        if [ -n "$region_locale" ]; then
                            # Normalise to xx_CC.UTF-8 form
                            region_locale=$(echo "$region_locale" | sed 's/utf8/UTF-8/; s/\.utf-8/.UTF-8/i')
                            dconf write /system/locale/region "'$region_locale'" 2>/dev/null || true
                            info "Regional format set to $region_locale (timezone: $tz, country: $cc)."
                        else
                            warning "No UTF-8 locale found for country $cc - skipping."
                        fi
                    fi
                fi
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

    # Star Steam library folder if Steam is installed
    local steam_folder="/home/${current_user}/.steam/steam/steamapps/common"
    if flatpak list --app --columns=application 2>/dev/null | grep -qx "com.valvesoftware.Steam" \
       || rpm -q steam &>/dev/null \
       || [ -d "$steam_folder" ]; then
        if [ -d "$steam_folder" ]; then
            gio set -t stringv "$steam_folder" metadata::xdg-tags "starred" 2>/dev/null \
                || warning "Could not star $steam_folder"
            info "Starred: $steam_folder"
        else
            info "Steam installed but library folder not yet created - star it after first launch."
        fi
    fi

    info "Nautilus configuration complete."
}

# ─── Create ~/Templates for right-click "New Document" menu ─────────────────────
setup_templates() {
    local tpl_dir
    tpl_dir=$(xdg-user-dir TEMPLATES 2>/dev/null || echo "$HOME/Templates")
    info "Setting up Templates directory at ${tpl_dir}..."

    mkdir -p "$tpl_dir"

    # Text file
    [ -f "$tpl_dir/untitled-document.txt" ] \
        || touch "$tpl_dir/untitled-document.txt"

    # Markdown
    [ -f "$tpl_dir/untitled-document.md" ] \
        || touch "$tpl_dir/untitled-document.md"

    # Shell script
    if [ ! -f "$tpl_dir/untitled-script.sh" ]; then
        echo '#!/usr/bin/env bash' > "$tpl_dir/untitled-script.sh"
        chmod +x "$tpl_dir/untitled-script.sh"
    fi

    # Python script
    if [ ! -f "$tpl_dir/untitled-script.py" ]; then
        echo '#!/usr/bin/env python3' > "$tpl_dir/untitled-script.py"
    fi

    # C# file
    [ -f "$tpl_dir/untitled-class.cs" ] \
        || touch "$tpl_dir/untitled-class.cs"

    # HTML file
    if [ ! -f "$tpl_dir/untitled-document.html" ]; then
        cat > "$tpl_dir/untitled-document.html" << 'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Untitled</title>
</head>
<body>

</body>
</html>
HTML
    fi

    info "Templates directory ready ($(ls "$tpl_dir" | wc -l) templates)."
}

# ─── Configure app defaults (Terminal, Text Editor) ─────────────────────────────
configure_app_defaults() {
    info "Configuring app defaults..."

    # Ptyxis (Terminal) - disable session restore
    gsettings set org.gnome.Ptyxis restore-session false 2>/dev/null || true
    gsettings set org.gnome.Ptyxis restore-window-size false 2>/dev/null || true

    # GNOME Text Editor - disable session restore
    gsettings set org.gnome.TextEditor restore-session false 2>/dev/null || true

    info "App defaults configured."
}

# ─── Adwaita theme setup (adw-gtk3 + Flatpak overrides) ────────────────────────
setup_themes() {
    info "Setting up Adwaita themes..."

    # Install adw-gtk3 theme (makes GTK3 apps match GTK4 Adwaita)
    if [ "$IS_ATOMIC" = true ]; then
        if ! rpm -q adw-gtk3-theme &>/dev/null 2>&1; then
            info "Installing adw-gtk3-theme..."
            pkg_install adw-gtk3-theme
        else
            info "adw-gtk3-theme is already installed."
        fi
    elif command -v dnf &>/dev/null; then
        if ! rpm -q adw-gtk3-theme &>/dev/null 2>&1; then
            info "Installing adw-gtk3-theme..."
            sudo dnf install -y adw-gtk3-theme || warning "Could not install adw-gtk3-theme."
        else
            info "adw-gtk3-theme is already installed."
        fi
    elif command -v pacman &>/dev/null; then
        if ! pacman -Qi adw-gtk3 &>/dev/null 2>&1; then
            info "Installing adw-gtk3..."
            sudo pacman -Sy --noconfirm adw-gtk3 2>/dev/null \
                || { if command -v yay &>/dev/null; then yay -S --noconfirm adw-gtk3; \
                     elif command -v paru &>/dev/null; then paru -S --noconfirm adw-gtk3; \
                     else warning "Could not install adw-gtk3 - install manually from AUR."; fi; }
        else
            info "adw-gtk3 is already installed."
        fi
    fi

    # Apply adw-gtk3-dark as GTK theme (for GTK3 apps)
    gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true

    # Allow Flatpak apps to access GTK themes
    flatpak override --user --filesystem=xdg-config/gtk-4.0 2>/dev/null || true
    flatpak override --user --filesystem=xdg-config/gtk-3.0 2>/dev/null || true

    info "Themes applied."
    info "Open Rewaita to browse and apply Adwaita icon theme variants."
}

# ─── Install Rewaita custom themes ─────────────────────────────────────────────
# Copies the bundled theme CSS files into Rewaita's data directory and
# configures prefs.json so they are selected by default.
REWAITA_DATA_DIR="$HOME/.var/app/io.github.swordpuffin.rewaita/data"

install_rewaita_themes() {
    info "Installing Rewaita custom themes..."

    local dark_dir="$REWAITA_DATA_DIR/dark"
    local light_dir="$REWAITA_DATA_DIR/light"
    mkdir -p "$dark_dir" "$light_dir"

    # Copy bundled themes
    local src="$DOTFILES_DIR"
    cp -f "$src/themes/dark/A Default Dark Theme.css"  "$dark_dir/"  2>/dev/null || warning "Could not copy default dark theme."
    cp -f "$src/themes/dark/A Oled Dark Theme.css"     "$dark_dir/"  2>/dev/null || warning "Could not copy Oled dark theme."
    cp -f "$src/themes/light/A Default Light Theme.css" "$light_dir/" 2>/dev/null || warning "Could not copy default light theme."

    info "Theme files installed into Rewaita data directory."

    # Configure Rewaita prefs.json - select the default dark/light themes
    local prefs_file="$REWAITA_DATA_DIR/prefs.json"
    python3 -c "
import json, os

path = '$prefs_file'
try:
    with open(path) as f:
        prefs = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    prefs = {}

# Set defaults, preserving any existing keys
prefs.setdefault('window-controls', 'default')
prefs.setdefault('modify-gtk3-theme', True)
prefs.setdefault('modify-gnome-shell', True)
prefs.setdefault('run-in-background', True)
prefs.setdefault('transparency', False)
prefs.setdefault('window', False)
prefs.setdefault('sharp', False)
prefs.setdefault('light-text', False)

# Select our custom themes
prefs['dark-theme']  = 'A Default Dark Theme.css'
prefs['light-theme'] = 'A Default Light Theme.css'

with open(path, 'w') as f:
    json.dump(prefs, f, indent=4)
" 2>/dev/null || warning "Could not write Rewaita prefs.json."

    info "Rewaita configured with default dark and light themes."
}

# ─── Ask Oled / pure-black preference ──────────────────────────────────────────
# If the user wants pure black (Oled) mode:
#   • Switch Rewaita dark theme to the Oled variant
#   • Enable Add Water "True Black" (oled-black) for Firefox
#   • Set GNOME Text Editor appearance to Classic Dark
#   • Set terminal (Ptyxis) palette to Dark Pastel
ask_oled_preference() {
    echo ""

    if [ "$GUM_AVAILABLE" = true ] && command -v gum &>/dev/null; then
        if gum confirm --default=no "  Use pure-black Oled dark theme?"; then
            USE_OLED=true
        fi
    else
        echo -e "${CYAN}${BOLD}Use pure-black Oled dark theme?${NC} [y/N]"
        local answer
        read -rp "> " answer
        case "$answer" in
            [yY]*) USE_OLED=true ;;
        esac
    fi

    if [ "$USE_OLED" = false ]; then
        info "Using standard dark theme."

        # Set Text Editor to Adwaita Dark
        gsettings set org.gnome.TextEditor style-scheme 'Adwaita-dark' 2>/dev/null || true

        # Set Terminal (Ptyxis) palette to GNOME (default)
        local profile_uuid=""
        profile_uuid=$(dconf read /org/gnome/Ptyxis/default-profile-uuid 2>/dev/null | tr -d "'" || true)
        if [ -z "$profile_uuid" ]; then
            local raw_uuids=""
            raw_uuids=$(dconf read /org/gnome/Ptyxis/profile-uuids 2>/dev/null || true)
            if [ -n "$raw_uuids" ]; then
                profile_uuid=$(echo "$raw_uuids" \
                    | python3 -c "import sys,ast; l=ast.literal_eval(sys.stdin.read()); print(l[0] if l else '')" 2>/dev/null || true)
            fi
        fi
        if [ -n "$profile_uuid" ]; then
            dconf write "/org/gnome/Ptyxis/Profiles/$profile_uuid/palette" "'gnome'" 2>/dev/null || true
        fi

        return
    fi

    info "Applying Oled / pure-black settings..."

    # 1. Switch Rewaita dark theme to Oled variant
    local prefs_file="$REWAITA_DATA_DIR/prefs.json"
    python3 -c "
import json
path = '$prefs_file'
try:
    with open(path) as f:
        prefs = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    prefs = {}
prefs['dark-theme'] = 'A Oled Dark Theme.css'
with open(path, 'w') as f:
    json.dump(prefs, f, indent=4)
" 2>/dev/null || warning "Could not update Rewaita prefs for Oled."
    info "Rewaita dark theme set to Oled variant."

    # 2. Enable Add Water "True Black" for Firefox
    #    Add Water is a Flatpak - use flatpak run to set gsettings inside the sandbox
    if command -v flatpak &>/dev/null; then
        flatpak run --command=gsettings dev.qwery.AddWater set dev.qwery.AddWater.Firefox oled-black true 2>/dev/null \
            || warning "Could not set Add Water oled-black (run Add Water once first)."
        info "Add Water True Black enabled for Firefox."
    else
        warning "flatpak not available - skipping Add Water True Black."
    fi

    # 3. GNOME Text Editor → Classic Dark appearance
    gsettings set org.gnome.TextEditor style-scheme 'classic-dark' 2>/dev/null || true
    info "Text Editor set to Classic Dark."

    # 4. Terminal (Ptyxis) → Dark Pastel palette
    local profile_uuid=""
    profile_uuid=$(dconf read /org/gnome/Ptyxis/default-profile-uuid 2>/dev/null | tr -d "'" || true)
    if [ -z "$profile_uuid" ]; then
        local raw_uuids=""
        raw_uuids=$(dconf read /org/gnome/Ptyxis/profile-uuids 2>/dev/null || true)
        if [ -n "$raw_uuids" ]; then
            profile_uuid=$(echo "$raw_uuids" \
                | python3 -c "import sys,ast; l=ast.literal_eval(sys.stdin.read()); print(l[0] if l else '')" 2>/dev/null || true)
        fi
    fi
    if [ -z "$profile_uuid" ]; then
        # No profile exists yet - create one with a deterministic UUID
        profile_uuid="d4e5f6a7-b8c9-0d1e-2f3a-4b5c6d7e8f90"
        dconf write /org/gnome/Ptyxis/default-profile-uuid "'$profile_uuid'" 2>/dev/null || true
        dconf write /org/gnome/Ptyxis/profile-uuids "['$profile_uuid']" 2>/dev/null || true
    fi
    if [ -n "$profile_uuid" ]; then
        dconf write "/org/gnome/Ptyxis/Profiles/$profile_uuid/palette" "'Dark Pastel'" 2>/dev/null || true
        info "Terminal palette set to Dark Pastel."
    else
        warning "Could not determine Ptyxis profile UUID - set terminal palette manually."
    fi

    # Also set Ptyxis interface style to dark
    gsettings set org.gnome.Ptyxis interface-style 'dark' 2>/dev/null || true

    info "Oled / pure-black settings applied."
}

# ─── Configure Add Water (Adwaita theme for Firefox) ───────────────────────────
configure_addwater() {
    info "Configuring Add Water for Firefox..."

    # Add Water is a Flatpak - use flatpak run to set gsettings inside the sandbox.
    # Add Water still needs to run once to actually install the CSS into the Firefox profile.
    if command -v flatpak &>/dev/null; then
        flatpak run --command=gsettings dev.qwery.AddWater set dev.qwery.AddWater.Firefox theme-enabled true 2>/dev/null || true
        flatpak run --command=gsettings dev.qwery.AddWater set dev.qwery.AddWater.Firefox hide-single-tab true 2>/dev/null || true
        flatpak run --command=gsettings dev.qwery.AddWater set dev.qwery.AddWater.Firefox normal-width-tabs true 2>/dev/null || true
        flatpak run --command=gsettings dev.qwery.AddWater set dev.qwery.AddWater.background-update true 2>/dev/null || true
        info "Add Water preferences set. Open Add Water once to apply the theme to Firefox."
    else
        warning "flatpak not available - skipping Add Water configuration."
    fi
}

# ─── Configure Firefox preferences ─────────────────────────────────────────────
configure_firefox() {
    info "Configuring Firefox preferences..."

    local src_user_js="$DOTFILES_DIR/firefox-profile/user.js"
    if [ ! -f "$src_user_js" ]; then
        warning "No user.js found in repo - skipping Firefox configuration."
        return
    fi

    # Find all Firefox profile directories (supports system, Flatpak, and Snap installs)
    local profile_dirs=()
    local search_roots=(
        "$HOME/.mozilla/firefox"
        "$HOME/.config/mozilla/firefox"
        "$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox"
        "$HOME/.var/app/org.mozilla.firefox/config/mozilla/firefox"
        "$HOME/snap/firefox/common/.mozilla/firefox"
    )

    # Ensure Firefox has created its profile directories
    # If no profiles exist yet, launch Firefox briefly to generate them
    local needs_init=true
    for root in "${search_roots[@]}"; do
        if [ -f "$root/profiles.ini" ]; then
            needs_init=false
            break
        fi
    done

    if [ "$needs_init" = true ]; then
        info "Launching Firefox briefly to create profile directories..."
        # Kill any running instance first
        pkill -f firefox 2>/dev/null || true
        sleep 1
        firefox --headless &>/dev/null &
        local ff_pid=$!
        sleep 5
        kill "$ff_pid" 2>/dev/null || true
        wait "$ff_pid" 2>/dev/null || true
        sleep 1
        info "Firefox profile directories created."
    else
        # Make sure Firefox is closed so our files don't get overwritten
        if pgrep -x firefox &>/dev/null; then
            info "Closing Firefox to apply toolbar and preference changes..."
            pkill -x firefox 2>/dev/null || true
            sleep 3
        fi
    fi

    for root in "${search_roots[@]}"; do
        [ -d "$root" ] || continue

        # 1. Parse profiles.ini for declared profile paths
        if [ -f "$root/profiles.ini" ]; then
            while IFS= read -r line || [ -n "$line" ]; do
                # Strip carriage returns and leading/trailing whitespace
                line="${line%%$'\r'}"
                line="${line#"${line%%[![:space:]]*}"}"
                case "$line" in
                    Path=*)
                        local value="${line#Path=}"
                        local pdir
                        if [[ "$value" = /* ]]; then
                            pdir="$value"
                        else
                            pdir="$root/$value"
                        fi
                        if [ -d "$pdir" ]; then
                            profile_dirs+=("$pdir")
                        fi
                        ;;
                esac
            done < "$root/profiles.ini"
        fi

        # 2. Also scan for directories containing prefs.js (without process substitution)
        local found_prefs
        found_prefs=$(find "$root" -maxdepth 2 -name 'prefs.js' -type f 2>/dev/null) || true
        if [ -n "$found_prefs" ]; then
            while IFS= read -r pjs; do
                [ -n "$pjs" ] && profile_dirs+=("$(dirname "$pjs")")
            done <<< "$found_prefs"
        fi
    done

    # Deduplicate
    if [ ${#profile_dirs[@]} -gt 0 ]; then
        local unique=()
        for d in "${profile_dirs[@]}"; do
            local dup=false
            for u in "${unique[@]+"${unique[@]}"}"; do
                [ "$d" = "$u" ] && { dup=true; break; }
            done
            $dup || unique+=("$d")
        done
        profile_dirs=("${unique[@]}")
    fi

    if [ ${#profile_dirs[@]} -eq 0 ]; then
        warning "No Firefox profiles found - skipping Firefox configuration."
        warning "Launch Firefox once, close it, then re-run the installer to configure it."
        return
    fi

    for profile in "${profile_dirs[@]}"; do
        local target="$profile/user.js"

        # Copy user.js from repo
        cp -f "$src_user_js" "$target"

        # Toggle Oled setting based on user choice
        if [ "$USE_OLED" = true ]; then
            sed -i 's/user_pref("gnomeTheme.oledBlack", false);/user_pref("gnomeTheme.oledBlack", true);/' "$target"
            sed -i 's/user_pref("browser.display.background_color", "#2b2b2b");/user_pref("browser.display.background_color", "#000000");/' "$target"
        fi


        info "Configured Firefox profile: $(basename "$profile")"

        # Clear all bookmarks via sqlite3
        if [ -f "$profile/places.sqlite" ] && command -v sqlite3 &>/dev/null; then
            sqlite3 "$profile/places.sqlite" "DELETE FROM moz_bookmarks;" 2>/dev/null || true
            info "Cleared bookmarks for profile: $(basename "$profile")"
        fi
    done

    info "Firefox preferences applied (takes effect on next Firefox launch)."

    # ── Deploy policies.json for search engine & toolbar policy ──
    local src_policies="$DOTFILES_DIR/firefox-profile/policies.json"
    if [ -f "$src_policies" ]; then
        info "Deploying Firefox enterprise policies (search engine, toolbar)..."

        # Possible Firefox installation directories
        local firefox_dirs=(
            "/usr/lib/firefox"
            "/usr/lib64/firefox"
            "/usr/share/firefox"
            "/usr/lib/firefox-esr"
            "/opt/firefox"
            "/snap/firefox/current/usr/lib/firefox"
            "/var/lib/flatpak/app/org.mozilla.firefox/current/active/files/lib/firefox"
        )

        # Also check common distro-specific locations
        local found_any=false
        for fdir in "${firefox_dirs[@]}"; do
            if [ -d "$fdir" ]; then
                local dist_dir="$fdir/distribution"
                # On atomic systems /usr is read-only, skip system dirs
                if [ "$IS_ATOMIC" = true ] && [[ "$fdir" == /usr/* ]]; then
                    continue
                fi
                sudo mkdir -p "$dist_dir" 2>/dev/null || continue
                if sudo cp -f "$src_policies" "$dist_dir/policies.json" 2>/dev/null; then
                    sudo chmod 644 "$dist_dir/policies.json" 2>/dev/null
                    info "Installed policies.json → $dist_dir/"
                    found_any=true
                fi
            fi
        done

        # For Snap Firefox, also try the writable config path
        local snap_dist="$HOME/snap/firefox/common/.mozilla/firefox/distribution"
        if [ -d "$HOME/snap/firefox" ]; then
            mkdir -p "$snap_dist" 2>/dev/null
            cp -f "$src_policies" "$snap_dist/policies.json" 2>/dev/null && {
                info "Installed policies.json → $snap_dist/"
                found_any=true
            }
        fi

        # For Flatpak Firefox, try the user override path
        local flatpak_dist="$HOME/.var/app/org.mozilla.firefox/config/mozilla/firefox/distribution"
        if [ -d "$HOME/.var/app/org.mozilla.firefox" ]; then
            mkdir -p "$flatpak_dist" 2>/dev/null
            cp -f "$src_policies" "$flatpak_dist/policies.json" 2>/dev/null && {
                info "Installed policies.json → $flatpak_dist/"
                found_any=true
            }
        fi

        if [ "$found_any" = false ]; then
            warning "Could not find Firefox installation directory to deploy policies.json."
            warning "You may need to manually copy policies.json to your Firefox distribution/ folder."
        else
            info "Firefox policies deployed (search engine & toolbar changes take effect on next launch)."
        fi
    fi
}


# ─── Pin installed optional apps to favorites ──────────────────────────────────
# Ordered list: "flatpak_id|rpm_desktop_name(s)"
# rpm_desktop_name is a comma-separated list of common .desktop filenames
# (without .desktop suffix) to look for when the app is installed via RPM.
OPTIONAL_PIN_ORDER=(
    # Entertainment
    "com.valvesoftware.Steam|steam"
    "com.discordapp.Discord|discord"
    "org.signal.Signal|signal-desktop"
    # Creative
    "org.blender.Blender|blender"
    "org.gimp.GIMP|gimp"
    "com.unity.UnityHub|unityhub"
    # Utilities
    "com.visualstudio.code|code"
    "com.jetbrains.Rider|jetbrains-rider"
    "io.github.shiftey.Desktop|github-desktop"
)

# Find the .desktop file for an app, checking Flatpak first then RPM names.
# Returns the desktop filename (e.g. "com.discordapp.Discord.desktop" or "steam.desktop")
# or empty string if not found.
_resolve_desktop_file() {
    local flatpak_id="$1"
    local rpm_names="$2"

    # Check Flatpak
    if flatpak list --app --columns=application 2>/dev/null | grep -qx "$flatpak_id"; then
        echo "${flatpak_id}.desktop"
        return
    fi

    # Check RPM / system .desktop files
    IFS=',' read -ra names <<< "$rpm_names"
    for name in "${names[@]}"; do
        for dir in /usr/share/applications /usr/local/share/applications "$HOME/.local/share/applications"; do
            if [ -f "$dir/${name}.desktop" ]; then
                echo "${name}.desktop"
                return
            fi
        done
    done
}

pin_optional_apps_to_favorites() {
    # Get current favorites
    local current_favs
    current_favs=$(gsettings get org.gnome.shell favorite-apps 2>/dev/null) || return 0

    # Apps that must always stay at the very end of the dock
    local -a tail_apps=(
        "org.gnome.Nautilus.desktop"
        "org.gnome.Ptyxis.desktop"
        "org.gnome.Software.desktop"
    )

    # Remove tail apps from the list (we'll re-append them at the end)
    for tail in "${tail_apps[@]}"; do
        current_favs=$(echo "$current_favs" | sed "s/, *'${tail}'//g; s/'${tail}', *//g; s/'${tail}'//g")
    done

    local changed=false

    for entry in "${OPTIONAL_PIN_ORDER[@]}"; do
        local flatpak_id="${entry%%|*}"
        local rpm_names="${entry#*|}"
        local desktop
        desktop=$(_resolve_desktop_file "$flatpak_id" "$rpm_names")

        if [ -n "$desktop" ]; then
            if ! echo "$current_favs" | grep -q "'${desktop}'"; then
                # Append before the closing bracket
                current_favs="${current_favs%]*}, '${desktop}']"
                changed=true
                info "Pinned $desktop to favorites."
            fi
        fi
    done

    # Re-append tail apps at the very end
    for tail in "${tail_apps[@]}"; do
        current_favs="${current_favs%]*}, '${tail}']"
    done
    changed=true

    if [ "$changed" = true ]; then
        gsettings set org.gnome.shell favorite-apps "$current_favs" 2>/dev/null || true
    fi
}

# ─── Register OpenCode shortcut (Super+C) if installed ─────────────────────────
register_opencode_shortcut() {
    if ! command -v opencode &>/dev/null; then
        return
    fi

    info "Registering Super+C shortcut for OpenCode..."

    # Read current custom keybindings list
    local current
    current=$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings 2>/dev/null) || return 0

    local path="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/"

    # Only add if not already present
    if echo "$current" | grep -q "custom2"; then
        info "Custom keybinding slot custom2 already in use - skipping."
        return
    fi

    # Append custom2 to the list
    current="${current%]*}, '${path}']"
    gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$current" 2>/dev/null || true

    # Set the keybinding
    dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/name "'OpenCode'" 2>/dev/null || true
    dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/command "'ptyxis -e opencode'" 2>/dev/null || true
    dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/binding "'<Super>c'" 2>/dev/null || true

    info "OpenCode shortcut registered: Super+C"
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

        # Set the Wallpaper Slideshow extension to use the preferred folder
        local slideshow_dir="$WALLPAPER_DIR/m-26.jp"
        if [ -d "$slideshow_dir" ]; then
            # Write directly via dconf (most reliable for extensions with bundled schemas)
            dconf write /org/gnome/shell/extensions/azwallpaper/slideshow-directory "'$slideshow_dir'" 2>/dev/null || true

            # Also try gsettings with the extension's compiled schema dir as fallback
            local ext_schema_dir="$HOME/.local/share/gnome-shell/extensions/azwallpaper@azwallpaper.gitlab.com/schemas"
            if [ -d "$ext_schema_dir" ]; then
                GSETTINGS_SCHEMA_DIR="$ext_schema_dir" gsettings set org.gnome.shell.extensions.azwallpaper slideshow-directory "$slideshow_dir" 2>/dev/null || true
            fi
            info "Wallpaper Slideshow set to $slideshow_dir"
        fi
    fi
}

# ─── Uninstall GNOME bloatware ──────────────────────────────────────────────────
# Format: "flatpak-id|dnf-package|pacman-package|Display Name"
# Use "-" if no flatpak/dnf/pacman package exists for that app.
GNOME_BLOAT_APPS=(
    "org.gnome.Boxes|gnome-boxes|gnome-boxes|Boxes"
    "org.gnome.Calendar|gnome-calendar|gnome-calendar|Calendar"
    "org.gnome.Snapshot|snapshot|snapshot|Camera"
    "org.gnome.Characters|gnome-characters|gnome-characters|Characters"
    "org.gnome.clocks|gnome-clocks|gnome-clocks|Clocks"
    "org.gnome.Connections|gnome-connections|gnome-connections|Connections"
    "org.gnome.Contacts|gnome-contacts|gnome-contacts|Contacts"
    "org.gnome.Extensions|gnome-extensions-app|gnome-extensions-app|Extensions"
    "org.gnome.baobab|baobab|baobab|Disk Usage Analyser"
    "org.gnome.SimpleScan|simple-scan|simple-scan|Document Scanner"
    "org.fedoraproject.MediaWriter|mediawriter|-|Fedora Media Writer"
    "org.gnome.Yelp|yelp|yelp|Help"
    "-|libreoffice-calc|libreoffice-still-calc|LibreOffice Calc"
    "-|libreoffice-impress|libreoffice-still-impress|LibreOffice Impress"
    "-|libreoffice-writer|libreoffice-still-writer|LibreOffice Writer"
    "org.gnome.Maps|gnome-maps|gnome-maps|Maps"
    "org.gnome.SystemMonitor|gnome-system-monitor|gnome-system-monitor|System Monitor"
    "org.gnome.Tour|gnome-tour|gnome-tour|Tour"
    "org.gnome.Weather|gnome-weather|gnome-weather|Weather"
)

# Packages whose removal would break the desktop - never touch these via dnf/pacman.
PROTECTED_RE="gnome-shell|gdm|mutter|gnome-session|gnome-settings-daemon"

# Safely remove an RPM package: dry-run first, skip if it would cascade into
# removing any protected desktop component.
safe_dnf_remove() {
    local pkg="$1" label="$2"

    # Not installed - nothing to do
    command -v rpm &>/dev/null || return 0
    rpm -q "$pkg" &>/dev/null 2>&1 || return 0

    # Dry-run: would this also pull gnome-shell / gdm / mutter?
    local sim
    sim=$(dnf remove --assumeno --setopt=clean_requirements_on_remove=True "$pkg" 2>&1 || true)
    if echo "$sim" | grep -qEi "$PROTECTED_RE"; then
        warning "Skipping $label ($pkg) - removing it would also remove core desktop packages."
        return 0
    fi

    info "Removing RPM: $pkg ($label)..."
    sudo dnf remove -y --noautoremove "$pkg" 2>/dev/null \
        || warning "Failed to remove $pkg."
}

# Safely remove a pacman package (Arch-based systems)
safe_pacman_remove() {
    local pkg="$1" label="$2"

    # Not installed - nothing to do
    pacman -Qi "$pkg" &>/dev/null 2>&1 || return 0

    # Check what would be removed - simulate and check for protected packages
    local sim
    sim=$(pacman -Rcs --print "$pkg" 2>&1 || true)
    if echo "$sim" | grep -qEi "$PROTECTED_RE"; then
        warning "Skipping $label ($pkg) - removing it would also remove core desktop packages."
        return 0
    fi

    info "Removing package: $pkg ($label)..."
    sudo pacman -Rns --noconfirm "$pkg" 2>/dev/null \
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
        rest="${rest#*|}"
        local pacman_pkg="${rest%%|*}"
        local label="${rest#*|}"

        # 1. Try Flatpak removal (safe, no side-effects)
        if [ "$flatpak_id" != "-" ]; then
            if flatpak list --app --columns=application 2>/dev/null | grep -qx "$flatpak_id"; then
                info "Removing Flatpak: $label..."
                flatpak uninstall -y "$flatpak_id" 2>/dev/null \
                    || warning "Failed to remove Flatpak $label."
            fi
        fi

        # 2. Try RPM/system package removal
        if [ "$dnf_pkg" != "-" ]; then
            if [ "$IS_ATOMIC" = true ]; then
                pkg_remove "$dnf_pkg" "$label"
            elif command -v dnf &>/dev/null; then
                safe_dnf_remove "$dnf_pkg" "$label"
            fi
        # 3. Try pacman removal (Arch-based)
        elif [ "$pacman_pkg" != "-" ] && command -v pacman &>/dev/null; then
            safe_pacman_remove "$pacman_pkg" "$label"
        fi
    done

    info "Bloat removal complete."
}

# ─── Main ──────────────────────────────────────────────────────────────────────
main() {
    echo ""
    echo -e "${CYAN}${BOLD}"
    cat << 'BANNER'
 ██████╗ ███╗   ██╗ ██████╗ ███╗   ███╗███████╗
██╔════╝ ████╗  ██║██╔═══██╗████╗ ████║██╔════╝
██║  ███╗██╔██╗ ██║██║   ██║██╔████╔██║█████╗  
██║   ██║██║╚██╗██║██║   ██║██║╚██╔╝██║██╔══╝  
╚██████╔╝██║ ╚████║╚██████╔╝██║ ╚═╝ ██║███████╗
 ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝
██████╗ ██╗     ██╗   ██╗███████╗██████╗ ██████╗ ██╗███╗   ██╗████████╗
██╔══██╗██║     ██║   ██║██╔════╝██╔══██╗██╔══██╗██║████╗  ██║╚══██╔══╝
██████╔╝██║     ██║   ██║█████╗  ██████╔╝██████╔╝██║██╔██╗ ██║   ██║   
██╔══██╗██║     ██║   ██║██╔══╝  ██╔═══╝ ██╔══██╗██║██║╚██╗██║   ██║   
██████╔╝███████╗╚██████╔╝███████╗██║     ██║  ██║██║██║ ╚████║   ██║   
╚═════╝ ╚══════╝ ╚═════╝ ╚══════╝╚═╝     ╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝   ╚═╝   
BANNER
    echo -e "${NC}"

    # 0. Detect atomic/immutable Fedora
    detect_atomic

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
    install_docker
    install_tailscale
    install_fastfetch

    # 5. Apply profile-specific dconf settings first (base layer)
    import_gnome_settings "$profile"
    run_profile "$profile"

    # 6. Essential Flatpaks (includes Mission Center) & GNOME extensions
    install_essential_flatpaks
    install_gnome_extensions
    restart_gnome_shell

    # Re-apply dconf settings after extensions are installed
    # (freshly installed extensions may reset to defaults on first enable)
    sleep 3
    import_gnome_settings "$profile"

    # 7. Adwaita theme setup (adw-gtk3 + Flatpak overrides)
    setup_themes

    # 8. Install Rewaita custom themes (dark, Oled dark, light)
    install_rewaita_themes

    # 9. Ask Oled preference (pure-black dark theme, Add Water, Text Editor, Terminal)
    ask_oled_preference

    # 10. Configure Add Water & Firefox
    configure_addwater
    configure_firefox

    # 11. User preferences override dconf base (24h clock, auto-login, blank screen, battery)
    ask_user_preferences

    # 12. Nautilus configuration (sort, list view, context menu, starred folders)
    configure_nautilus

    # 12b. Create ~/Templates for right-click "New Document" menu
    setup_templates

    # 13. App defaults (Terminal, Text Editor - disable session restore)
    configure_app_defaults

    # 14. Download wallpaper collection
    ask_download_wallpapers

    # 15. Ask to uninstall GNOME bloat
    ask_uninstall_bloat

    # 16. Optional applications (interactive chooser)
    select_and_install_optional_apps

    # 17. Docker Compose services (interactive chooser)
    select_and_install_docker_services

    # 17b. Create web app shortcuts for installed Docker services
    create_docker_web_apps

    # 18. Pin any installed optional apps to dock favorites
    pin_optional_apps_to_favorites

    # 19. Register OpenCode shortcut (Super+C) if installed
    register_opencode_shortcut

    # 20. Reset app grid (remove folders, single alphabetical view)
    reset_app_grid

    # 21. Detect & install NVIDIA drivers
    install_nvidia_drivers

    # 22. Final system cleanup & update
    final_cleanup

    # 23. Ask to reboot
    echo ""
    info "Installation complete!"
    ask_reboot
}

# ─── NVIDIA driver installation ──────────────────────────────────────────────
install_nvidia_drivers() {
    # Check if an NVIDIA GPU is present
    if ! lspci | grep -qi 'nvidia'; then
        return
    fi

    info "NVIDIA GPU detected: $(lspci | grep -i 'nvidia' | head -1 | sed 's/.*: //')"

    # Check if NVIDIA drivers are already installed
    if modinfo nvidia &>/dev/null; then
        local current_ver
        current_ver=$(modinfo -F version nvidia 2>/dev/null || echo "unknown")
        info "NVIDIA driver already installed (version $current_ver). Skipping."
        return
    fi

    local do_nvidia=false
    if command -v gum &>/dev/null; then
        if gum confirm --default=yes "  Install NVIDIA proprietary drivers?"; then
            do_nvidia=true
        fi
    else
        echo -e "${CYAN}${BOLD}Install NVIDIA proprietary drivers?${NC} [Y/n]"
        read -r answer
        case "$answer" in
            [nN]*) ;;
            *) do_nvidia=true ;;
        esac
    fi

    if [ "$do_nvidia" = true ]; then
        ensure_rpmfusion
        if [ "$IS_ATOMIC" = true ]; then
            info "Installing NVIDIA drivers via rpm-ostree (akmod-nvidia + CUDA + VA-API)..."
            rpm-ostree install --idempotent --allow-inactive -y \
                akmod-nvidia xorg-x11-drv-nvidia-cuda nvidia-vaapi-driver libva-utils \
                || warning "NVIDIA driver layering failed."
            info "NVIDIA drivers layered. A reboot is required to build the kernel module."
        else
            info "Installing NVIDIA drivers (akmod-nvidia + CUDA + VA-API)..."
            sudo dnf install -y akmod-nvidia || warning "Failed to install akmod-nvidia."
            sudo dnf install -y xorg-x11-drv-nvidia-cuda || warning "Failed to install nvidia-cuda."
            sudo dnf install -y nvidia-vaapi-driver libva-utils || warning "Failed to install VA-API drivers."
            info "NVIDIA drivers installed. A reboot is required to build the kernel module."
        fi
    fi
}

# ─── Reset app grid ─────────────────────────────────────────────────────────────
# Remove all app-grid folders and custom page layout so every app appears in a
# single flat, alphabetically sorted grid.
reset_app_grid() {
    info "Resetting app grid to flat alphabetical layout..."

    # Clear custom page layout → GNOME falls back to auto-sorted alphabetical
    # Must use reset (not set to empty) so GNOME auto-populates with all installed apps
    gsettings reset org.gnome.shell app-picker-layout 2>/dev/null || true
    dconf reset /org/gnome/shell/app-picker-layout 2>/dev/null || true

    # Remove all app folders and their definitions
    gsettings set org.gnome.desktop.app-folders folder-children '@as []' 2>/dev/null || true
    dconf reset -f /org/gnome/desktop/app-folders/folders/ 2>/dev/null || true

    # Disable the folders feature entirely
    dconf write /org/gnome/desktop/app-folders/folder-children '@as []' 2>/dev/null || true

    info "App grid reset - all apps will appear in a single alphabetical view."
}

# ─── Final system cleanup & update ──────────────────────────────────────────────
final_cleanup() {
    info "Running final system cleanup & update..."

    # ── Atomic / immutable Fedora ──────────────────────────────────────────────
    if [ "$IS_ATOMIC" = true ]; then
        info "Upgrading base image (rpm-ostree)..."
        rpm-ostree upgrade || warning "rpm-ostree upgrade encountered an error."

        info "Cleaning up rpm-ostree..."
        rpm-ostree cleanup -m 2>/dev/null || true

    # ── DNF-based systems ───────────────────────────────────────────────────────
    elif command -v dnf &>/dev/null; then
        # Refresh metadata and upgrade all packages
        info "Upgrading packages (with refreshed metadata)..."
        sudo dnf upgrade --refresh -y || warning "dnf upgrade encountered an error."

        # Remove unused dependencies
        info "Removing unused dependencies..."
        sudo dnf autoremove -y || warning "dnf autoremove encountered an error."

        # Remove old kernels / installonly packages (keep latest 2)
        local old_kernels
        old_kernels=$(dnf repoquery --installonly --latest-limit=-2 -q 2>/dev/null) || true
        if [ -n "$old_kernels" ]; then
            info "Removing old kernels..."
            sudo dnf remove -y $old_kernels || warning "Could not remove old kernels."
        fi

        # Clean package cache
        info "Cleaning DNF cache..."
        sudo dnf clean all || warning "dnf clean encountered an error."

    elif command -v apt-get &>/dev/null; then
        info "Upgrading packages..."
        sudo apt-get update -y && sudo apt-get upgrade -y || warning "apt upgrade encountered an error."
        info "Removing unused dependencies..."
        sudo apt-get autoremove -y || warning "apt autoremove encountered an error."
        sudo apt-get clean || true

    elif command -v pacman &>/dev/null; then
        info "Upgrading packages..."
        sudo pacman -Syu --noconfirm || warning "pacman update encountered an error."

        # Remove orphaned packages
        local orphans
        orphans=$(pacman -Qdtq 2>/dev/null) || true
        if [ -n "$orphans" ]; then
            info "Removing orphaned packages..."
            sudo pacman -Rns --noconfirm $orphans || warning "Could not remove orphans."
        fi

        # Clean package cache (keep latest 2 versions)
        if command -v paccache &>/dev/null; then
            info "Cleaning pacman cache..."
            sudo paccache -rk2 2>/dev/null || true
        fi
    fi

    # ── Flatpak cleanup ─────────────────────────────────────────────────────────
    if command -v flatpak &>/dev/null; then
        info "Updating Flatpak applications..."
        flatpak update -y || warning "flatpak update encountered an error."

        info "Removing unused Flatpak runtimes..."
        flatpak uninstall --unused -y 2>/dev/null || true

        info "Repairing Flatpak installation..."
        flatpak repair 2>/dev/null || true
    fi

    # ── System-wide cache cleanup ───────────────────────────────────────────────
    info "Trimming systemd journal to 200 MB..."
    sudo journalctl --vacuum-size=200M 2>/dev/null || true

    info "Clearing thumbnail cache..."
    rm -rf ~/.cache/thumbnails/* 2>/dev/null || true

    info "Reloading systemd daemon..."
    sudo systemctl daemon-reload 2>/dev/null || true

    info "System cleanup complete."
}

# ─── Ask to reboot ──────────────────────────────────────────────────────────────
ask_reboot() {
    echo ""
    local do_reboot=false

    if [ "$GUM_AVAILABLE" = true ] && command -v gum &>/dev/null; then
        if gum confirm --default=no "  Reboot now to apply all changes?"; then
            do_reboot=true
        fi
    else
        echo -e "${CYAN}${BOLD}Reboot now to apply all changes?${NC} [y/N]"
        local answer
        read -rp "> " answer
        case "$answer" in
            [yY]*) do_reboot=true ;;
        esac
    fi

    if [ "$do_reboot" = true ]; then
        info "Rebooting..."
        sudo reboot
    else
        info "Skipping reboot. Please reboot manually for all changes to take effect."
        echo ""
    fi
}

main "$@"
