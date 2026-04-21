#!/usr/bin/env bash
# 02Gnome - Theme setup (Adwaita, Rewaita, OLED, Add Water, Firefox)
# Sourced by install.sh - do not run directly.

# ─── Adwaita theme setup (adw-gtk3 + Flatpak overrides) ────────────────────────
setup_themes() {
    info "Setting up Adwaita themes..."

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

    gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true

    flatpak override --user --filesystem=xdg-config/gtk-4.0 2>/dev/null || true
    flatpak override --user --filesystem=xdg-config/gtk-3.0 2>/dev/null || true

    info "Themes applied."
    info "Open Rewaita to browse and apply Adwaita icon theme variants."
}

# ─── Install Rewaita custom themes ─────────────────────────────────────────────
REWAITA_DATA_DIR="$HOME/.var/app/io.github.swordpuffin.rewaita/data"

install_rewaita_themes() {
    info "Installing Rewaita custom themes..."

    local dark_dir="$REWAITA_DATA_DIR/dark"
    local light_dir="$REWAITA_DATA_DIR/light"
    mkdir -p "$dark_dir" "$light_dir"

    local src="$DOTFILES_DIR"
    cp -f "$src/assets/themes/dark/A Default Dark Theme.css"  "$dark_dir/"  2>/dev/null || warning "Could not copy default dark theme."
    cp -f "$src/assets/themes/dark/A Pure Dark Theme.css"     "$dark_dir/"  2>/dev/null || warning "Could not copy Oled dark theme."
    cp -f "$src/assets/themes/light/A Default Light Theme.css" "$light_dir/" 2>/dev/null || warning "Could not copy default light theme."

    info "Theme files installed into Rewaita data directory."

    local prefs_file="$REWAITA_DATA_DIR/prefs.json"
    python3 -c "
import json, os

path = '$prefs_file'
try:
    with open(path) as f:
        prefs = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    prefs = {}

prefs.setdefault('window-controls', 'default')
prefs.setdefault('modify-gtk3-theme', True)
prefs.setdefault('modify-gnome-shell', True)
prefs.setdefault('run-in-background', True)
prefs.setdefault('transparency', False)
prefs.setdefault('window', False)
prefs.setdefault('sharp', False)
prefs.setdefault('light-text', False)

prefs['dark-theme']  = 'A Default Dark Theme.css'
prefs['light-theme'] = 'A Default Light Theme.css'

with open(path, 'w') as f:
    json.dump(prefs, f, indent=4)
" 2>/dev/null || warning "Could not write Rewaita prefs.json."

    info "Rewaita configured with default dark and light themes."
}

# ─── Ask Oled / pure-black preference ──────────────────────────────────────────
ask_oled_preference() {
    echo ""

    if [ "$GUM_AVAILABLE" = true ] && command -v gum &>/dev/null; then
        if gum_confirm_styled --default=no "  Use pure-black Oled dark theme?"; then
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

        gsettings set org.gnome.TextEditor style-scheme 'Adwaita-dark' 2>/dev/null || true

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

    local prefs_file="$REWAITA_DATA_DIR/prefs.json"
    python3 -c "
import json
path = '$prefs_file'
try:
    with open(path) as f:
        prefs = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    prefs = {}
prefs['dark-theme'] = 'A Pure Dark Theme.css'
with open(path, 'w') as f:
    json.dump(prefs, f, indent=4)
" 2>/dev/null || warning "Could not update Rewaita prefs for Oled."
    info "Rewaita dark theme set to Oled variant."

    if command -v flatpak &>/dev/null; then
        flatpak run --command=gsettings dev.qwery.AddWater set dev.qwery.AddWater.Firefox oled-black true 2>/dev/null \
            || warning "Could not set Add Water oled-black (run Add Water once first)."
        info "Add Water True Black enabled for Firefox."
    else
        warning "flatpak not available - skipping Add Water True Black."
    fi

    gsettings set org.gnome.TextEditor style-scheme 'classic-dark' 2>/dev/null || true
    info "Text Editor set to Classic Dark."

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

    gsettings set org.gnome.Ptyxis interface-style 'dark' 2>/dev/null || true

    info "Oled / pure-black settings applied."
}

# ─── Configure Add Water (Adwaita theme for Firefox) ───────────────────────────
configure_addwater() {
    info "Configuring Add Water for Firefox..."

    if command -v flatpak &>/dev/null; then
        flatpak run --command=gsettings dev.qwery.AddWater set dev.qwery.AddWater.Firefox theme-enabled true 2>/dev/null || true
        flatpak run --command=gsettings dev.qwery.AddWater set dev.qwery.AddWater.Firefox hide-single-tab true 2>/dev/null || true
        flatpak run --command=gsettings dev.qwery.AddWater set dev.qwery.AddWater.Firefox normal-width-tabs true 2>/dev/null || true
        flatpak run --command=gsettings dev.qwery.AddWater set dev.qwery.AddWater.background-update true 2>/dev/null || true
        info "Add Water preferences set."
        info "Open Add Water once to apply the theme to Firefox."
    else
        warning "flatpak not available - skipping Add Water configuration."
    fi
}

# ─── Resolve Firefox repo asset paths ──────────────────────────────────────────
_resolve_firefox_repo_file() {
    local rel_path="$1"
    local candidate

    for candidate in \
        "$DOTFILES_DIR/firefox/$rel_path" \
        "$DOTFILES_DIR/firefox-profile/$rel_path"
    do
        if [ -f "$candidate" ]; then
            echo "$candidate"
            return 0
        fi
    done

    return 1
}

