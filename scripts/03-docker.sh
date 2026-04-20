#!/usr/bin/env bash
# 02Gnome - Docker, Tailscale, and Docker Compose services
# Sourced by install.sh — do not run directly.

# ─── Install Docker ────────────────────────────────────────────────────────────
install_docker() {
    if command -v docker &>/dev/null; then
        info "Docker is already installed."
        return
    fi

    info "Installing Docker..."

    if [ "$IS_ATOMIC" = true ]; then
        rpm-ostree uninstall -y podman-docker 2>/dev/null || true

        local docker_repo="https://download.docker.com/linux/fedora/docker-ce.repo"
        sudo curl -fsSL "$docker_repo" -o /etc/yum.repos.d/docker-ce.repo 2>/dev/null || {
            warning "Could not add Docker repo - skipping."
            return
        }

        local fedora_ver
        fedora_ver=$(rpm -E %fedora 2>/dev/null) || true
        if [ -n "$fedora_ver" ] && [ -f /etc/yum.repos.d/docker-ce.repo ]; then
            sudo sed -i "s|\$releasever|${fedora_ver}|g" /etc/yum.repos.d/docker-ce.repo 2>/dev/null || true
        fi

        rpm-ostree install --idempotent --allow-inactive -y \
            docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
            || { warning "Docker layering failed - skipping."; return; }

        sudo systemctl enable docker 2>/dev/null || true
        sudo usermod -aG docker "$(whoami)" 2>/dev/null || true
        info "Docker layered via rpm-ostree. A reboot is required to activate."
        return

    elif command -v dnf &>/dev/null; then
        sudo dnf remove -y docker docker-client docker-client-latest \
            docker-common docker-latest docker-latest-logrotate \
            docker-logrotate docker-engine podman-docker 2>/dev/null || true

        local docker_repo="https://download.docker.com/linux/fedora/docker-ce.repo"
        sudo dnf config-manager addrepo --from-repofile="$docker_repo" \
            2>/dev/null || sudo dnf config-manager --add-repo "$docker_repo" \
            2>/dev/null || { warning "Could not add Docker repo - skipping."; return; }

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

    sudo systemctl enable --now docker 2>/dev/null || true
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

                if [ -f "$DOTFILES_DIR/docker/$dir_name/env" ]; then
                    if [ ! -f "$target_dir/.env" ]; then
                        cp "$DOTFILES_DIR/docker/$dir_name/env" "$target_dir/.env"
                        if grep -q 'please-change-me' "$target_dir/.env" 2>/dev/null; then
                            local random_pw
                            random_pw=$(openssl rand -base64 42 | tr -d '\n')
                            sed -i "s|please-change-me|${random_pw}|g" "$target_dir/.env"
                        fi
                    fi
                fi

                if ! lspci | grep -qi 'nvidia'; then
                    sed -i '/deploy:/,/capabilities: \[gpu\]/d' "$target_dir/docker-compose.yml" 2>/dev/null || true
                fi

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

    local icon_dir="$HOME/.local/share/icons/hicolor/256x256/apps"
    mkdir -p "$icon_dir"

    local src_icon=""
    case "$icon_name" in
        immich)    src_icon="$DOTFILES_DIR/assets/icons/immich.png" ;;
        open-webui) src_icon="$DOTFILES_DIR/assets/icons/open-webui-light.png" ;;
        zerotier)  src_icon="$DOTFILES_DIR/assets/icons/zerotier.png" ;;
        tailscale) src_icon="$DOTFILES_DIR/assets/icons/tailscale-light.png" ;;
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

