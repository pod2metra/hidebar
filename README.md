<div align="center">

<img src="docs/brand/logo.svg" alt="Hidebar logo" width="128" height="128">

# Hidebar

Hide menu-bar icons behind one divider. Open source, for macOS.

[![CI](https://github.com/pod2metra/hidebar/actions/workflows/ci.yml/badge.svg)](https://github.com/pod2metra/hidebar/actions/workflows/ci.yml)
[![Latest release](https://img.shields.io/github/v/release/pod2metra/hidebar)](https://github.com/pod2metra/hidebar/releases/latest)
[![License: MIT](https://img.shields.io/github/license/pod2metra/hidebar)](LICENSE)
![macOS 15+](https://img.shields.io/badge/macOS-15%2B-blue)

[Website](https://pod2metra.github.io/hidebar)

</div>

**Expanded:** everything left of the pipe is visible.

<img src="docs/media/expanded.png" alt="Menu bar with the section expanded" width="782">

**Collapsed:** one click on the arrow hides it.

<img src="docs/media/collapsed.png" alt="Menu bar with the section collapsed" width="782">

## Install

With Homebrew:

```bash
brew install --cask pod2metra/tap/hidebar
```

Or download the DMG from the [latest release](https://github.com/pod2metra/hidebar/releases/latest) and drag Hidebar to Applications.

Hidebar needs macOS 15 (Sequoia) or later.

### First launch

Releases are signed with the project's own certificate and are not notarized by Apple, so macOS blocks the first launch ("Apple could not verify…"). You do this once:

1. Try to open Hidebar, then close the warning.
2. Open System Settings → Privacy & Security and scroll down to Security.
3. Click **Open Anyway** next to Hidebar and confirm.

Right-click → Open no longer bypasses this on macOS 15. The Accessibility permission carries over to updates, because every release is signed with the same certificate. macOS may ask you to choose Open Anyway again after an update. Homebrew installs show the same prompt.

Notarization needs a paid Apple Developer membership, and Hidebar is a free hobby project. The code is open, so you can audit it or build it yourself (see [Build from source](#build-from-source)).

## How to use

Hidebar puts one divider in the menu bar: a pipe (`|`) and an arrow to the right of it.

- **Collapse and expand.** Click the arrow. Everything left of the pipe is hidden; click again to bring it back. Hidebar always starts expanded.
- **Choose what is hidden.** Hold ⌘ and drag an icon (the system's own gesture) to the left of the pipe to hide it, or to the right to keep it visible. Keep the arrow right of the pipe: if it would be hidden along with the icons, Hidebar does not collapse.
- **Menu.** Right-click, Control-click or middle-click the pipe or the arrow for: Open at Login, How to Use Hidebar…, Quit Hidebar. While Accessibility is off the menu also has Reach Icons Behind the Notch….
- **Open at Login.** On its very first launch Hidebar adds itself to your login items, so it starts when you log in. Untick **Open at Login** in the menu, or switch it off in System Settings → General → Login Items; Hidebar never turns it back on. If macOS needs your approval, the item shows a dash, and clicking it opens Login Items settings. It needs no extra permission.
- **Overflow strip.** Icons right of the pipe that do not fit the bar, because they sit under the notch or the app menus, appear in a scrollable strip below the bar, each with its app name and icon. Click one there to click the real icon.
- **Notch indicator.** While some icons are behind the notch or the app menus, a small orange dot sits on the arrow, and its tooltip says how many. With no hidden icons the arrow looks as usual. Seeing which icons are hidden needs no permission; the app menus' width is only known with Accessibility, so without it only the icons under the notch are counted.

## Permissions

Hidebar needs one permission, and only for one feature. It asks for nothing at launch: hiding and showing icons works from the first run. It never refuses to run.

| Permission | Why | Without it |
|---|---|---|
| Accessibility | Tells which app owns each icon and clicks icons from the overflow strip with synthetic ⌘-drag and mouse events. While it is off, Hidebar asks when you click a row of the strip, or when you choose Reach Icons Behind the Notch… in the menu. The request explains why and has an "Open System Settings" button; the grant is picked up when you switch back to the app. | Hiding with the divider still works; the strip and the arrow's dot still show which icons are hidden, but the icons cannot be clicked |

macOS ties the grant to the app's code signature. Hidebar is not sandboxed, because a sandboxed app cannot click other apps' icons.

## Privacy

No telemetry and no network access. Hidebar stores only the positions of its own two menu-bar items and a flag that it has already added itself to login items once. Nothing leaves your Mac. It does not record the screen.

## Known limitations

- Clicking an icon in the strip posts synthetic mouse events. No new step starts after 10 seconds in total, and the cursor is put back afterwards. User input is never blocked.
- The Clock, Control Center and Siri items cannot be moved, so they cannot be clicked from the strip.
- On macOS 26 every icon's window is owned by Control Center, so icons can only be told apart through Accessibility. Without it they are listed but never clicked.
- A clicked icon returns to its place when its menu closes, or after about 10 seconds. While a menu is open the return is postponed, up to 120 seconds in all.
- A busy or frozen app slows icon discovery; Accessibility requests time out after 0.3 seconds per app.
- With ad-hoc signing macOS may forget the granted permission after every rebuild.
- macOS 15 is the minimum target; run check 6.2 of the manual checklist ([docs/MANUAL_TEST.md](docs/MANUAL_TEST.md)) on it before relying on it.

## Build from source

Requires Xcode 27 (Swift 6.4).

```bash
git clone https://github.com/pod2metra/hidebar.git
cd hidebar
make check    # tests, 100% HidebarCore coverage, mutation score, adapter lint
bash scripts/dev_cert.sh   # once: creates the local signing identity make run uses
make run      # Debug build signed with that identity, then launched
```

`make package` builds an ad-hoc signed `build/Hidebar.dmg`. See [docs/XCODE_SETUP.md](docs/XCODE_SETUP.md) for the project layout and for keeping permissions stable between rebuilds, and [docs/MANUAL_TEST.md](docs/MANUAL_TEST.md) for the manual checklist.

## Contributing

Issues and pull requests are welcome. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the layers and the gates. Run `make check` before sending a change. New logic goes into `HidebarKit/Sources/HidebarCore` with tests; `HidebarSystem` and `App/` stay free of logic. Do not edit `Hidebar.xcodeproj/project.pbxproj` by hand.

## License

MIT, see [LICENSE](LICENSE).