_has_firefox_profiles() {
    local root
    for root in "$@"; do
        [ -f "$root/profiles.ini" ] && return 0
        [ -d "$root" ] || continue
        if find "$root" -maxdepth 2 -name 'prefs.js' -type f -print -quit 2>/dev/null | grep -q .; then
            return 0
        fi
    done

    return 1
}

_stop_firefox_processes() {
    pkill -x firefox 2>/dev/null || true
    pkill -x firefox-esr 2>/dev/null || true
    pkill -f '/app/lib/firefox/firefox' 2>/dev/null || true
    pkill -f 'org.mozilla.firefox' 2>/dev/null || true
    pkill -f 'snap/firefox' 2>/dev/null || true
}

_start_firefox_headless_for_profile_init() {
    if command -v firefox &>/dev/null; then
        firefox --headless &>/dev/null &
        return 0
    fi

    if command -v firefox-esr &>/dev/null; then
        firefox-esr --headless &>/dev/null &
        return 0
    fi

    if have_flatpak_app org.mozilla.firefox; then
        (flatpak run --command=firefox org.mozilla.firefox --headless \
            || flatpak run org.mozilla.firefox --headless) &>/dev/null &
        return 0
    fi

    if have_snap_app firefox; then
        snap run firefox --headless &>/dev/null &
        return 0
    fi

    return 1
}

# ─── Configure Firefox preferences ─────────────────────────────────────────────
configure_firefox() {
    info "Configuring Firefox preferences..."

    local src_user_js
    src_user_js=$(_resolve_firefox_repo_file "user.js") || true
    if [ ! -f "$src_user_js" ]; then
        warning "No user.js found in repo - skipping Firefox configuration."
        return
    fi

    local profile_dirs=()
    local search_roots=(
        "$HOME/.mozilla/firefox"
        "$HOME/.config/mozilla/firefox"
        "$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox"
        "$HOME/.var/app/org.mozilla.firefox/config/mozilla/firefox"
        "$HOME/snap/firefox/common/.mozilla/firefox"
    )

    local needs_init=true
    if _has_firefox_profiles "${search_roots[@]}"; then
        needs_init=false
    fi

    if [ "$needs_init" = true ]; then
        info "Launching Firefox briefly to create profile directories..."
        _stop_firefox_processes
        sleep 1

        if _start_firefox_headless_for_profile_init; then
            local waited=0
            while [ "$waited" -lt 15 ]; do
                sleep 1
                if _has_firefox_profiles "${search_roots[@]}"; then
                    break
                fi
                waited=$((waited + 1))
            done
        else
            warning "Firefox executable not found on PATH and no Flatpak/Snap Firefox install was detected."
        fi

        _stop_firefox_processes
        sleep 1

        if _has_firefox_profiles "${search_roots[@]}"; then
            info "Firefox profile directories created."
        else
            warning "Firefox profile directories were not detected after launch attempt."
            warning "Launch Firefox once manually, close it, then re-run the installer to configure it."
        fi
    else
        if pgrep -x firefox &>/dev/null || pgrep -x firefox-esr &>/dev/null; then
            info "Closing Firefox to apply toolbar and preference changes..."
            _stop_firefox_processes
            sleep 3
        fi
    fi

    for root in "${search_roots[@]}"; do
        [ -d "$root" ] || continue

        if [ -f "$root/profiles.ini" ]; then
            while IFS= read -r line || [ -n "$line" ]; do
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

        local found_prefs
        found_prefs=$(find "$root" -maxdepth 2 -name 'prefs.js' -type f 2>/dev/null) || true
        if [ -n "$found_prefs" ]; then
            while IFS= read -r pjs; do
                [ -n "$pjs" ] && profile_dirs+=("$(dirname "$pjs")")
            done <<< "$found_prefs"
        fi
    done

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
        cp -f "$src_user_js" "$target"

        if [ "$USE_OLED" = true ]; then
            sed -i 's/user_pref("gnomeTheme.oledBlack", false);/user_pref("gnomeTheme.oledBlack", true);/' "$target"
            sed -i 's/user_pref("browser.display.background_color", "#2b2b2b");/user_pref("browser.display.background_color", "#000000");/' "$target"
        fi

        info "Configured Firefox profile: $(basename "$profile")"

        if [ -f "$profile/places.sqlite" ] && command -v sqlite3 &>/dev/null; then
            sqlite3 "$profile/places.sqlite" "DELETE FROM moz_bookmarks;" 2>/dev/null || true
            info "Cleared bookmarks for profile: $(basename "$profile")"
        fi
    done

    info "Firefox preferences applied (takes effect on next Firefox launch)."

    local src_policies
    src_policies=$(_resolve_firefox_repo_file "policies.json") || true
    if [ -f "$src_policies" ]; then
        info "Deploying Firefox enterprise policies (search engine, toolbar)..."

        local firefox_dirs=(
            "/usr/lib/firefox"
            "/usr/lib64/firefox"
            "/usr/share/firefox"
            "/usr/lib/firefox-esr"
            "/opt/firefox"
            "/snap/firefox/current/usr/lib/firefox"
            "/var/lib/flatpak/app/org.mozilla.firefox/current/active/files/lib/firefox"
        )

        local found_any=false
        for fdir in "${firefox_dirs[@]}"; do
            if [ -d "$fdir" ]; then
                local dist_dir="$fdir/distribution"
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

        local snap_dist="$HOME/snap/firefox/common/.mozilla/firefox/distribution"
        if [ -d "$HOME/snap/firefox" ]; then
            mkdir -p "$snap_dist" 2>/dev/null
            cp -f "$src_policies" "$snap_dist/policies.json" 2>/dev/null && {
                info "Installed policies.json → $snap_dist/"
                found_any=true
            }
        fi

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
            info "Firefox policies deployed (takes effect on next Firefox launch)."
        fi
    fi
}

