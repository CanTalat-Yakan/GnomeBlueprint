#!/usr/bin/env bash
# 02Gnome - GNOME desktop configuration (dconf, profile, preferences, Nautilus, etc.)
# Sourced by install.sh — do not run directly.

# ─── Import GNOME settings via dconf ───────────────────────────────────────────
import_gnome_settings() {
    local profile="$1"
    local dconf_dir="$DOTFILES_DIR/gnome/${profile}"

    if [ ! -d "$dconf_dir" ]; then
        warning "No dconf directory found at $dconf_dir - skipping GNOME settings import."
        return
    fi

    if ! command -v dconf &>/dev/null; then
        warning "dconf not found - skipping GNOME settings import."
        return
    fi

    info "Importing GNOME settings for profile '${profile}'..."

    local count=0
    for dconf_file in "$dconf_dir"/*.dconf; do
        [ -f "$dconf_file" ] || continue
        local fname
        fname=$(basename "$dconf_file")
        info "  Loading ${fname}..."
        sed "s|DOTFILES_DIR|${DOTFILES_DIR}|g" "$dconf_file" | dconf load /
        count=$((count + 1))
    done

    if [ "$count" -eq 0 ]; then
        warning "No .dconf files found in $dconf_dir."
    else
        info "GNOME settings imported successfully ($count file(s) loaded)."
    fi
}

# ─── Profile selection (gum TUI or plain-text fallback) ────────────────────────
select_profile() {
    local profile

    if [ "$GUM_AVAILABLE" = true ] && command -v gum &>/dev/null; then
        profile=$(gum choose \
            --header.foreground="12" --header.italic=false \
            --header "  Select a 02Gnome profile:" \
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

    if [ -z "$profile" ]; then
        warning "No profile selected - defaulting to 'desktop'."
        profile="desktop"
    fi

    echo "$profile"
}

# ─── Run profile-specific setup script ─────────────────────────────────────────
run_profile() {
    local profile="$1"
    local script="$DOTFILES_DIR/gnome/${profile}/setup.sh"

    if [ ! -f "$script" ]; then
        warning "No setup script found at $script - skipping profile setup."
        return
    fi

    info "Running ${profile} profile setup..."
    chmod +x "$script"
    bash "$script"
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
                local gdm_conf=""
                for f in /etc/gdm/custom.conf /etc/gdm3/custom.conf; do
                    if [ -f "$f" ]; then gdm_conf="$f"; break; fi
                done
                if [ -z "$gdm_conf" ]; then
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
                    local cc=""
                    cc=$(awk -v tz="$tz" '$3 == tz { print $1; exit }' /usr/share/zoneinfo/zone.tab 2>/dev/null) || true
                    if [ -z "$cc" ]; then
                        warning "Could not determine country for timezone $tz - skipping."
                    else
                        local region_locale=""
                        region_locale=$(locale -a 2>/dev/null \
                            | grep -i "_${cc}\." \
                            | grep -i 'utf' \
                            | head -1) || true
                        if [ -n "$region_locale" ]; then
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

    gsettings set org.gnome.nautilus.preferences sort-directories-first true 2>/dev/null || true
    gsettings set org.gnome.nautilus.preferences default-folder-viewer 'list-view' 2>/dev/null || true
    gsettings set org.gnome.nautilus.preferences show-create-link true 2>/dev/null || true
    gsettings set org.gnome.nautilus.preferences show-delete-permanently true 2>/dev/null || true
    gsettings set org.gnome.nautilus.list-view use-tree-view true 2>/dev/null || true
    gsettings set org.gnome.nautilus.list-view default-zoom-level 'small' 2>/dev/null || true
    gsettings set org.gtk.gtk4.Settings.FileChooser sort-directories-first true 2>/dev/null || true

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

    [ -f "$tpl_dir/untitled-document.txt" ] \
        || touch "$tpl_dir/untitled-document.txt"

    [ -f "$tpl_dir/untitled-document.md" ] \
        || touch "$tpl_dir/untitled-document.md"

    if [ ! -f "$tpl_dir/untitled-script.sh" ]; then
        echo '#!/usr/bin/env bash' > "$tpl_dir/untitled-script.sh"
        chmod +x "$tpl_dir/untitled-script.sh"
    fi

    if [ ! -f "$tpl_dir/untitled-script.py" ]; then
        echo '#!/usr/bin/env python3' > "$tpl_dir/untitled-script.py"
    fi

    [ -f "$tpl_dir/untitled-class.cs" ] \
        || touch "$tpl_dir/untitled-class.cs"

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
    gsettings set org.gnome.Ptyxis restore-session false 2>/dev/null || true
    gsettings set org.gnome.Ptyxis restore-window-size false 2>/dev/null || true
    gsettings set org.gnome.TextEditor restore-session false 2>/dev/null || true
    info "App defaults configured."
}

# ─── Reset app grid ─────────────────────────────────────────────────────────────
reset_app_grid() {
    info "Resetting app grid to flat alphabetical layout..."
    gsettings reset org.gnome.shell app-picker-layout 2>/dev/null || true
    dconf reset /org/gnome/shell/app-picker-layout 2>/dev/null || true
    gsettings set org.gnome.desktop.app-folders folder-children '@as []' 2>/dev/null || true
    dconf reset -f /org/gnome/desktop/app-folders/folders/ 2>/dev/null || true
    dconf write /org/gnome/desktop/app-folders/folder-children '@as []' 2>/dev/null || true
    info "App grid reset - all apps will appear in a single alphabetical view."
}

# ─── Pin installed optional apps to favorites ──────────────────────────────────
OPTIONAL_PIN_ORDER=(
    "com.valvesoftware.Steam|steam"
    "com.discordapp.Discord|discord"
    "org.signal.Signal|signal-desktop"
    "org.blender.Blender|blender"
    "org.gimp.GIMP|gimp"
    "com.unity.UnityHub|unityhub"
    "com.visualstudio.code|code"
    "com.jetbrains.Rider|jetbrains-rider"
    "io.github.shiftey.Desktop|github-desktop"
)

_resolve_desktop_file() {
    local flatpak_id="$1"
    local rpm_names="$2"

    if flatpak list --app --columns=application 2>/dev/null | grep -qx "$flatpak_id"; then
        echo "${flatpak_id}.desktop"
        return
    fi

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
    local current_favs
    current_favs=$(gsettings get org.gnome.shell favorite-apps 2>/dev/null) || return 0

    local -a tail_apps=(
        "org.gnome.Nautilus.desktop"
        "org.gnome.Ptyxis.desktop"
        "org.gnome.Software.desktop"
    )

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
                current_favs="${current_favs%]*}, '${desktop}']"
                changed=true
                info "Pinned $desktop to favorites."
            fi
        fi
    done

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

    local current
    current=$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings 2>/dev/null) || return 0

    local path="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/"

    if echo "$current" | grep -q "custom2"; then
        info "Custom keybinding slot custom2 already in use - skipping."
        return
    fi

    current="${current%]*}, '${path}']"
    gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$current" 2>/dev/null || true

    dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/name "'OpenCode'" 2>/dev/null || true
    dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/command "'ptyxis -e opencode'" 2>/dev/null || true
    dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/binding "'<Super>c'" 2>/dev/null || true

    info "OpenCode shortcut registered: Super+C"
}

