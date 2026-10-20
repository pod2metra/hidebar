# Releasing Hidebar

A release is a git tag. Running the *Release* workflow with a version bump creates the tag, and
pushing `vMAJOR.MINOR.PATCH` by hand also runs `.github/workflows/release.yml`,
which builds the app, signs it with a Developer ID certificate, notarizes and staples the
app and then the DMG, publishes the DMG as a GitHub Release, and updates the Homebrew cask in the tap repository.
The site in `site/` is deployed separately by `.github/workflows/pages.yml`.

## One-time setup

### Repositories

- `pod2metra/hidebar` - this repository (Releases and Pages).
- `pod2metra/homebrew-tap` - the tap. Create it empty; the workflow adds
  `Casks/hidebar.rb`. Put the text of `packaging/README-tap.md` in its `README.md`.

### Pages

In the repository: *Settings -> Pages -> Build and deployment -> Source: GitHub Actions*.
Without this the `pages.yml` deploy step fails.

### Secrets

Add these under *Settings -> Secrets and variables -> Actions -> Repository secrets*.
The release workflow reads them only through step-level `env:`; nothing is printed.

| Secret | What it is |
|---|---|
| `DEVELOPER_ID_P12` | Base64 of the exported Developer ID Application certificate with its private key |
| `DEVELOPER_ID_P12_PASSWORD` | The password chosen when exporting that `.p12` |
| `APPLE_TEAM_ID` | The 10-character Team ID of the Apple Developer account |
| `NOTARY_KEY_ID` | Key ID of the App Store Connect API key |
| `NOTARY_ISSUER_ID` | Issuer ID shown on the App Store Connect keys page |
| `NOTARY_KEY_P8` | The full text of the downloaded `AuthKey_<KEY_ID>.p8` file |
| `TAP_TOKEN` | Fine-grained personal access token that can push to the tap |

#### `DEVELOPER_ID_P12`, `DEVELOPER_ID_P12_PASSWORD`

1. In the Apple Developer portal create a *Developer ID Application* certificate and
   install it into the login keychain (Keychain Access -> Certificate Assistant ->
   Request a Certificate from a Certificate Authority, then upload the request).
2. In Keychain Access, *My Certificates*, select the *Developer ID Application: ...*
   certificate (the one with the private key under it) and choose *File -> Export Items...*
   with the `.p12` format. Set a strong password; that is `DEVELOPER_ID_P12_PASSWORD`.
3. Encode and copy it, then delete the file:

   ```bash
   base64 -i DeveloperID.p12 | pbcopy
   rm DeveloperID.p12
   ```

   Paste the clipboard as `DEVELOPER_ID_P12`.

#### `APPLE_TEAM_ID`

Apple Developer portal -> *Membership details* -> *Team ID*. The workflow only accepts a
signing identity that belongs to this team.

#### `NOTARY_KEY_ID`, `NOTARY_ISSUER_ID`, `NOTARY_KEY_P8`

1. App Store Connect -> *Users and Access -> Integrations -> App Store Connect API* ->
   *Team Keys* -> add a key with the *Developer* role.
2. The key ID is in the keys table; the issuer ID is shown above it.
3. Download `AuthKey_<KEY_ID>.p8` (Apple lets you download it once). Paste its whole
   content, including the `BEGIN`/`END` lines, as `NOTARY_KEY_P8`.

#### `TAP_TOKEN`

GitHub -> *Settings -> Developer settings -> Personal access tokens -> Fine-grained tokens*:

- Resource owner: the account that owns the tap.
- Repository access: *Only select repositories* -> `pod2metra/homebrew-tap`.
- Permissions: *Contents: Read and write* (nothing else).
- Set an expiry and note it; an expired token makes the last release step fail.

## Cutting a release

The version comes only from the tag; `project.pbxproj` is never edited.

