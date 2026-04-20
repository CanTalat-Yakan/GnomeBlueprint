#!/usr/bin/env bash
# 02Gnome - GNOME Shell extensions installer
# Sourced by install.sh - do not run directly.


# ─── Patch extension metadata.json with current GNOME Shell version ─────────────
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

    local shell_version
    shell_version=$(gnome-shell --version 2>/dev/null | grep -oP '\d+' | head -1) || true
    if [ -z "$shell_version" ]; then
        warning "Could not detect GNOME Shell version - skipping $name."
        return
    fi

    local info_url="https://extensions.gnome.org/extension-info/?uuid=${uuid}&shell_version=${shell_version}"
    local info_json
    info_json=$(curl -fsSL "$info_url" 2>/dev/null) || {
        warning "Could not fetch metadata for $name - skipping."
        return
    }

    local download_url
    download_url=$(echo "$info_json" \
        | python3 -c "import sys,json; print(json.load(sys.stdin)['download_url'])" 2>/dev/null) || {
        warning "Extension $name may not support GNOME Shell $shell_version - skipping."
        return
    }

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

    patch_extension_metadata "$uuid"

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

