# SpaceLens 1.1.0

Smart Scan inventories common development caches and larger review items in the selected folder. It measures cache trees without retaining a row for every file and publishes throttled progress with up to three concurrent measurements.

- Expanded coverage for Xcode, Python, Cargo, JavaScript framework output, package caches, simulator devices, local histories, research outputs, and large user files.
- Cargo targets require a sibling manifest. Whole node_modules and web framework outputs require a package manifest and lockfile. Generic build/dist folders remain review-only.
- Worktrees, session histories, virtual environments, release archives, backups, Docker storage, model stores, and simulator state remain review-only or tool-owned. Age alone does not authorize removal.
- Incomplete scans, symbolic links, failed activity checks, active tools, and changed filesystem identities block cleanup. Shared temporary directories cannot be removed wholesale.
- Cleanup refreshes activity information and checks rebuild evidence again before moving files to the Bin.
- Table locations are relative to the selected folder. Full paths remain in tooltips, accessibility text, the selectable inspector, and cleanup confirmation.
- The confirmation lists every target in a scrollable sheet and retains the confirmed selection. Cancelling a scan requires a new completed scan before cleanup.

## Limits

Only the selected scope and accessible metadata are scanned. The discovery time budget reports unfinished roots; it is not a promise to inspect every file on every volume. Filesystem metadata and process snapshots cannot prove that every cache is disposable. Review the exact paths and close owning applications before cleanup. File size is an estimate: hard links, APFS clones, compression, sparse files, and the Bin affect actual reclaimed space. Moving to the Bin does not immediately free that space.

Activity inspection uses bounded local process helpers. When the operating system or sandbox prevents that inspection, the app reports it and keeps candidates review-only. Simulator inspection may likewise be unavailable; use Xcode for tool-owned removals.

This source version is prepared for local installation. Apple notarization and public release publication are separate distribution steps.
