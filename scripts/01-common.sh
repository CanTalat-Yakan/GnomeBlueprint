#!/usr/bin/env bash
# 02Gnome - Common helpers, colors, and package management
# Sourced by install.sh - do not run directly.

# ─── Colors ───────────────────────────────────────────────────────────────────
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
warning() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

GUM_CONFIRM_STYLE_FLAGS=(
    "--selected.foreground="
    "--selected.background=238"
    "--unselected.foreground="
    "--unselected.background="
    "--prompt.foreground="
    "--prompt.background="
)

GUM_CHOOSE_STYLE_FLAGS=(
    "--header.foreground="
    "--header.background="
    "--selected.foreground="
    "--selected.background="
    "--cursor.foreground="
    "--cursor.background="
    "--item.foreground="
    "--item.background="
)

gum_confirm_styled() {
    gum confirm "${GUM_CONFIRM_STYLE_FLAGS[@]}" "$@"
}

gum_choose_styled() {
    gum choose "${GUM_CHOOSE_STYLE_FLAGS[@]}" "$@"
}

# ─── Detect immutable / atomic Fedora (Silverblue, Bazzite, Kinoite, etc.) ────
detect_atomic() {
    if [ -f /run/ostree-booted ] || command -v rpm-ostree &>/dev/null; then
        IS_ATOMIC=true
        info "Detected atomic/immutable Fedora (rpm-ostree)."
        info "Adapting installation accordingly."
    fi
}

# ─── Helpers: install / remove system packages (atomic-aware) ─────────────────
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
        if rpm-ostree status 2>/dev/null | grep -q "LayeredPackages:.*$pkg"; then
            info "Removing layered package: $pkg ($label)..."
            rpm-ostree uninstall -y "$pkg" 2>/dev/null \
                || warning "Could not remove $pkg via rpm-ostree."
        elif rpm -q "$pkg" &>/dev/null 2>&1; then
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

have_flatpak_app() {
    local app="$1"
    command -v flatpak &>/dev/null \
        && flatpak list --app --columns=application 2>/dev/null | grep -qx "$app"
}

have_snap_app() {
    local app="$1"
    command -v snap &>/dev/null && snap list "$app" &>/dev/null
}

have_firefox_install() {
    command -v firefox &>/dev/null \
        || command -v firefox-esr &>/dev/null \
        || have_flatpak_app org.mozilla.firefox \
        || have_snap_app firefox
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
        if ! sudo dnf install -y "$pkg" 2>/dev/null; then
            ensure_rpmfusion
            sudo dnf install -y "$pkg" || warning "Could not install $pkg via dnf."
        fi
    fi
}

# ─── Packages whose removal would break the desktop ──────────────────────────
PROTECTED_RE="gnome-shell|gdm|mutter|gnome-session|gnome-settings-daemon"

safe_dnf_remove() {
    local pkg="$1" label="$2"
    command -v rpm &>/dev/null || return 0
    rpm -q "$pkg" &>/dev/null 2>&1 || return 0

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

safe_pacman_remove() {
    local pkg="$1" label="$2"
    pacman -Qi "$pkg" &>/dev/null 2>&1 || return 0

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

