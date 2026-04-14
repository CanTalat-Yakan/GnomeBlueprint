# GnomeBlueprint

> A GNOME desktop automation and dotfiles repository - install your perfect GNOME environment in one command.

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

---

## ⚡ One-liner Installation

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/CanTalat-Yakan/GnomeBlueprint/main/install.sh)
```

The script will:

1. Install **git** (if missing) and clone this repository to `~/.dotfiles`.
2. Install and configure **Flatpak** with the Flathub remote.
3. Install a curated set of **common applications** via Flatpak.
4. Install **[gum](https://github.com/charmbracelet/gum)** to display an interactive TUI menu.
5. Prompt you to choose a **Desktop** or **Laptop** profile.
6. Import profile-specific **GNOME settings** via `dconf load`.
7. Run the profile-specific **setup script** to install additional apps and apply tweaks.

---

## 📦 Common Applications (installed for every profile)

| Application | Flatpak ID |
|---|---|
| Visual Studio Code | `com.visualstudio.code` |
| Discord | `com.discordapp.Discord` |
| Firefox | `org.mozilla.firefox` |
| GNOME Extensions | `org.gnome.Extensions` |
| Spotify | `com.spotify.Client` |
| VLC | `org.videolan.VLC` |

---

## 🖥️ Desktop Profile

Additional apps: **Steam**, **Kdenlive**, **Blender**, **GIMP**

GNOME tweaks applied:
- Dark colour scheme
- Ambient brightness disabled (no sensor on most desktops)
- Display stays on while active
- Power button shows the shutdown dialog

---

## 💻 Laptop Profile

Additional apps: **GNOME PowerStats**, **Flatseal**, **GNOME Network Displays**

GNOME tweaks applied:
- Dark colour scheme, battery percentage shown in top bar
- Ambient brightness enabled
- Lid-close suspends the machine
- Tap-to-click & natural scrolling enabled
- Screen dims after 5 minutes of inactivity

---

## 🗂️ Project Structure

```
GnomeBlueprint/
├── install.sh                  # Root installer (curl | bash)
├── profiles/
│   ├── desktop/
│   │   └── setup.sh            # Desktop-specific setup script
│   └── laptop/
│       └── setup.sh            # Laptop-specific setup script
├── gnome-settings/
│   ├── desktop.dconf           # dconf settings for desktop
│   └── laptop.dconf            # dconf settings for laptop
├── LICENSE                     # GNU GPL v3.0
└── README.md
```

---

## 🔧 Customisation

### Adding or removing Flatpak apps

Edit the `FLATPAK_APPS` array in `install.sh` for apps common to all profiles, or the `DESKTOP_FLATPAK_APPS` / `LAPTOP_FLATPAK_APPS` arrays in the respective profile `setup.sh`.

### Updating GNOME settings

Export your current settings and overwrite the relevant file:

```bash
# Desktop
dconf dump / > ~/.dotfiles/gnome-settings/desktop.dconf

# Laptop
dconf dump / > ~/.dotfiles/gnome-settings/laptop.dconf
```

Then commit and push the changes to your fork so future installs pick them up.

---

## 📄 License

This project is licensed under the **GNU General Public License v3.0 or later** - see the [LICENSE](LICENSE) file for details.