#!/usr/bin/env bash
# GnomeBlueprint - Laptop profile setup
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This script is invoked automatically by install.sh when the "Laptop" profile
# is selected.  It applies GNOME settings optimised for battery life and mobile
# use.

set -euo pipefail

info() { echo -e "\033[0;32m[INFO]\033[0m  $*"; }

info "Applying Laptop profile settings..."

# ─── Laptop-specific GNOME tweaks ──────────────────────────────────────────────
if command -v gsettings &>/dev/null; then
    info "Applying laptop GNOME settings..."

    # Enable automatic brightness via ambient light sensor
    gsettings set org.gnome.settings-daemon.plugins.power ambient-enabled true \
        2>/dev/null || true

    # Suspend when lid is closed (on battery and on AC)
    gsettings set org.gnome.settings-daemon.plugins.power lid-close-battery-action 'suspend' \
        2>/dev/null || true
    gsettings set org.gnome.settings-daemon.plugins.power lid-close-ac-action 'suspend' \
        2>/dev/null || true

    # Enable tap-to-click on the touchpad
    gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click true \
        2>/dev/null || true

    # Enable natural (reverse) scrolling on the touchpad
    gsettings set org.gnome.desktop.peripherals.touchpad natural-scroll true \
        2>/dev/null || true

    # Dim the screen after 5 minutes of inactivity to save battery
    gsettings set org.gnome.settings-daemon.plugins.power idle-dim true \
        2>/dev/null || true
    gsettings set org.gnome.desktop.session idle-delay 300 \
        2>/dev/null || true

    # Just Perfection - panel at the top, clock centered (laptop default)
    gsettings set org.gnome.shell.extensions.just-perfection panel-position 0 \
        2>/dev/null || true
    gsettings set org.gnome.shell.extensions.just-perfection clock-menu-position 1 \
        2>/dev/null || true
fi

info "Laptop profile setup complete."
