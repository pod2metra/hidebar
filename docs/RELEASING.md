# Releasing Hidebar

A release is a git tag. Running the *Release* workflow with a version bump creates the tag, and
pushing `vMAJOR.MINOR.PATCH` by hand also runs `.github/workflows/release.yml`,
which builds the app, signs it with the project's self-signed release certificate, publishes the
DMG as a GitHub Release, and updates the Homebrew cask in the tap repository.
The site in `site/` is deployed separately by `.github/workflows/pages.yml`.

There is no Apple Developer Program membership behind this: the app is not notarized (it does use
the hardened runtime). The first launch therefore needs one manual step from the user
(*System Settings -> Privacy & Security -> Open Anyway*). Signing every version with the same
certificate keeps the designated requirement identical, so macOS keeps the Accessibility grant
across updates.

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
| `SIGNING_P12` | Base64 of the password-protected `.p12` with the release certificate and its private key |
| `SIGNING_P12_PASSWORD` | The password of that `.p12` |
| `TAP_TOKEN` | Fine-grained personal access token that can push to the tap |

#### `SIGNING_P12`, `SIGNING_P12_PASSWORD`

Generate the certificate once, on your Mac:

```bash
bash scripts/release_cert.sh ~/hidebar-release.p12
```

The script asks for a password (or reads `RELEASE_P12_PASSWORD`), creates a self-signed
"Hidebar Release Signing" code-signing certificate valid for 10 years, writes it with its private
key to the `.p12`, and prints the certificate SHA-1 and the two commands that store the secrets:

```bash
base64 -i ~/hidebar-release.p12 | gh secret set SIGNING_P12 --repo pod2metra/hidebar
gh secret set SIGNING_P12_PASSWORD --repo pod2metra/hidebar
```

It refuses to overwrite an existing file and touches neither the repository nor your keychain.

**Back up the `.p12` and its password** (a password manager, an encrypted drive), outside the
repository. If it is lost, the next certificate is a different one: every release after that has
a different signature, and every user has to grant Accessibility again. The same happens if
you run the script a second time and replace the secrets. The certificate expires after 10 years;
replacing it then is the same one-time break.

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
   - imports the `.p12` into a temporary keychain and picks the signing identity by the SHA-1 of
     the certificate inside it (a self-signed certificate is untrusted, so `find-identity -v`
     would not list it);
   - re-signs the app with that identity, with the hardened runtime (the script fails if the flag
     is missing) and without a timestamp (`scripts/package.sh release-app`);
   - builds the DMG from the app and signs it (`release-dmg`), then records its SHA-256;
   - creates the GitHub Release `v0.2.0` with `Hidebar-0.2.0.dmg` and notes made from
     the commit subjects since the previous `v*` tag (`scripts/release_notes.sh`);
   - writes `Casks/hidebar.rb` (version and SHA-256) to the tap and pushes it;
   - deletes the temporary keychain and the `.p12`.

To re-run for an existing tag, use *Actions -> Release -> Run workflow*, leave `bump` as
`none` and enter the tag. Give exactly one of `bump` and `tag`; the run fails otherwise.
If the GitHub Release already exists, the DMG is replaced and the cask is refreshed
with the new checksum.

Users then install with:

```bash
brew install --cask pod2metra/tap/hidebar
```

or download the DMG from the Release. Either way, the first launch is blocked by Gatekeeper:
they open *System Settings -> Privacy & Security*, scroll down and press *Open Anyway* next to
Hidebar. The cask prints this as a caveat.

## Trying the release build locally

Import the `.p12` into a throwaway keychain (never your login keychain), put that keychain first
in the search list, and pass the certificate hash as the identity:

```bash
read -rs -p "p12 password: " P12_PASSWORD; echo   # keeps the password out of the shell history
security create-keychain -p tmp /tmp/hidebar-test.keychain-db
security unlock-keychain -p tmp /tmp/hidebar-test.keychain-db
security import ~/hidebar-release.p12 -k /tmp/hidebar-test.keychain-db -P "$P12_PASSWORD" -T /usr/bin/codesign
unset P12_PASSWORD
security set-key-partition-list -S apple-tool:,apple: -s -k tmp /tmp/hidebar-test.keychain-db
security list-keychains -d user -s /tmp/hidebar-test.keychain-db "$HOME/Library/Keychains/login.keychain-db"

SIGN_IDENTITY=<certificate SHA-1> VERSION=0.2.0 BUILD_NUMBER=1 bash scripts/package.sh release-app
SIGN_IDENTITY=<certificate SHA-1> VERSION=0.2.0 bash scripts/package.sh release-dmg
```

This signs `build/dd/Build/Products/Release/Hidebar.app` and writes `build/Hidebar-0.2.0.dmg`.
`codesign -dvv` on either shows `Authority=Hidebar Release Signing`, and `codesign -dr -` prints a
designated requirement that is identical across builds. Remove the test keychain afterwards with
`security delete-keychain` and restore the keychain search list.
Without arguments, `bash scripts/package.sh` makes the ad-hoc `build/Hidebar.dmg` for local use.

## Notes

- The Accessibility grant is tied to the code signature. Because every release is signed with the
  same certificate, users keep their grant across updates. Hidebar's own debug builds use a different
  certificate (`scripts/dev_cert.sh`).
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
- Moving to a Developer ID certificate later means restoring notarization steps (they are in git
  history) and changing the secrets; users then grant Accessibility once more.
