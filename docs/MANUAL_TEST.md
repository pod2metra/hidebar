# Manual test checklist

These checks cover what unit tests cannot: the live menu bar, permissions and
synthetic events. Run them on a real Mac after building the app. Mark each item
PASS or FAIL with the date and the macOS version. Every FAIL becomes a task in the
next plan block.

Build and run:

```bash
xcodebuild -project Hidebar.xcodeproj -scheme Hidebar -configuration Debug \
  -derivedDataPath build/dd build
open build/dd/Build/Products/Debug/Hidebar.app
```

With ad-hoc signing, macOS forgets the permissions after every rebuild. Set a
development team first (see `docs/XCODE_SETUP.md`), or re-grant after each build.

## 1. Permissions and onboarding

| # | Check | Expected | Result |
|---|---|---|---|
| 1.1 | First launch with no permissions | Onboarding lists Accessibility and Screen Recording; the buttons open the right System Settings panes | |
| 1.2 | Grant Accessibility only, switch back to the app | Onboarding updates without a restart; groups show app names, rows are clickable | |
| 1.3 | Grant Screen Recording only | Rows show app names and are not clickable; nothing is moved | |
| 1.4 | No permissions at all | Hiding with the separator still works; nothing is moved | |
| 1.5 | Revoke Screen Recording while running | Panels fall back to app names; no crash | |

## 2. Hiding

| # | Check | Expected | Result |
|---|---|---|---|
| 2.1 | Click the separator chevron | Icons left of it are pushed off-screen; click again and they come back | |
| 2.2 | Hide, then `kill -9` the app, then relaunch | All icons are visible again after relaunch | |
| 2.3 | Hide, then quit normally | All icons are visible after quit | |
| 2.4 | Clock and Control Center | Never moved or hidden | |

## 3. Discovery and identity (needs Accessibility)

| # | Check | Expected | Result |
|---|---|---|---|
| 3.1 | Open Settings | Every third-party icon is listed with its app name | |
| 3.2 | Which AX attribute names an item (`AXTitle`, then `AXDescription`) | Names are stable across relaunches; record apps with empty names | |
| 3.3 | Hide icons with the separator, then open Settings | Hidden icons are still listed (their windows may report `onscreen=false`) | |
| 3.4 | A frozen or busy app with a menu bar icon | Discovery does not hang the app (AX messaging timeout is 0.3 s per app); user input is never suppressed for more than 10 seconds in total, even if a move hangs | |
| 3.5 | Hide, then immediately open a group panel or Settings | Positions are read after the bar has re-laid out: the reveal waits until the separator's frame is the same in two reads 25 ms apart, for about 1 second (one extra frame read). Record the usual wait and any case where an icon was read at a stale position | |

## 4. Moving and settings (needs Accessibility)

| # | Check | Expected | Result |
|---|---|---|---|
| 4.1 | Drag an icon from visible to hidden in Settings, press Apply | The real icon moves left of the separator; the cursor returns to where it was | |
| 4.2 | Reorder two visible icons, Apply | The bar matches the new order | |
| 4.3 | Type, press modifiers or move the mouse during Apply | Keyboard and mouse input are ignored until the move ends, then work normally; our own synthetic events still pass | |
| 4.4 | Try to hide a non-hidable item | The drop is disabled | |
| 4.5 | Apply while the separator is hiding | Icons are revealed for the move and hidden again afterwards | |
| 4.6 | Move fails (for example, the app quits mid-move) | Draft is kept, an error names the failed step, nothing is saved | |
| 4.7 | Apply a plan while an app resizes its icon (for example, a clock or a counter that changes width) | If an icon is not on its side of its anchor once the whole plan has run, Apply reports that step as not in place, keeps the draft and saves nothing | |

## 5. Groups (needs Accessibility; snapshots need Screen Recording)

| # | Check | Expected | Result |
|---|---|---|---|
| 5.1 | Create a group with a symbol from the picker | A new status item with that SF Symbol appears to the right of the separator (this also verifies the unconfirmed assumption that a smaller `NSStatusItem Preferred Position` value means closer to the right edge) | |
| 5.1a | Run `swift run --package-path Spikes/MoveSpike MoveSpike list` with the app running | The separator and every group item are listed with distinct titles | |
| 5.2 | Move icons into the group, Apply, click the group icon | A panel drops down with snapshots of the group's icons | |
| 5.3 | Click an icon in the panel | Its own menu opens; after the menu closes the icon goes back into hiding | |
| 5.4 | Click an icon whose click opens no menu | The icon is restored within about 10 seconds | |
| 5.4a | Keep an icon's menu open longer than 10 seconds | The icon stays where it is while any menu is open (an open menu window is detected on the pop-up menu layer); about 10 seconds after the menu closes it goes back, and the menu is never closed under you | |
| 5.5 | Delete a group | Its icons move to hidden; none disappear | |
| 5.6 | Change a group's symbol | The status item updates | |

## 6. Overflow strip

| # | Check | Expected | Result |
|---|---|---|---|
| 6.1 | On a Mac with a notch, add icons until some fall behind the notch | Those icons appear in the strip under the bar | |
| 6.2 | Open an app with long menus (Xcode) | Icons covered by the menus appear in the strip | |
| 6.3 | Scroll the strip with a mouse wheel, Shift+wheel and a trackpad | It scrolls horizontally with all three; tune `pointsPerWheelLine` (20) if it feels off | |
| 6.4 | Toggle natural scrolling | The strip follows the system direction | |
| 6.5 | Click an icon in the strip, including the one right next to the separator | Every strip click goes through the same reveal and return as a panel click. Its menu opens; the icon returns afterwards. The icon next to the separator is dragged over its next neighbour (or clicked in place when it has none), so the click does not fail with a reveal error | |

## 7. Platforms

| # | Check | Expected | Result |
|---|---|---|---|
| 7.1 | macOS 26 | All sections above | |
| 7.2 | macOS 15 (minimum target) | Sections 1–5 | |
