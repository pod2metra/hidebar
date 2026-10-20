# Xcode project setup

`Hidebar.xcodeproj` builds the menu-bar app. All logic lives in the local Swift
package `HidebarKit/`; the Xcode project only hosts thin AppKit code.

## Structure

| Piece | Where | Notes |
|---|---|---|
| App target `Hidebar` | `Hidebar.xcodeproj` | macOS 15.0+, Swift 6 language mode, bundle id `app.hidebar.Hidebar` |
| App sources | `App/` | A synchronized folder (`PBXFileSystemSynchronizedRootGroup`): every file in it is part of the target automatically |
| Entitlements | `App/Hidebar.entitlements` | Empty on purpose: App Sandbox is **off** (moving other apps' menu bar items needs Accessibility and synthetic events, which a sandbox forbids). Excluded from target membership so it is not copied as a resource |
| Info.plist | generated (`GENERATE_INFOPLIST_FILE`) | `LSUIElement = YES` (no Dock icon); set via `INFOPLIST_KEY_LSUIElement` |
| Package | `HidebarKit/` (local package reference) | The app links the `HidebarCore` and `HidebarSystem` products |
| Scheme | `Hidebar.xcodeproj/xcshareddata/xcschemes/Hidebar.xcscheme` | Shared, so `xcodebuild -scheme Hidebar` works from the command line |

Build from the command line:

```bash
xcodebuild -project Hidebar.xcodeproj -scheme Hidebar -configuration Debug build
```

## Rule: do not hand-edit `project.pbxproj`

- To add a source file, drop it into `App/` (or create it from Xcode inside that
  folder). It is picked up automatically; `project.pbxproj` does not change.
- Changes that really need the project file (a new target, a build setting, a new
  package product) are made in Xcode's UI, never by editing `project.pbxproj` as text.
- A diff of `Hidebar.xcodeproj` in a normal feature change should be empty.

## Signing and stable permissions (TCC)

The project signs with `CODE_SIGN_IDENTITY = "-"` (ad-hoc) and no development team,
so it builds and runs on any machine without an Apple account. With ad-hoc signing
Xcode also disables the hardened runtime for the build.

macOS ties Accessibility and Screen Recording grants to the app's code signature.
An ad-hoc signature changes on every build, so the grants can be reset after each
rebuild. Two builds at different paths (for example `build/dd` and Xcode's
DerivedData) also count as different apps.

The simplest fix needs no Apple account: a local self-signed signing certificate.

```bash
bash scripts/dev_cert.sh   # once: creates "Hidebar Local Signing" in the login keychain
make run                   # every time: builds at build/dd, signs, quits the old copy, launches
```

Grant the permissions once after the first `make run`; later rebuilds keep them. Launch
the app only through `make run`, not with Xcode's Run button, which still signs ad-hoc
into DerivedData. If a grant was given to an older build, reset it (below) and grant again.

Alternatively, sign with an Apple development certificate:

1. Open `Hidebar.xcodeproj` in Xcode and select the `Hidebar` target.
2. Open *Signing & Capabilities* and choose your team under *Team*
   (a free personal team is enough).
3. Keep *Automatically manage signing* on. Xcode then signs with your development
   certificate, and the grants survive rebuilds.

Keep this setting local: do not commit a `DEVELOPMENT_TEAM` value. Xcode writes it
into `project.pbxproj`, so discard that change before committing
(`git restore Hidebar.xcodeproj/project.pbxproj`). For command-line builds pass it
per invocation instead: `xcodebuild ... DEVELOPMENT_TEAM=<your team id>`.

If a grant gets stuck, reset it and re-grant on the next launch:

```bash
tccutil reset Accessibility app.hidebar.Hidebar
tccutil reset ScreenCapture app.hidebar.Hidebar
```

Release builds use Developer ID signing, the hardened runtime and notarization;
that is configured at release time, not in this project's defaults.
