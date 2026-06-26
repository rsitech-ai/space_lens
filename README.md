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
- Cleanup queue plus confirmation-gated Move to Bin and typed-confirmation
  Delete Forever for cleanup-ready items only.
- Local intelligence summaries and per-item evidence without sending file
  contents or metadata to external services.
- Visible Settings and Support entry points in the toolbar, sidebar, menu bar,
  and Settings window.

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

See [docs/APP_STORE.md](docs/APP_STORE.md) for signing, archive, upload, and
App Store Connect metadata steps.

## Workflow

- Click table headers to sort scanned files.
- Use search and the filter segmented control to narrow visible results.
- Use Select All or Select Safe to build a multi-selection.
- Use the bottom action bar to queue, move to Bin, or permanently delete only
  cleanup-ready items.
- Open Settings or Support from the toolbar or the bottom sidebar action strip.

## Safety

Cleanup is safety-gated. SpaceLens enables Move to Bin and Delete Forever only
for items classified as safe temp, rebuildable cache, or generated output. Move
to Bin asks for confirmation; Delete Forever requires typing `DELETE`.

## Performance Notes

- Visible rows, classifications, selected cleanup candidates, and selected
  recoverable bytes are cached in app state instead of recomputed during every
  SwiftUI redraw.
- Scan progress is throttled and guarded by scan generation tokens so cancelled
  scans cannot update a newer active scan.
- Tree flattening and scan statistics aggregation avoid repeated full-tree
  passes.

## Support

If SpaceLens saves you time or disk space, you can support development here:

<https://buymeacoffee.com/s1korrrr>

Privacy and support:

- [Privacy Policy](docs/PRIVACY.md)
- [Support](docs/SUPPORT.md)
