# SpaceLens App Store Release Runbook

SpaceLens now has a reproducible Xcode/App Store packaging lane alongside the
SwiftPM development lane.

## Prerequisites

- Active Apple Developer Program membership.
- Xcode 26.5 or newer.
- XcodeGen installed: `brew install xcodegen`.
- App Store Connect app record for bundle ID `com.andrzej.spacelens`.
- Apple Distribution signing certificate installed in the login keychain.
- App Store provisioning handled automatically by Xcode, or already available
  for `com.andrzej.spacelens`.

## Repo-Owned Release Assets

- `project.yml`: XcodeGen source of truth for `SpaceLens.xcodeproj`.
- `Config/Info.plist`: App Store bundle metadata, version, category, and icon.
- `Config/SpaceLens.entitlements`: App Sandbox, user-selected read/write file
  access, and app-scoped security bookmark persistence.
- `Config/ExportOptions-AppStore.plist`: App Store Connect archive export
  settings.
- `Resources/PrivacyInfo.xcprivacy`: privacy manifest declaring no collected
  data and file timestamp required-reason API usage for user-selected files.
- `Resources/Assets.xcassets`: App icon asset catalog.

## Validate Locally

```bash
./script/validate_app_store_readiness.sh
```

This validates plists, entitlements, icon assets, SwiftPM tests, Xcode project
generation, and an unsigned Xcode build.

## Create An App Store Archive

```bash
SPACE_LENS_DEVELOPMENT_TEAM=YOUR_TEAM_ID ./script/archive_app_store.sh
```

The script creates:

- `build/AppStore/SpaceLens.xcarchive`
- `build/AppStore/export/`

If the script reports a missing Apple Distribution certificate, open Xcode,
sign in with the Apple Developer account, then create/download the distribution
certificate from Xcode Settings > Accounts > Manage Certificates.

## Upload

Upload the exported package using one of Apple's supported paths:

- Xcode Organizer
- Transporter
- App Store Connect API tooling

## App Store Connect Metadata

Prepare these before submitting for review:

- App name: `SpaceLens`
- Bundle ID: `com.andrzej.spacelens`
- Category: Utilities
- Privacy Policy URL:
  `https://github.com/s1korrrr/space_lens/blob/main/docs/PRIVACY.md`
- Support URL:
  `https://github.com/s1korrrr/space_lens/blob/main/docs/SUPPORT.md`
- App privacy answers: local filesystem metadata is processed on device; no
  file contents or metadata are sent to external services by SpaceLens.
- Review notes: SpaceLens scans only user-selected folders, classifies cleanup
  risk locally, and gates destructive cleanup behind confirmation.
- Screenshots from the current macOS build.
