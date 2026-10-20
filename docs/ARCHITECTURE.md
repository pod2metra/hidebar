# Architecture

Logic lives in the local Swift package `HidebarKit/`; the Xcode project only hosts thin
AppKit code.

| Layer | Where | Rule |
|---|---|---|
| `HidebarCore` | `HidebarKit/Sources/HidebarCore` | Pure logic: discovery, clicking, moving, overflow, composition. Depends on protocols only, so it is tested without a screen |
| `HidebarSystem` | `HidebarKit/Sources/HidebarSystem` | Adapters to CoreGraphics, Accessibility, ScreenCaptureKit and AppKit. No branching or loops, at most 40 lines per file |
| `App/` | `App/` | AppKit windows and wiring. No logic |

`HidebarCore` folders: `StatusBar/` (the separator and its collapse guard), `Discovery/`,
`Moving/`, `Groups/` (clicking an icon from the strip), `Overflow/`, `Geometry/`, `Model/`,
`Permissions/`, `Composition/`, `Support/`.

## How it works

- The divider is two status items: a pipe and an arrow right of it. Their positions are
  kept by `autosaveName`; nothing else is stored, and Hidebar starts expanded every launch.
- Icons are found through the window list (`CGWindowListCopyWindowInfo`) and the
  Accessibility tree (`AXExtrasMenuBar`), which names the real owner of each icon.
- Hiding gives the pipe a huge length (`SeparatorController.hidingLength`), which pushes the
  icons on its left out of view. The length is restored at quit and again at the next
  launch, so a crash cannot leave icons hidden.
- Before hiding, `CollapseGuard` compares the positions of the pipe and the arrow. If the
  arrow is left of the pipe, or either has no frame on the bar, nothing is hidden.
- Icons that do not fit the bar are listed in the overflow strip. Their images are captured
  with ScreenCaptureKit when Screen Recording is granted; otherwise a row shows the app
  name and its icon.
- Clicking a row in the strip moves the real icon next to the pipe with a synthetic
  Command-drag (`Moving/`), verifies the result by reading the icon's frame again, clicks
  it, and returns it when its menu closes (`Groups/ClickProxy`).

## Tests and gates

```bash
make test        # swift test
make coverage    # HidebarCore: 100% lines and functions
make mutation    # Muter mutation score, threshold 85% (brew install muter-mutation-testing/formulae/muter)
make lint        # HidebarSystem adapters: size and no branching
make check       # all of the above
```

Equivalent surviving mutants are listed in
[`HidebarKit/muter-allowlist.md`](../HidebarKit/muter-allowlist.md). Everything the unit
tests cannot reach (the live menu bar, permissions, synthetic events) is covered by the
checklist in [MANUAL_TEST.md](MANUAL_TEST.md). Project setup for Xcode is in
[XCODE_SETUP.md](XCODE_SETUP.md).
