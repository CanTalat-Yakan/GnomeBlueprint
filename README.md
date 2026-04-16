<h1 align="center" style="text-align:center">GnomeBlueprint</h1>
<h4 align="center" style="text-align:center">Automate your perfect GNOME desktop in one command.</h4>
<p align="center" style="text-align:center">Extensions, themes, apps, and settings - all configured interactively.</p>
<p align="center" style="text-align:center"><strong>10 min Fedora install + 10 min GnomeBlueprint = fully configured desktop in 20 minutes.</strong></p>

<p align="center" style="text-align:center">
  <img alt="Platform" src="https://img.shields.io/badge/Platform-Linux-FCC624">
  <img alt="Desktop" src="https://img.shields.io/badge/Desktop-GNOME-4A86CF">
  <img alt="Shell" src="https://img.shields.io/badge/Shell-Bash-4EAA25">
  <img alt="TUI" src="https://img.shields.io/badge/TUI-gum-FF75B5">
  <a href="LICENSE"><img alt="License: GPL v3" src="https://img.shields.io/badge/License-GPLv3-blue.svg"></a>
  <a href="https://deepwiki.com/CanTalat-Yakan/GnomeBlueprint"><img alt="Ask DeepWiki" src="https://deepwiki.com/badge.svg"></a>
</p>

## Quick Installation

```bash
curl -fsSL https://bit.ly/gnomeblueprint | bash
```

![gnomeblueprint.png](.github/assets/gnomeblueprint.png)

<!-- TOC -->

