# Production Plan: SpaceLens

## Product Brief

- Target user: Mac users and developers who need to understand disk usage
  without blindly deleting valuable project or document data.
- Primary job: scan a user-selected folder, explain what is consuming space,
  classify cleanup risk, and queue safe cleanup candidates.
- Core workflow: select folder -> watch scan progress -> sort/filter/review
  findings -> queue cleanup-ready items -> review exact paths -> confirm Move
  to Bin.
- Business model: free utility with no in-app purchase or external tipping link.
- Supported macOS versions: macOS 14+.
- Offline behavior: fully local and offline for scanning, classification,
  persistence, and cleanup.
- Data handled: user-selected filesystem metadata; no file contents are read for
  intelligence decisions.
- Privacy posture: local-only, no analytics, no tracking, no external metadata
  upload.
- V1 scope: filesystem scan, local classification, persistent scan root/cleanup
  queue restore, cleanup confirmations, App Store packaging lane.
- Explicitly out of scope: cloud sync, background global disk monitoring,
  unsandboxed full-disk access, external AI processing, auto-delete.

## Architecture

- Scene model: `WindowGroup` plus native `Settings` scene.
- Window roles: one primary sidebar/table/inspector window.
- Layout model: `NavigationSplitView` with sidebar, table content, inspector,
  and bottom cleanup action bar.
- State ownership: `AppState` owns app-wide scan, selection, queue, and cached
  derived data.
- Persistence: `AppSessionStore` writes a small JSON session under Application
  Support with security-scoped bookmark data for the last root and cleanup queue
  paths.
- Services: `DiskScanner`, `FileCleanupService`, `FinderService`,
  `LocalIntelligenceService`, `RuleEngine`.
- App Intents / Foundation Models / advanced capabilities: not used in V1.
- Folder/module structure: app state at root, models/services/rules/stores/
  support/views/tests split by responsibility.

## Build And Run

- Project type: SwiftPM primary with XcodeGen-backed Xcode project for App
  Store packaging.
- Build command: `swift build` or `swift build -c release`.
- Development run command: `./script/build_and_run.sh --verify`.
- `script/build_and_run.sh` status: verified.
- Codex Run action status: `.codex/environments/environment.toml` runs
  `./script/build_and_run.sh --verify`.

## Design System

- Native structures: SwiftUI `NavigationSplitView`, `Table`, native forms,
  settings, commands, toolbar, and inspector.
- Adaptive states: compact sidebar titles, responsive table/action bar, empty
  state, scan progress, error and confirmation surfaces.
- Visual style: dark native macOS utility style with restrained color accents
  for progress, safety, and support actions.
- Motion rules: scan progress and live scan animation communicate long-running
  work; cancellation is visible.
- Accessibility requirements: labels/tooltips for icon controls, keyboard/menu
  paths for scan and selection commands, native focus/selection states.
- Empty/loading/error/offline/permission states: empty state prompts folder
  selection; scan state shows progress/cancel; cleanup failures surface
  user-facing errors; no online dependency.

## Test Strategy

- Unit tests: formatters, scanner, rule engine, intelligence summary, cleanup
  queue, support links, session store.
- Integration tests or mocks: real temporary filesystem scans and cleanup
  actions; session restore integration test using a temporary store file.
- UI/manual smoke: development launch through `script/build_and_run.sh
  --verify`; release proof uses the current Xcode Release/archive app.
- Release smoke: `script/validate_app_store_readiness.sh`, Xcode app
  build/test, signed archive/export, sandbox entitlement inspection, and a
  controlled relaunch restore smoke.
- Commands:
  - `swift test`
  - `swift build -c release`
  - `xcodebuild -project SpaceLens.xcodeproj -scheme SpaceLens -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test`
- `./script/build_and_run.sh --verify` (development smoke only)
- `./script/validate_app_store_readiness.sh`
  - `SPACE_LENS_DEVELOPMENT_TEAM=2NY8A789TN ./script/archive_app_store.sh`

## Observability

- Logger subsystem: `com.rsitech.spacelens`.
- Categories: `session` currently logs persistence failures.
- Key lifecycle/action events: session restore/persistence failures are logged;
  scan/cleanup state is visible in UI.
- Sensitive logging exclusions: no file contents, tokens, or external account
  secrets are logged.

## App Store Readiness

- Bundle ID: `com.rsitech.spacelens`.
- Signing team used for verified App Store export: `2NY8A789TN`.
- Sandbox/entitlements: App Sandbox plus user-selected read/write file access
  and app-scoped security bookmark persistence.
- Privacy manifest: present at `Resources/PrivacyInfo.xcprivacy`.
- Privacy labels: draft as no collected data; local selected-folder metadata
  processing only.
- Assets: App icon asset catalog present.
- Metadata: local privacy/support drafts are present; public HTTPS URLs remain blocked.
- Review notes: app scans only user-selected folders, performs local risk
  classification, and gates destructive cleanup behind confirmation.
- Historical export exists; a final current-source export remains pending.
- Known blockers: App Store Connect app record confirmation, final metadata,
  screenshots, privacy labels, age rating, and upload/submission.

## Iteration Log

| Date | Gate | Change | Verification | Next blocker |
| --- | --- | --- | --- | --- |
| 2026-06-29 | Persistence | Added `AppSessionStore` and automatic restore of last scan root/cleanup queue. | `swift test --filter AppSessionStoreTests` and live restore smoke passed. | App Store Connect upload. |
| 2026-06-29 | Production docs | Added this production plan and release checklist. | Markdown/docs reviewed in repo. | App Store metadata. |
| 2026-06-29 | App Store export | Generated signed App Store package. | `SPACE_LENS_DEVELOPMENT_TEAM=2NY8A789TN ./script/archive_app_store.sh` produced `build/AppStore/export/SpaceLens.pkg`. | Upload and submit in App Store Connect. |
