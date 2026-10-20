# Hidebar

Hidebar is a macOS menu-bar utility. It hides menu-bar icons behind a separator,
collects icons into groups, and shows icons that do not fit the bar (behind the
notch or under a long app menu) in a strip below it.

## Features

- **Hide icons.** A separator in the menu bar pushes every icon on its left off the
  screen. Click its chevron to show them again.
- **Groups.** Each group is one icon in the bar, labelled with an SF Symbol from a
  curated catalog (`docs/SYMBOL_CATALOG.md`). Clicking it drops down a panel with the
  group's icons; clicking one there opens that icon's own menu.
- **Settings.** Arrange icons and groups by drag and drop; the real icons are moved
  when you press Apply.
- **Overflow strip.** Icons hidden behind the notch or under the app menus appear in a
  scrollable strip under the menu bar.
- **No network, no telemetry.**

## Screenshots

_Screenshots will be added here._

## Requirements

- macOS 15 (Sequoia) or later
- Xcode with Swift 6.4 to build from source

## Permissions

Hidebar degrades gracefully when a permission is missing.

| Permission | Why | Without it |
|---|---|---|
| Accessibility | Reads which app owns each icon and where it is, and moves icons with synthetic Command-drag events | Hiding with the separator still works; nothing is listed, moved or clicked |
| Screen Recording | Captures the images of hidden icons for the group panel | The panel shows app names instead of images, and its rows are not clickable |

macOS ties both grants to the app's code signature. The app is not sandboxed,
because a sandbox does not allow moving other apps' icons.

## Build from source

```bash
git clone <repository-url>
cd hidebar
xcodebuild -project Hidebar.xcodeproj -scheme Hidebar -configuration Debug \
  -derivedDataPath build/dd build
open build/dd/Build/Products/Debug/Hidebar.app
```

Make a disk image with an ad-hoc signed Release build:

```bash
make package        # writes build/Hidebar.dmg
```

An ad-hoc signed build runs on the machine that built it. To hand it to anyone else it
must be signed with a Developer ID certificate and notarized; the commands are at the end
of `scripts/package.sh`. See `docs/XCODE_SETUP.md` for stable permissions during development.

## Architecture

Logic lives in the local Swift package `HidebarKit/`; the Xcode project only hosts thin
AppKit code.

| Layer | Where | Rule |
|---|---|---|
| `HidebarCore` | `HidebarKit/Sources/HidebarCore` | Pure logic: discovery, move planning, groups, settings, composition. Depends on protocols only, so it is tested without a screen |
| `HidebarSystem` | `HidebarKit/Sources/HidebarSystem` | Adapters to CoreGraphics, Accessibility, ScreenCaptureKit and AppKit. No branching or loops, at most 40 lines per file |
| `App/` | `App/` | AppKit windows and wiring. No logic |

How it works:

- Icons are found through the window list (`CGWindowListCopyWindowInfo`) and the
  Accessibility tree (`AXExtrasMenuBar`), which names the real owner of each icon.
- Hiding gives the separator a huge length, which pushes the icons on its left out of view.
- Moving an icon posts a synthetic Command-drag and verifies the result by reading the
  icon's frame again.
- The icons of a group are captured with ScreenCaptureKit. Clicking one in the panel moves
  the real icon next to the separator, clicks it, and returns it when its menu closes.

## Tests and gates

```bash
make test        # swift test
make coverage    # HidebarCore: 100% lines and functions
make mutation    # Muter mutation score, threshold 85% (brew install muter-mutation-testing/formulae/muter)
make lint        # HidebarSystem adapters: size and no branching
make check       # all of the above
```

Equivalent surviving mutants are listed in `HidebarKit/muter-allowlist.md`. Everything
the unit tests cannot reach (the live menu bar, permissions, synthetic events) is covered
by the checklist in `docs/MANUAL_TEST.md`.

## Known limitations

- Moving icons posts synthetic mouse events. User input is ignored while a move runs, for at
  most 10 seconds in total, and the cursor is put back afterwards.
- The Clock and Control Center items are never moved. A few Control Center modules can be
  moved but not hidden.
- On macOS 26 every icon's window is owned by Control Center, so icons can only be told
  apart through Accessibility. Without it they are shown but never moved or saved.
- A clicked icon returns to its place when its menu closes, or after about 10 seconds. While a
  menu is open the return is postponed, up to 120 seconds in all.
- A busy or frozen app slows icon discovery; Accessibility requests time out after 0.3
  seconds per app. Group panels and the overflow strip read the bar off the main thread, but
  the first read at launch, Settings, and moves still run on it, so a frozen app can stall
  them for a moment.
- Sequoia asks again for Screen Recording from time to time.
- With ad-hoc signing macOS may forget the granted permissions after every rebuild.
- macOS 15 is the minimum target; run the manual checklist on it (`docs/MANUAL_TEST.md`,
  section 7) before relying on it.

## Contributing

Issues and pull requests are welcome. Run `make check` before sending a change. New logic
goes into `HidebarCore` with tests; `HidebarSystem` and `App/` stay free of logic. Do not
edit `Hidebar.xcodeproj/project.pbxproj` by hand (see `docs/XCODE_SETUP.md`).

## License

License: TBD
