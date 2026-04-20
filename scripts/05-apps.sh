#!/usr/bin/env bash
# 02Gnome - Application installers (essential Flatpaks, optional apps, .NET, OpenCode)
# Sourced by install.sh - do not run directly.


install_essential_flatpaks() {
    info "Installing essential Flatpak applications..."
    for app in "${ESSENTIAL_APPS[@]}"; do
        install_one_flatpak "$app"
    done

    # Install Firefox if not already present
    if ! command -v firefox &>/dev/null && ! flatpak list 2>/dev/null | grep -q org.mozilla.firefox; then
        info "Installing Firefox..."
        if [ "$IS_ATOMIC" = true ]; then
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

    # Install GNOME Tweaks
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


# ─── .NET SDK installer ─────────────────────────────────────────────────────────
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

# ─── OpenCode installer ─────────────────────────────────────────────────────────
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

    local labels=()
    for entry in "${OPTIONAL_APPS[@]}"; do
        labels+=("${entry%%|*}")
    done

    local selected=()

    if [ "$GUM_AVAILABLE" = true ] && command -v gum &>/dev/null; then
        local raw
        raw=$(gum_choose_styled --no-limit --height=${#labels[@]} \
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

