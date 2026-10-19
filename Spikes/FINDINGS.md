# MoveSpike — findings (macOS 26)

Throwaway spike, not part of HidebarKit. Build: `swift build --package-path Spikes/MoveSpike`.
Commands: `list`, `check-perms`, `snapshot <windowID> <out.png>`, `drag <windowID> <deltaX> [--step-ms N] [--steps N] [--tap hid|session|pid] [--force]`.

Status of the first run: Accessibility = false, Screen Recording = false. `snapshot` and `drag` have not been run yet.

## 1. Discovery

`list` returned 31 windows. Sample rows (window names are empty without Screen Recording):

```
id=155363 pid=407 owner="Window Server" name="Menubar" x=0 w=1728 layer=24 onscreen=true cgs=true
id=21 pid=629 bundle=com.apple.controlcenter x=1566 w=46 layer=25 onscreen=true cgs=true
id=19 pid=629 bundle=com.apple.controlcenter x=1612 w=118 layer=25 onscreen=true cgs=true
```

- **Owner.** On macOS 26 every status item window is owned by Control Center (one pid), so `ownerName` cannot identify the app. Ice handles this (PRs #903, #911) with the real owner from XPC `sourcePID` or from AX `AXExtrasMenuBar`. The AX path is in `AXOwners.swift` (`axOwner=` column) and is not verified yet: it needs Accessibility.
- **CGS.** The private `CGSGetProcessMenuBarWindowList` still works on 26. It returns the same windows plus the `Menubar` window (layer 24).
- **Duplicates.** Most items have a twin with identical bounds and `onscreen=false` (ids around 1540xx). Use the `onscreen=true` one. Some windows are 0x0, so skip them.
- **Unmovable / unhidable** (keyed by bundle id + title, as Ice does). Unmovable: `controlcenter/Clock`, `controlcenter/BentoBox`, `systemuiserver/Siri`. Movable but not hidable: `AudioVideoModule`, `FaceTime`, `MusicRecognition`. The two rightmost windows (x=1566 w=46, x=1612 w=118) look like Control Center and the clock by geometry. This is not verified.
- **Other OS versions.** `CGWindowListCreateImage` returns nil on 26.5, so ScreenCaptureKit is required (Ice PR #982). On macOS 27 menu bar item windows are not exposed at all, only AX (Ice PR #995).

## 2. Snapshot

Needs Screen Recording. It uses SCK `desktopIndependentWindow` and falls back to a display capture with `sourceRect`. SCK cannot capture off-screen items.
Run after granting: `swift run --package-path Spikes/MoveSpike MoveSpike snapshot <windowID> /tmp/icon.png`

## 3. Drag

Needs Accessibility. Use a third-party icon. `drag` refuses Control Center-owned windows without a third-party AX owner unless `--force` is given. It makes one attempt with no retries, then polls bounds for up to 500 ms and restores the cursor.

```
swift run --package-path Spikes/MoveSpike MoveSpike drag <windowID> -80 --step-ms 20
```

Output: before/after/dx and `RESULT: MOVED|NOT MOVED`.

| windowID | deltaX | step-ms | steps | tap | x before | x after | RESULT |
|---|---|---|---|---|---|---|---|
| | | | | | | | |

Ice moves differently for comparison. It sends no intermediate `mouseDragged`: `leftMouseDown` with ⌘ at (20000, 20000), then `leftMouseUp` at the edge of the target icon. Events go via `postToPid` and an event tap, then it waits up to 50 ms for the frame to change, with up to 5 attempts.

## 4. Timings

Candidates (`--step-ms` / `--steps`): A 50/1 (closest to Ice), B 20/10, C 10/10, D 5/10, E 40/20. Pass criterion: MOVED 10 out of 10. If none moves, try `--tap session`, then `--tap pid`.

## Open

- After granting both permissions, re-run `list`. It shows whether `name` is filled and whether `axOwner` resolves. This decides how `MenuBarItemID` is built (plan items 1.3 and 1.6).
