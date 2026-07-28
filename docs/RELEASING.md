# SpaceLens Release Runbook

This runbook separates repository verification, Developer ID packaging, Apple
notarization, and GitHub publication. Each stage must use the same clean source
commit. Do not reuse prior artifacts after source or packaging inputs change.

## 1. Seal the source commit

```bash
git status --short
swift test -Xswiftc -warnings-as-errors
./script/generate_xcode_project.sh
git diff --exit-code -- SpaceLens.xcodeproj
./script/build_and_run.sh --verify
```

Confirm `docs/OPEN_SOURCE_READINESS.md` has no unresolved release gate. In
particular, require an approved license and asset-provenance confirmation.
Derive the release version from `project.yml` and keep every later filename,
tag, and documentation path aligned with it:

```bash
VERSION="$(awk -F '"' '/MARKETING_VERSION:/ { print $2; exit }' project.yml)"
test -n "$VERSION"
```

## 2. Build the pre-notarization direct download

Use new artifact and DerivedData directories. The script refuses dirty source,
unsafe paths, unavailable identities, and source changes during packaging.

```bash
SPACE_LENS_DEVELOPER_ID='Developer ID Application: Name (TEAMID)' \
SPACE_LENS_RELEASE_OUTPUT_DIR='/absolute/path/to/pre-notarization' \
SPACE_LENS_RELEASE_DERIVED_DATA='/absolute/path/to/derived-data' \
  ./script/build_direct_download.sh
```

Archive the exact `BUILD_INFO.txt`, `SHA256SUMS.txt`, app, and ZIP together.
This ZIP is not the final public asset.

## 3. Notarize, staple, and recreate the ZIP

Store notarization credentials in a Keychain profile outside the repository,
then run the approval-bound finalizer with a separate output directory:

```bash
SPACE_LENS_NOTARY_PROFILE='SpaceLens-notary' \
SPACE_LENS_RELEASE_INPUT_DIR='/absolute/path/to/pre-notarization' \
SPACE_LENS_NOTARIZED_OUTPUT_DIR='/absolute/path/to/final-notarized' \
  ./script/notarize_direct_download.sh
```

The script submits the exact pre-notarization ZIP with `notarytool --wait`,
requires an `Accepted` response, copies and staples the app, validates the
ticket, runs Gatekeeper assessment, and creates a new ZIP from the stapled app.
It does not modify the input directory. Preserve `NOTARIZATION_INFO.json` as
release evidence and confirm the final checksum:

```bash
cd /absolute/path/to/final-notarized
shasum -a 256 -c SHA256SUMS.txt
xcrun stapler validate SpaceLens.app
spctl -a -vv -t execute SpaceLens.app
```

Apple's distribution guidance requires Developer ID signing, hardened runtime,
and notarization for software distributed outside the Mac App Store. A ZIP
cannot carry a stapled ticket itself, so the app is stapled before the final ZIP
is created. See Apple's
[notarization workflow](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
and [custom workflow guidance](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow).

## 4. Create the GitHub release

Verify the final commit has a green hosted CI run and that the repository is at
the approved canonical owner and visibility. Create annotated tag `v$VERSION`
at that exact commit. Start a draft GitHub release and attach only:

- `SpaceLens-$VERSION-macOS-universal.zip` from the notarized output directory
- `SHA256SUMS.txt`
- `BUILD_INFO.txt`
- release notes derived from `docs/release/$VERSION/RELEASE_NOTES.md`

Verify downloaded release assets again before publishing. GitHub documents the
release workflow in [Managing releases in a repository](https://docs.github.com/repositories/releasing-projects-on-github/managing-releases-in-a-repository).

## 5. Mac App Store lane

The App Store package is independent from the direct-download ZIP:

```bash
./script/validate_app_store_readiness.sh
SPACE_LENS_DEVELOPMENT_TEAM=YOUR_TEAM_ID ./script/archive_app_store.sh
```

Follow `docs/APP_STORE.md`. App Store Connect validation, upload, TestFlight,
review, and release remain separate external owner-authorized actions.

## Rollback

If an unpublished candidate is invalid, discard only its isolated artifact
directories and rebuild from a new clean commit. If a published release is
invalid, mark it clearly, remove affected assets only with owner approval,
publish a corrected version, and retain the incident evidence. Never overwrite
an existing tag or silently replace a signed artifact.
