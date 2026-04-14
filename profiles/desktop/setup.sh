#!/usr/bin/env bash
# GnomeBlueprint - Desktop profile setup
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This script is invoked automatically by install.sh when the "Desktop" profile
# is selected.  It applies GNOME settings suited for a desktop (non-portable)
# machine.

set -euo pipefail

info() { echo -e "\033[0;32m[INFO]\033[0m  $*"; }

info "Applying Desktop profile settings..."


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

    # Just Perfection - panel at the bottom, clock on the right (desktop layout)
    gsettings set org.gnome.shell.extensions.just-perfection panel-position 1 \
        2>/dev/null || true
    gsettings set org.gnome.shell.extensions.just-perfection clock-menu-position 2 \
        2>/dev/null || true
fi

info "Desktop profile setup complete."
