#!/usr/bin/env bash
# 02Gnome - Cleanup, bloat removal, NVIDIA drivers, wallpapers, reboot
# Sourced by install.sh - do not run directly.

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

        local slideshow_dir="$WALLPAPER_DIR/m-26.jp"
        if [ -d "$slideshow_dir" ]; then
            dconf write /org/gnome/shell/extensions/azwallpaper/slideshow-directory "'$slideshow_dir'" 2>/dev/null || true

            local ext_schema_dir="$HOME/.local/share/gnome-shell/extensions/azwallpaper@azwallpaper.gitlab.com/schemas"
            if [ -d "$ext_schema_dir" ]; then
                GSETTINGS_SCHEMA_DIR="$ext_schema_dir" gsettings set org.gnome.shell.extensions.azwallpaper slideshow-directory "$slideshow_dir" 2>/dev/null || true
            fi
            info "Wallpaper Slideshow set to $slideshow_dir"
        fi
    fi
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

        if [ "$flatpak_id" != "-" ]; then
            if flatpak list --app --columns=application 2>/dev/null | grep -qx "$flatpak_id"; then
                info "Removing Flatpak: $label..."
                flatpak uninstall -y "$flatpak_id" 2>/dev/null \
                    || warning "Failed to remove Flatpak $label."
            fi
        fi

        if [ "$dnf_pkg" != "-" ]; then
            if [ "$IS_ATOMIC" = true ]; then
                pkg_remove "$dnf_pkg" "$label"
            elif command -v dnf &>/dev/null; then
                safe_dnf_remove "$dnf_pkg" "$label"
            fi
        elif [ "$pacman_pkg" != "-" ] && command -v pacman &>/dev/null; then
            safe_pacman_remove "$pacman_pkg" "$label"
        fi
    done

    info "Bloat removal complete."
}

# ─── NVIDIA driver installation ──────────────────────────────────────────────
install_nvidia_drivers() {
    if ! lspci | grep -qi 'nvidia'; then
        return
    fi

    info "NVIDIA GPU detected: $(lspci | grep -i 'nvidia' | head -1 | sed 's/.*: //')"

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

# ─── Final system cleanup & update ──────────────────────────────────────────────
final_cleanup() {
    info "Running final system cleanup & update..."

    if [ "$IS_ATOMIC" = true ]; then
        info "Upgrading base image (rpm-ostree)..."
        rpm-ostree upgrade || warning "rpm-ostree upgrade encountered an error."
        info "Cleaning up rpm-ostree..."
        rpm-ostree cleanup -m 2>/dev/null || true

    elif command -v dnf &>/dev/null; then
        info "Upgrading packages (with refreshed metadata)..."
        sudo dnf upgrade --refresh -y || warning "dnf upgrade encountered an error."
        info "Removing unused dependencies..."
        sudo dnf autoremove -y || warning "dnf autoremove encountered an error."

        local old_kernels
        old_kernels=$(dnf repoquery --installonly --latest-limit=-2 -q 2>/dev/null) || true
        if [ -n "$old_kernels" ]; then
            info "Removing old kernels..."
            sudo dnf remove -y $old_kernels || warning "Could not remove old kernels."
        fi

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

        local orphans
        orphans=$(pacman -Qdtq 2>/dev/null) || true
        if [ -n "$orphans" ]; then
            info "Removing orphaned packages..."
            sudo pacman -Rns --noconfirm $orphans || warning "Could not remove orphans."
        fi

        if command -v paccache &>/dev/null; then
            info "Cleaning pacman cache..."
            sudo paccache -rk2 2>/dev/null || true
        fi
    fi

    if command -v flatpak &>/dev/null; then
        info "Updating Flatpak applications..."
        flatpak update -y --noninteractive || warning "flatpak update encountered an error."
        info "Removing unused Flatpak runtimes..."
        flatpak uninstall --unused -y 2>/dev/null || true
        info "Repairing Flatpak installation..."
        flatpak repair 2>/dev/null || true
    fi

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