1. Make sure CI has finished green on the `main` commit you want to release.
2. Open *Actions -> Release -> Run workflow*, keep the branch `main`, and pick `bump`
   (`patch`, `minor` or `major`); leave `tag` empty. The `tag` job:
   - refuses to run from any branch other than `main`;
   - requires a successful CI push run on that exact commit;
   - refuses if the commit already carries a `v*` tag;
   - creates the annotated tag `vX.Y.Z` with `scripts/next_version.sh` (the highest existing
     `vMAJOR.MINOR.PATCH` tag plus the bump; `0.0.0` when there is none) and pushes it.

   The tag is created inside the same run because a tag pushed with the workflow token does
   not start the tag-triggered run. The `release` job follows in that run. Bump runs share
   one concurrency group, so two button presses cannot race for the same tag.

   Alternative: tag and push by hand. This path does not check CI, so check it yourself.

   ```bash
   git tag v0.2.0
   git push origin v0.2.0
   ```

3. Watch the *Release* run. The `release` job then:
   - builds with `MARKETING_VERSION=0.2.0` and `CURRENT_PROJECT_VERSION=<run number>`, and
     with `ASSETCATALOG_COMPILER_APPICON_NAME=AppIcon` so the app icon from
     `App/Assets.xcassets` is included even while the project file does not set it;
   - signs the app (hardened runtime, secure timestamp), notarizes it (zipped with `ditto`),
     staples the ticket to `Hidebar.app` and checks it with `spctl -t exec`; the app then
     launches offline without a Gatekeeper lookup;
   - builds the DMG from the stapled app, signs it, notarizes and staples it, and checks it
     with `spctl -t open --context context:primary-signature`;
   - creates the GitHub Release `v0.2.0` with `Hidebar-0.2.0.dmg` and notes made from
     the commit subjects since the previous `v*` tag (`scripts/release_notes.sh`);
   - writes `Casks/hidebar.rb` (version and SHA-256) to the tap and pushes it.

To re-run for an existing tag, use *Actions -> Release -> Run workflow*, leave `bump` as
`none` and enter the tag. Give exactly one of `bump` and `tag`; the run fails otherwise.
If the GitHub Release already exists, the DMG is replaced and the cask is refreshed
with the new checksum.

Users then install with:

```bash
brew install --cask pod2metra/tap/hidebar
```

## Trying the release build locally

```bash
SIGN_IDENTITY="Developer ID Application: <NAME> (<TEAM_ID>)" \
VERSION=0.2.0 BUILD_NUMBER=1 bash scripts/package.sh release-app
```

This signs `build/dd/Build/Products/Release/Hidebar.app`. To go on, export
`NOTARY_KEY_ID`, `NOTARY_ISSUER_ID` and `NOTARY_KEY_P8` (the key file's text) and run, in order:

```bash
bash scripts/notarize.sh build/dd/Build/Products/Release/Hidebar.app
SIGN_IDENTITY=... VERSION=0.2.0 bash scripts/package.sh release-dmg
bash scripts/notarize.sh build/Hidebar-0.2.0.dmg
```

`release-dmg` refuses an app without a stapled ticket. Without arguments,
`bash scripts/package.sh` makes the ad-hoc `build/Hidebar.dmg` for local use.

## Notes

- Accessibility and Screen Recording grants are tied to the code signature. Because every
  release is signed with the same Developer ID, users keep their grants across updates.
- The Release run builds the DMG with Xcode 27.0 and fails unless `xcodebuild -version`
  reports exactly `XCODE_VERSION` and `XCODE_BUILD` from `release.yml`. That is a version and
  build pin, not a beta detector: before raising it, confirm from the runner image notes that
  the new Xcode is a GA release. `XCODE_BUILD` must be filled in with the GA build before the
  first release. The CI `build-app` job uses the same toolchain; keep its `DEVELOPER_DIR` in
  sync with `release.yml` (the other CI jobs run on 27.1).
- If the run fails at "Update Homebrew tap" (for example, an expired `TAP_TOKEN`), the
  release already holds a DMG the cask does not know. Fix the cause and start *Run workflow*
  with that `tag` (not "Re-run all jobs": for a tag the bump created, the `tag` job would fail
  on "already tagged"): it rebuilds and replaces the DMG, then writes the new checksum to
  the cask. Until then `brew install` fails its checksum check.
