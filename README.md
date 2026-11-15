# snry-kde

My Plasma 6 setup, packaged: Hyprland-style workspaces on KWin and a TV/couch mode with its own panel widget.

| Component                               | What it is                                                                                                                                                                                                                            |
| --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Snry Workspaces** (`snry-workspaces`) | KWin script. 5 workspaces per monitor on Plasma 6.7+ per-screen virtual desktops. `Super+1..5` drive monitor 1, `Super+6..0` drive monitor 2, add `Shift` to move the focused window. Focus and the cursor follow the target monitor. |
| **HTPC Mode** (`me.snry.htpc`)          | Plasma widget. Switch between the desktop monitors and the TV, launch Kodi / Steam Big Picture on the TV, and configure outputs, modes and audio devices with pickers. Middle-click toggles.                                          |
| `snry-htpc`                             | The command-line tool behind the widget, also used by KDE Connect, shortcuts and the `HTPC Mode` launcher actions.                                                                                                                    |
| `snry-kde-setup`                        | One-time per-user setup: per-screen desktops, enables the scripts, installs [Krohnkite](https://codeberg.org/anametologin/Krohnkite) for tiling, applies the shortcut layout and a window rule.                                       |

## Requirements

Plasma 6.7 or newer (per-screen virtual desktops), Wayland. Runtime tools: `kscreen-doctor`, `pactl`, `jq`, `kreadconfig6`/`kwriteconfig6`, `notify-send`, `gdbus`, `kpackagetool6`, `flock`. The packages pull these in.

## Install

Grab the package for your distro from the [releases](../../releases) (or the artifacts of the latest CI run).

```sh
# Arch / CachyOS
sudo pacman -U snry-kde-*.pkg.tar.zst

# Fedora
sudo dnf install ./snry-kde-*.noarch.rpm

# anything else, per user, from a source tarball or checkout
make install PREFIX=$HOME/.local
```

Then, as your normal user inside Plasma:

```sh
snry-kde-setup
```

Add the **HTPC Mode** widget to a panel (right-click the panel → Add Widgets…).

Re-running `snry-kde-setup` is safe. Options: `--skip-krohnkite`, `--update-krohnkite`, `--skip-shortcuts`, `--skip-kwin`, `--skip-rules`. It backs up `kwinrc`, `kwinrulesrc` and `kglobalshortcutsrc` to `~/.config/.bak/` first.

## Configure

**Workspaces:** System Settings → Window Management → KWin Scripts → Snry Workspaces → configure. Set monitor 1 / monitor 2 output names, or leave them empty for left-to-right auto-detection. With a single screen, both key sets drive it.

**HTPC:** right-click the widget → Configure. Every field is optional; empty means auto-detect:

- TV = first connected `HDMI-*` output
- monitors = remaining connected outputs, left to right
- modes = keep current
- TV audio = first HDMI sink
- desktop audio = whatever was the default before entering couch mode

The widget writes `~/.config/snry-htpcrc`, which the CLI reads, so KDE Connect and shortcuts use the same settings. Without the widget, edit that file (see `/usr/share/snry-kde/snry-htpcrc.example`) or use:

```sh
snry-htpc list                         # detected outputs, modes, sinks, current config (JSON)
snry-htpc config set TvOutput HDMI-A-1
snry-htpc config dump
```

## Using the HTPC side

```sh
snry-htpc mode couch|desktop|toggle|status
snry-htpc launch kodi|steam    # TV on, start app, back to desktop when it exits
snry-htpc stop                 # stop TV apps (also happens on switching to desktop)
snry-htpc log                  # follow ~/.local/state/snry-htpc/snry-htpc.log
```

The **HTPC Mode** launcher entry has actions (Couch, Desktop, Kodi, Steam, Stop). You can bind them in System Settings → Keyboard → Shortcuts, or find them in KRunner.

For KDE Connect, add run commands such as `snry-htpc mode toggle` or `snry-htpc launch kodi`.

## Shortcuts applied by `snry-kde-setup`

| Keys                              | Action                                 |
| --------------------------------- | -------------------------------------- |
| `Super+1..5` / `Super+6..0`       | Workspace 1–5 on monitor 1 / monitor 2 |
| `Super+Shift+1..0`                | Move the focused window there          |
| `Super+Arrows`                    | Focus (Krohnkite)                      |
| `Super+Shift+Arrows`              | Move window in the layout              |
| `Super+Ctrl+Arrows`               | Resize                                 |
| `Super+Alt+Space`                 | Toggle floating                        |
| `Super+Shift+T` / `Super+Shift+M` | Tile / monocle layout                  |
| `Super+Q` / `Super+Shift+Q`       | Close / kill window                    |
| `Super+F`, `Super+P`              | Fullscreen, keep above                 |
| `Super+D`                         | Application launcher                   |
| `Super+Return`, `Super+T`         | Ghostty, Dolphin                       |

The full list lives in `share/snry-kde/shortcuts.conf`.

## Development

```sh
make check                      # bash -n, shellcheck, node --check, json
make install PREFIX=$HOME/.local
make packages                   # dist/: source tarball, .kwinscript, .plasmoid
```

Reload after editing: `snry-kde-setup --skip-krohnkite --skip-shortcuts --skip-rules`. For the widget, use `plasmawindowed me.snry.htpc` or restart plasmashell.

CI (`.github/workflows/build.yml`) lints, builds the source tarball, `.kwinscript` and `.plasmoid`, an Arch package and a Fedora RPM on every push. It publishes them as a GitHub release when you push a `vX.Y.Z` tag matching `VERSION`.

## License

GPL-3.0-or-later
