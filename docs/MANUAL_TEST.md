# Manual test checklist

These checks cover what unit tests cannot: the live menu bar, permissions and
synthetic events. Run them on a real Mac after building the app. Mark each item
PASS or FAIL with the date and the macOS version. Every FAIL becomes a task in the
next plan block.

Build and run:

```bash
bash scripts/dev_cert.sh   # once: a local signing identity, so grants survive rebuilds
make run                   # builds, signs, quits the old copy and launches
```

Launch the app only through `make run`: a copy built elsewhere (for example by Xcode's
Run button) has another signature and looks ungranted. See `docs/XCODE_SETUP.md`.

The separator is two status items: the pipe (a thin vertical line) and the arrow right of
it. Everything left of the pipe is what the arrow hides.

## 1. Permissions and onboarding

| # | Check | Expected | Result |
|---|---|---|---|
| 1.1 | First launch with no permissions | Onboarding lists only Accessibility; its button opens the Accessibility pane. No Screen Recording prompt appears | |
| 1.2 | Grant Accessibility only, switch back to the app | Onboarding closes without a restart; the strip shows app names, its rows are clickable | |
| 1.3 | Grant Screen Recording only | Onboarding still lists Accessibility; strip rows are not clickable; nothing is moved | |
| 1.4 | No permissions at all | Hiding with the arrow still works; nothing is moved or clicked | |
| 1.5 | Revoke Screen Recording while running | The strip falls back to app names; no crash | |

## 2. Collapse and expand

| # | Check | Expected | Result |
|---|---|---|---|
| 2.1 | Click the arrow | Icons left of the pipe are pushed off-screen; the arrow stays visible and now points left. Click again and they come back; the arrow points right | |
| 2.2 | Collapse, then `kill -9` the app, then relaunch | All icons are visible again after relaunch | |
| 2.3 | Collapse, then quit normally | All icons are visible after quit | |
| 2.4 | Clock and Control Center | Never moved or hidden | |
| 2.5 | Hold Command and drag the arrow to the left of the pipe, then click the arrow | The icons stay shown and a message says the arrow would be hidden with them; nothing is hidden. Drag the arrow back to the right of the pipe: the click collapses | |
| 2.6 | Hold Command and drag an icon from the right of the pipe to its left while collapsed, then expand | The icon goes off-screen with the others and comes back on expand | |
| 2.7 | Hold Command and drag an icon from the left of the pipe to its right | The icon stays visible while collapsed | |

## 3. Menu and help

| # | Check | Expected | Result |
|---|---|---|---|
| 3.1 | Right-click the pipe, then the arrow | The same menu opens under each | |
| 3.2 | Control-click and middle-click the arrow | The same menu opens; a plain left click collapses or expands and opens no menu | |
| 3.3 | Open the menu without Screen Recording | Items: "Show Icon Images…", "How to Use Hidebar…", a separator, "Quit Hidebar". "Show Icon Images…" shows the system prompt and opens the Screen Recording pane | |
| 3.4 | Open the menu with Screen Recording granted | No "Show Icon Images…" item | |
| 3.5 | Choose "How to Use Hidebar…" | The app comes to the front and a window explains the arrow, the pipe, Command-drag, the menu, the overflow strip and the permissions; OK closes it | |
| 3.6 | Choose "Quit Hidebar" while collapsed | The app quits and all icons are visible | |
| 3.7 | Collapse, then open the menu from the arrow | The menu opens although the pipe is stretched | |

## 4. Discovery and identity (needs Accessibility)

| # | Check | Expected | Result |
|---|---|---|---|
| 4.1 | Names of the strip rows (`AXTitle`, then `AXDescription`) | Names are stable across relaunches; record apps with empty names | |
| 4.2 | Collapse, then fill the bar until icons overflow | Icons pushed off-screen by the pipe are still read (their windows may report `onscreen=false`) and are not shown in the strip | |
| 4.3 | A frozen or busy app with a menu bar icon | Discovery does not hang the app (AX messaging timeout is 0.3 s per app); user input is never blocked and no step of a click starts after 10 seconds in total. Switching apps (which refreshes the overflow strip) does not freeze the menu bar while the frozen app is read | |
| 4.4 | Collapse, then immediately click an icon in the strip | Positions are read after the bar has re-laid out: the reveal waits until the pipe's frame is the same in two reads 25 ms apart, for about 1 second. Record the usual wait and any case where an icon was read at a stale position | |

## 5. Overflow strip

| # | Check | Expected | Result |
|---|---|---|---|
| 5.1 | On a Mac with a notch, add icons until some fall behind the notch | Those icons appear in the strip under the bar | |
| 5.2 | Open an app with long menus (Xcode) | Icons covered by the menus appear in the strip | |
| 5.3 | Scroll the strip with a mouse wheel, Shift+wheel and a trackpad | It scrolls horizontally with all three; tune `pointsPerWheelLine` (20) if it feels off | |
| 5.4 | Toggle natural scrolling | The strip follows the system direction | |
| 5.5 | Click an icon in the strip, including the one right next to the pipe | Its menu opens; the icon returns afterwards. The icon next to the pipe is dragged over its next neighbour (or clicked in place when it has none), so the click does not fail with a reveal error | |
| 5.6 | Click an icon whose click opens no menu | The icon is restored within about 10 seconds | |
| 5.7 | Keep an icon's menu open longer than 10 seconds | The icon stays where it is while any menu is open (an open menu window is detected on the pop-up menu layer); about 10 seconds after the menu closes it goes back, and the menu is never closed under you. A menu kept open (or a foreign window stuck on the menu layer) postpones the return for at most 120 seconds in all; after that the icon goes back regardless | |
| 5.8 | Click an icon in the strip while collapsed | The icon's menu opens; afterwards the icon goes back and the section is hidden again | |
| 5.9 | Click a strip row without Accessibility | The row is not clickable; nothing is moved | |
| 5.10 | While a click is running, type and move the mouse | Input is never blocked; the cursor is put back where it was when the click ends | |

## 6. Platforms

| # | Check | Expected | Result |
|---|---|---|---|
| 6.1 | macOS 26 | All sections above | |
| 6.2 | macOS 15 (minimum target) | Sections 1–5 | |
| 6.3 | Two displays | Only the main display's menu bar items are listed and moved | |
| 6.4 | A second display arranged to the LEFT of the main one, top edges aligned | Known limitation: its copies of the icons look like hidden items; they stay unmanaged (never clicked) but may show as non-clickable duplicates in the overflow strip | |
