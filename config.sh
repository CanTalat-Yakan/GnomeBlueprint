#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  02Gnome - User Configuration                                                ║
# ║                                                                              ║
# ║  Edit the arrays below to customise your installation.                       ║
# ║  This file is sourced before anything else - changes take effect on the      ║
# ║  next run of install.sh.                                                     ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ─── Essential Flatpak applications (always installed) ──────────────────────────
ESSENTIAL_APPS=(
    "com.mattjakeman.ExtensionManager"     # Extension Manager - browse & toggle GNOME extensions
    "com.github.tchx84.Flatseal"           # Flatseal - manage Flatpak permissions
    "io.github.fabrialberio.pinapp"        # Pins - create custom app shortcuts
    "dev.qwery.AddWater"                   # Add Water - apply Adwaita theme to Firefox
    "io.github.swordpuffin.rewaita"        # Rewaita - bring color to Adwaita
    "io.missioncenter.MissionCenter"       # Mission Center - system monitor
    "org.pvermeer.WebAppHub"               # Web App Hub - manage web applications
)

# ─── Optional applications (interactive chooser) ───────────────────────────────
# Format: "Label|type:id"   type = flatpak | rpm | script
OPTIONAL_APPS=(
    # Entertainment
    "Steam|rpm:steam"
    "Discord|flatpak:com.discordapp.Discord"
    "Signal|flatpak:org.signal.Signal"
    "VLC|flatpak:org.videolan.VLC"
    # Creative
    "Blender|flatpak:org.blender.Blender"
    "GIMP|flatpak:org.gimp.GIMP"
    "Unity Hub|flatpak:com.unity.UnityHub"
    # Utilities
    "Visual Studio Code|flatpak:com.visualstudio.code"
    "JetBrains Rider|flatpak:com.jetbrains.Rider"
    "GitHub Desktop|flatpak:io.github.shiftey.Desktop"
    "Trayscale (Tailscale GUI)|flatpak:dev.deedles.Trayscale"
    # Developer Tools
    "OpenCode (AI coding agent)|script:opencode"
    # Runtimes
    ".NET SDK & Runtimes|script:dotnet"
)

# ─── GNOME Shell extensions ────────────────────────────────────────────────────
# Format: "uuid|Human-readable name"
GNOME_EXTENSIONS=(
    "appindicatorsupport@rgcjonas.gmail.com|AppIndicator & KStatusNotifierItem Support"
    "arcmenu@arcmenu.com|ArcMenu"
    "clipboard-history@alexsaveau.dev|Clipboard History"
    "dash-to-dock@micxgx.gmail.com|Dash to Dock"
    "gtk4-ding@smedius.gitlab.com|Gtk4 Desktop Icons NG (DING)"
    "just-perfection-desktop@just-perfection|Just Perfection"
    "logomenu@aryan_k|Logo Menu"
    "panel-corners@aunetx|Panel Corners"
    "pip-on-top@rafostar.github.com|PiP on top"
    "quick-settings-audio-panel@rayzeq.github.io|Quick Settings Audio Panel"
    "restartto@tiagoporsch.github.io|Restart To"
    "user-theme@gnome-shell-extensions.gcampax.github.com|User Themes"
    "azwallpaper@azwallpaper.gitlab.com|Wallpaper Slideshow"
)

# Extensions to install but keep disabled by default
GNOME_EXTENSIONS_DISABLED=(
    "rounded-window-corners@fxgn|Rounded Window Corners Reborn"
    "Vitals@CoreCoding.com|Vitals"
)

# ─── GNOME bloatware to remove (when user confirms) ────────────────────────────
# Format: "flatpak-id|dnf-pkg|pacman-pkg|Display Name"
GNOME_BLOAT_APPS=(
    "org.gnome.Boxes|gnome-boxes|gnome-boxes|Boxes"
    "org.gnome.Calendar|gnome-calendar|gnome-calendar|Calendar"
    "org.gnome.Snapshot|snapshot|snapshot|Camera"
    "org.gnome.Characters|gnome-characters|gnome-characters|Characters"
    "org.gnome.clocks|gnome-clocks|gnome-clocks|Clocks"
    "org.gnome.Connections|gnome-connections|gnome-connections|Connections"
    "org.gnome.Contacts|gnome-contacts|gnome-contacts|Contacts"
    "org.gnome.Extensions|gnome-extensions-app|gnome-extensions-app|Extensions"
    "org.gnome.baobab|baobab|baobab|Disk Usage Analyser"
    "org.gnome.SimpleScan|simple-scan|simple-scan|Document Scanner"
    "org.fedoraproject.MediaWriter|mediawriter|-|Fedora Media Writer"
    "org.gnome.Yelp|yelp|yelp|Help"
    "-|libreoffice-calc|libreoffice-still-calc|LibreOffice Calc"
    "-|libreoffice-impress|libreoffice-still-impress|LibreOffice Impress"
    "-|libreoffice-writer|libreoffice-still-writer|LibreOffice Writer"
    "org.gnome.Maps|gnome-maps|gnome-maps|Maps"
    "org.gnome.SystemMonitor|gnome-system-monitor|gnome-system-monitor|System Monitor"
    "org.gnome.Tour|gnome-tour|gnome-tour|Tour"
    "org.gnome.Weather|gnome-weather|gnome-weather|Weather"
)

# ─── Dock pin order for optional apps ──────────────────────────────────────────
# Format: "flatpak-id|rpm-desktop-name(s)"
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

# ─── Docker Compose services (interactive chooser) ─────────────────────────────
# Format: "Label|directory-name"  (must exist under docker/)
DOCKER_SERVICES=(
    "Immich|immich"
    "Ollama + Open WebUI|ollama"
    "ZeroTier One|zerotierone"
)

