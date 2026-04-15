# GnomeBlueprint

> Automate your perfect GNOME desktop - extensions, themes, apps, and settings - in one command.

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

---

## ⚡ One-liner Installation

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/CanTalat-Yakan/GnomeBlueprint/main/install.sh)
```

The interactive installer walks you through every step using [gum](https://github.com/charmbracelet/gum) (with a plain-text fallback).

---

## 🔄 What the installer does

| Step | Description |
|------|-------------|
| 1 | Installs **gum** for a nice TUI experience |
| 2 | Runs **system update** (`dnf update` + `flatpak update`) |
| 3 | Asks you to pick a profile: **Desktop** or **Laptop** |
| 4 | Installs **git**, clones the repo to `~/.dotfiles`, sets up **Flatpak + Flathub** |
| 5 | Installs **essential Flatpak apps** and **GNOME Shell extensions** |
| 6 | Sets up **Adwaita themes** (`adw-gtk3` + Flatpak overrides) |
| 7 | Lets you toggle **user preferences** (24h clock, auto-login, blank screen, screen lock, battery) |
| 8 | Configures **Nautilus** (list view, sort folders first, tree view, starred folders) |
| 9 | Optionally downloads a **wallpaper collection** |
| 10 | Optionally **removes GNOME bloat** (Boxes, Characters, Weather, LibreOffice, etc.) |
| 11 | Lets you pick **optional apps** to install (Spotify, Discord, Steam, VS Code, etc.) |
| 12 | Imports **profile-specific dconf settings** and runs the profile setup script |
| 13 | **Pins installed optional apps** to the dock favorites |

---

## 📦 Essential Applications (always installed)

| Application | Flatpak ID | Description |
|---|---|---|
| Flatseal | `com.github.tchx84.Flatseal` | Manage Flatpak permissions |
| Extension Manager | `com.mattjakeman.ExtensionManager` | Browse & toggle GNOME extensions |
| Pins | `io.github.fabrialberio.pinapp` | Create custom app shortcuts |
| Add Water | `dev.qwery.AddWater` | Apply Adwaita theme to Firefox |
| Rewaita | `io.github.swordpuffin.rewaita` | Bring color to Adwaita icons |
| Mission Center | `io.missioncenter.MissionCenter` | System resource monitor |

---

## 🧩 GNOME Shell Extensions (always installed)

| Extension | UUID |
|---|---|
| AppIndicator & KStatusNotifierItem | `appindicatorsupport@rgcjonas.gmail.com` |
| ArcMenu | `arcmenu@arcmenu.com` |
| Clipboard History | `clipboard-history@alexsaveau.dev` |
| Dash to Dock | `dash-to-dock@micxgx.gmail.com` |
| Just Perfection | `just-perfection-desktop@just-perfection` |
| Panel Corners | `panel-corners@aunetx` |
| User Themes | `user-theme@gnome-shell-extensions.gcampax.github.com` |
| Wallpaper Slideshow | `azwallpaper@azwallpaper.gitlab.com` |

> Extensions that don't list the current GNOME Shell version are **automatically patched** via `metadata.json` so they load without waiting for an upstream update.

---

## 🎛️ Optional Applications (interactive chooser)

Pick any combination from the TUI menu:

| Category | Application | Source |
|---|---|---|
| Entertainment | Spotify, Discord, Signal, Steam, VLC | Flatpak |
| Creative | Blender, GIMP, Unity Hub | Flatpak |
| Utilities | VS Code, JetBrains Rider, GitHub Desktop, Trayscale | Flatpak |
| Runtimes | .NET SDK & Runtimes (LTS + STS) | Script |

Installed optional apps are automatically **pinned to the dock**.

---

## 🖥️ Desktop Profile

- Panel at **bottom**, clock on the **right**
- Dynamic workspaces
- Blank screen: never / no idle dim
- No touchpad natural scroll / tap-to-click
- `Super+D` show desktop, `Super+E` files, `Super+T` terminal, `Super+Space` ArcMenu runner

---

## 💻 Laptop Profile

- Panel at **top** (default), clock in the **center**
- Dynamic workspaces
- Battery percentage shown, ambient brightness enabled
- Lid close → suspend (resumes instantly on open)
- Tap-to-click, natural scroll, two-finger scrolling
- Same keyboard shortcuts as Desktop

---

## 🎨 Theming

- **adw-gtk3-dark** installed via dnf - makes GTK3 apps match GTK4 Adwaita
- Flatpak overrides applied for `gtk-4.0` and `gtk-3.0` theme access
- Open **Add Water** after setup to apply Adwaita theme to Firefox
- Open **Rewaita** to browse and apply icon theme variants

---

## 🗑️ Bloat Removal

When confirmed, the installer removes these pre-installed apps (Flatpak + RPM with safety check):

> Boxes · Characters · Connections · Contacts · Extensions · Disks · Disk Usage Analyser · Document Scanner · Fedora Media Writer · Help · LibreOffice Calc/Impress/Writer · Maps · Parental Controls · System Monitor · Tour · Weather

RPM removal runs a **dry-run first** - if removing a package would cascade into `gnome-shell`, `gdm`, or `mutter`, it is safely skipped.

---

## 🗂️ Project Structure

```
GnomeBlueprint/
├── install.sh                  # Root installer (curl | bash)
├── gnome-settings/
│   ├── desktop.dconf           # dconf settings for desktop profile
│   └── laptop.dconf            # dconf settings for laptop profile
├── profiles/
│   ├── desktop/
│   │   └── setup.sh            # Desktop-specific setup script
│   └── laptop/
│       └── setup.sh            # Laptop-specific setup script
├── LICENSE                     # GNU GPL v3.0
└── README.md
```

---

## 🔧 Customisation

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

---

## 📄 License

This project is licensed under the **GNU General Public License v3.0 or later** - see the [LICENSE](LICENSE) file for details.