- [Quick Installation](#quick-installation)
- [What the Installer Does](#what-the-installer-does)
- [Essential Applications](#essential-applications-always-installed)
- [GNOME Shell Extensions](#gnome-shell-extensions-always-installed)
- [Optional Applications](#optional-applications-interactive-chooser)
- [Desktop Profile](#desktop-profile)
- [Laptop Profile](#laptop-profile)
- [Theming](#theming)
- [Bloat Removal](#bloat-removal)
- [Project Structure](#project-structure)
- [Customisation](#customisation)
- [License](#license)

## What the installer does

| Step | Description |
|------|-------------|
| 1 | Installs **gum** for a nice TUI experience |
| 2 | Runs **system update** (`dnf update` + `flatpak update`) |
| 3 | Asks you to pick a profile: **Desktop** or **Laptop** |
| 4 | Installs **git**, **Docker**, **Tailscale**, and sets up **Flatpak + Flathub** |
| 5 | Imports **profile-specific dconf settings** and runs the profile setup script |
| 6 | Installs **essential Flatpak apps** and **GNOME Shell extensions** |
| 7 | Sets up **Adwaita themes** and asks for **Oled (pure-black) preference** |
| 8 | Configures **Firefox** (injects `user.js` for privacy, disables AI, sets up GNOME theme) |
| 9 | Lets you toggle **user preferences** (24h clock, auto-login, regional formats, etc.) |
| 10 | Configures **Nautilus, Terminal, and Text Editor** defaults |
| 11 | Optionally downloads a **wallpaper collection** |
| 12 | Optionally **removes GNOME bloat** (Boxes, Characters, Weather, LibreOffice, etc.) |
| 13 | Lets you pick **optional apps** (Discord, Steam, VS Code, OpenCode, etc.) |
| 14 | Lets you pick **Docker Compose services** (ZeroTier, Ollama + Open WebUI, Immich) |
| 15 | **Pins installed apps** to the dock (Firefox first, Files/Terminal/Software last) |
| 16 | **Resets the app grid** to a single flat alphabetical layout |
| 17 | Detects **NVIDIA GPU** and installs proprietary drivers (`akmod-nvidia`, CUDA, VA-API) |

## Essential Applications (always installed)

| Application | Flatpak ID | Description |
|---|---|---|
| Firefox | `firefox` (system package) | Web browser |
| Flatseal | `com.github.tchx84.Flatseal` | Manage Flatpak permissions |
| Extension Manager | `com.mattjakeman.ExtensionManager` | Browse & toggle GNOME extensions |
| Pins | `io.github.fabrialberio.pinapp` | Create custom app shortcuts |
| Add Water | `dev.qwery.AddWater` | Apply Adwaita theme to Firefox |
| Rewaita | `io.github.swordpuffin.rewaita` | Bring color to Adwaita |
| Mission Center | `io.missioncenter.MissionCenter` | System resource monitor |
| GNOME Tweaks | `gnome-tweaks` (system package) | Advanced GNOME settings |

## GNOME Shell Extensions (always installed)

| Extension | UUID |
|---|---|
| AppIndicator & KStatusNotifierItem | `appindicatorsupport@rgcjonas.gmail.com` |
| ArcMenu | `arcmenu@arcmenu.com` |
| Clipboard History | `clipboard-history@alexsaveau.dev` |
| Dash to Dock | `dash-to-dock@micxgx.gmail.com` |
| Gtk4 Desktop Icons NG (DING) | `gtk4-ding@smedius.gitlab.com` |
| Just Perfection | `just-perfection-desktop@just-perfection` |
| Logo Menu | `logomenu@aryan_k` |
| Panel Corners | `panel-corners@aunetx` |
| PiP on top | `pip-on-top@rafostar.github.com` |
| Quick Settings Audio Panel | `quick-settings-audio-panel@rayzeq.github.io` |
| Restart To | `restartto@tiagoporsch.github.io` |
| Rounded Window Corners Reborn | `rounded-window-corners@fxgn` | *Disabled — not yet compatible with GNOME 50* |
| User Themes | `user-theme@gnome-shell-extensions.gcampax.github.com` |
| Wallpaper Slideshow | `azwallpaper@azwallpaper.gitlab.com` |

> Extensions that don't list the current GNOME Shell version are **automatically patched** via `metadata.json` so they load without waiting for an upstream update.

## Optional Applications (interactive chooser)

Pick any combination from the TUI menu:

| Category | Application | Source |
|---|---|---|
| Entertainment | Steam | RPM (via RPM Fusion) |
| Entertainment | Discord, Signal, VLC | Flatpak |
| Creative | Blender, GIMP, Unity Hub | Flatpak |
| Utilities | VS Code, JetBrains Rider, GitHub Desktop, Trayscale | Flatpak |
| Developer | OpenCode (AI coding agent) | Script |
| Runtimes | .NET SDK & Runtimes (LTS + STS) | Script |

Installed optional apps are automatically **pinned to the dock**.

## Docker Compose Services (interactive chooser)

Pick any combination from the TUI menu — selected services are copied to your home directory and started automatically:

| Service | Directory | Address | Description |
|---|---|---|---|
| ZeroTier One | `~/zerotierone` | Host network (see [my.zerotier.com](https://my.zerotier.com)) | Peer-to-peer VPN mesh network |
| Ollama + Open WebUI | `~/ollama` | http://localhost:3000 | Local LLM inference with web chat UI |
| Immich | `~/immich` | http://localhost:2283 | Self-hosted photo & video management |

Each directory contains a `docker-compose.yml` and a `README.md` with usage instructions.

**Common commands** (run from the service directory):

```bash
docker compose up -d      # Start (detached)
docker compose down        # Stop
docker compose pull        # Update to latest version
docker compose up -d      # Restart with new images
```

## Desktop Profile

- Panel at **bottom**, clock on the **right**
- Dynamic workspaces
- Blank screen: never / no idle dim
- No touchpad natural scroll / tap-to-click
- `Super+D` show desktop, `Super+E` files, `Super+T` terminal, `Super+Space` ArcMenu runner

## Laptop Profile

- Panel at **top** (default), clock in the **center**
- Dynamic workspaces
- Battery percentage shown, ambient brightness enabled
- Lid close → suspend (resumes instantly on open)
- Tap-to-click, natural scroll, two-finger scrolling
- Same keyboard shortcuts as Desktop

## Theming

### Desktop

- Panel at the **bottom** with clock on the **right**

![screenshot-desktop.png](.github/assets/screenshot-desktop.png)

### Laptop

- Panel at the **top** (default) with clock in the **center**

![screenshot-laptop.png](.github/assets/screenshot-laptop.png)

- **adw-gtk3-dark** installed via dnf - makes GTK3 apps match GTK4 Adwaita
- Flatpak overrides applied for `gtk-4.0` and `gtk-3.0` theme access
- Custom **Rewaita** themes included (`themes/dark` and `themes/light`)
- Prompts for an **Oled** preference to apply pure-black styling to Rewaita, Firefox, Terminal, and Text Editor
- Automatically configures **Add Water** and injects `user.js` to theme and lock down Firefox (disabling AI/bloat)

## Bloat Removal

When confirmed, the installer removes these pre-installed apps (Flatpak + RPM with safety check):

> Boxes · Characters · Connections · Contacts · Extensions · Disk Usage Analyser · Document Scanner · Fedora Media Writer · Help · LibreOffice Calc/Impress/Writer · Maps · Parental Controls · System Monitor · Tour · Weather

RPM removal runs a **dry-run first** - if removing a package would cascade into `gnome-shell`, `gdm`, or `mutter`, it is safely skipped.

## Project Structure

```
GnomeBlueprint/
├── install.sh                  # Root installer (curl | bash)
├── docker/
│   ├── zerotierone/
│   │   ├── docker-compose.yml  # ZeroTier One container
│   │   └── README.md
│   ├── ollama/
│   │   ├── docker-compose.yml  # Ollama + Open WebUI containers
│   │   └── README.md
│   └── immich/
│       ├── docker-compose.yml  # Immich photo management stack
│       ├── .env                # Immich configuration
│       └── README.md
├── firefox-profile/
│   └── user.js                 # Privacy, theming, and UI settings for Firefox
├── gnome-settings/
│   ├── desktop.dconf           # dconf settings for desktop profile
│   └── laptop.dconf            # dconf settings for laptop profile
├── profiles/
│   ├── desktop/
│   │   └── setup.sh            # Desktop-specific setup script
│   └── laptop/
│       └── setup.sh            # Laptop-specific setup script
├── themes/
│   ├── dark/                   # Default and Oled pure-black CSS themes
│   └── light/                  # Default light CSS theme
├── LICENSE                     # GNU GPL v3.0
└── README.md
```

## Customisation

### Adding optional apps

Edit the `OPTIONAL_APPS` array in `install.sh`. Format: `"Display Label|type:identifier"` where type is `flatpak` or `script`.

### Adding essential Flatpaks

Edit the `ESSENTIAL_FLATPAK_APPS` array in `install.sh`.

### Adding GNOME extensions

Edit the `GNOME_EXTENSIONS` array in `install.sh`. Format: `"uuid|Human-readable name"`.

### Updating GNOME settings

Export your current settings and overwrite the relevant file:

```bash
dconf dump / > ~/.dotfiles/gnome-settings/desktop.dconf
dconf dump / > ~/.dotfiles/gnome-settings/laptop.dconf
```

Then commit and push so future installs pick them up.

## License

This project is licensed under the **GNU General Public License v3.0 or later** - see the [LICENSE](LICENSE) file for details.
