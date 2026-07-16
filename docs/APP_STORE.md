# SpaceLens App Store Release Runbook

SpaceLens now has a reproducible Xcode/App Store packaging lane alongside the
SwiftPM development lane.

## Prerequisites

- Active Apple Developer Program membership.
- Xcode 26.6 or newer for the production release lane.
- XcodeGen 2.45.4 installed. Release scripts fail closed on version drift.
- App Store Connect app record for bundle ID `com.rsitech.spacelens`.
- Apple Distribution signing certificate installed in the login keychain.
- App Store provisioning handled automatically by Xcode, or already available
  for `com.rsitech.spacelens`.

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

- App name: `SpaceLens: Disk Cleanup`
- Bundle ID: `com.rsitech.spacelens`
- Category: Utilities
- Privacy Policy URL: `https://www.rsitech.ai/spacelens/privacy`; verified
  signed-out HTTP 200.
- Support URL: `https://www.rsitech.ai/spacelens/support`; verified signed-out
  HTTP 200.
- App privacy answers: local filesystem metadata is processed on device; no
  file contents or metadata are sent to external services by SpaceLens.
- Review notes: SpaceLens scans only user-selected folders, classifies cleanup
  risk locally, and gates destructive cleanup behind confirmation.
- Screenshots from the current macOS build at an Apple-accepted 16:10 size.

`./script/build_and_run.sh --verify` creates a local SwiftPM development smoke
bundle. It is not the sandboxed, signed App Store artifact. Release runtime
proof must use the current Xcode Release/archive app.
