# SpaceLens

SpaceLens is a native macOS disk intelligence app. It scans filesystem
metadata, explains large disk consumers, classifies cleanup risk with local
rules, and queues review candidates before cleanup.

![SpaceLens main window](docs/screenshots/spacelens-main.png)

## Features

- Native SwiftUI macOS app packaged from SwiftPM.
- Real filesystem scanning with throttled live progress updates.
- Responsive sidebar, table, inspector, and bottom cleanup action bar.
- Local rule-based safety classification for caches, generated outputs, logs,
  protected system paths, active tool-owned storage, and valuable user data.
- Sortable table headers, search, filters, multi-select, Select All, and Select
  Safe.
- Cleanup queue plus confirmation-gated Move to Bin for cleanup-ready items.
- Persistent last scan restore using security-scoped folder access and a durable
  cleanup queue, so closing or restarting the app keeps your review context.
- Local intelligence summaries and per-item evidence without sending file
  contents or metadata to external services.
- Visible Settings, privacy, and saved-session controls.

## Run

```bash
./script/build_and_run.sh --verify
```

## Test

```bash
swift test
```

## Build

```bash
swift build
swift build -c release
```

## App Store

SpaceLens includes a reproducible Xcode/App Store packaging lane:

```bash
./script/validate_app_store_readiness.sh
SPACE_LENS_DEVELOPMENT_TEAM=YOUR_TEAM_ID ./script/archive_app_store.sh
```

Existing local App Store exports are stale and are not current release
evidence. Generate a fresh archive only after the release-hardening gate passes.

See [docs/APP_STORE.md](docs/APP_STORE.md) for signing, archive, upload, and
App Store Connect metadata steps.

Production readiness notes live in [docs/production-plan.md](docs/production-plan.md)
and [docs/app-store-release-checklist.md](docs/app-store-release-checklist.md).

## Workflow

- Click table headers to sort scanned files.
- Use search and the filter segmented control to narrow visible results.
- Use Select All or Select Safe to build a multi-selection.
- Use the bottom action bar to queue or move cleanup-ready items to the Bin.
- Restart SpaceLens to restore the last selected scan root and cleanup queue.
- Open Settings from the toolbar or the bottom sidebar action strip.

## Safety

Cleanup is safety-gated. SpaceLens enables Move to Bin only for items
classified as safe temp, rebuildable cache, or generated output. The
confirmation lists every target path. Permanent deletion is not exposed in
SpaceLens 1.0.

## Performance Notes

- Visible rows, classifications, selected cleanup candidates, and selected
  recoverable bytes are cached in app state instead of recomputed during every
  SwiftUI redraw.
- Scan progress is throttled and guarded by scan generation tokens so cancelled
  scans cannot update a newer active scan.
- Tree flattening and scan statistics aggregation avoid repeated full-tree
  passes.

## Support

Privacy and support drafts:

- [Privacy Policy](docs/PRIVACY.md)
- [Support](docs/SUPPORT.md)

The public privacy-policy and support URLs required by App Store Connect remain
external release blockers until they return HTTP 200 without authentication.
