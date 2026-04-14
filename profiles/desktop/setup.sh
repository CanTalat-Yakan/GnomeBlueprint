#!/usr/bin/env bash
# GnomeBlueprint — Desktop profile setup
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This script is invoked automatically by install.sh when the "Desktop" profile
# is selected.  It installs desktop-specific Flatpak applications and applies
# GNOME settings suited for a desktop (non-portable) machine.

set -euo pipefail

info() { echo -e "\033[0;32m[INFO]\033[0m  $*"; }

info "Applying Desktop profile settings..."

# ─── Desktop-specific Flatpak applications ─────────────────────────────────────
DESKTOP_FLATPAK_APPS=(
    "com.valvesoftware.Steam"    # Steam gaming platform
    "org.kde.kdenlive"           # Video editor
    "org.blender.Blender"        # 3-D modelling & animation
    "org.gimp.GIMP"              # Image editor
)

info "Installing desktop-specific Flatpak applications..."
for app in "${DESKTOP_FLATPAK_APPS[@]}"; do
    if flatpak list --app --columns=application 2>/dev/null | grep -qx "$app"; then
        info "$app is already installed."
    else
        info "Installing $app..."
        flatpak install -y flathub "$app" \
            || echo -e "\033[1;33m[WARN]\033[0m  Failed to install $app — skipping."
    fi
done

# ─── Desktop-specific GNOME tweaks ─────────────────────────────────────────────
if command -v gsettings &>/dev/null; then
    info "Applying desktop GNOME settings..."

    # Disable automatic brightness adjustment (no ambient light sensor on desktops)
    gsettings set org.gnome.settings-daemon.plugins.power ambient-enabled false \
        2>/dev/null || true

    # Disable tap-to-click (no touchpad on a typical desktop)
    gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click false \
        2>/dev/null || true

    # Power button triggers the interactive shutdown dialog
    gsettings set org.gnome.settings-daemon.plugins.power power-button-action 'interactive' \
        2>/dev/null || true

    # Keep the display on while the machine is idle (desktops usually stay on)
    gsettings set org.gnome.desktop.session idle-delay 0 \
        2>/dev/null || true
fi

info "Desktop profile setup complete."
