# Changelog

## 1.1.1

- Bound whole-folder scan details across the entire tree while measuring all accessible descendants.
- Stream directory entries and drain temporary metadata objects during large scans.
- Show activity, safety classification, and summary phases after traversal finishes.
- Stop classification cooperatively when a scan is cancelled and disclose limited folder details.

## 1.1.0

- Expand Smart Scan coverage and retain only candidate roots during sizing.
- Index activity paths once, bound helper lifetimes, and reject unavailable activity checks.
- Require rebuild evidence, preserve incomplete-scan warnings, and protect shared temporary directories.
- Confirm every frozen cleanup target in a scrollable sheet and refresh activity before cleanup.
- Rebind queued items after rescans and keep updated safety explanations consistent.


All notable SpaceLens changes will be documented in this file. The format is
based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and published
versions will use [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.2] - 2026-07-28

### Added

- File rows now show a compact home-relative parent location beneath the name,
  while hover help and accessibility expose the complete absolute path.
- Selected and cleanup-queued rows now retain distinct visual and accessibility
  states, including when both states apply to the same item.

### Changed

- The large result table now uses reusable native AppKit cells with fixed
  two-line rows, stable identifier-based selection, and responsive columns.
- Cleanup queue membership is cached for constant-time visible-row lookups.

### Fixed

- Sorting, filtering, keyboard selection, queue updates, and responsive layout
  transitions no longer leave reused rows with stale state or accessibility
  labels.

## [1.0.1] - 2026-07-27

### Fixed

- Smart Scan now adds a large selection to the cleanup queue in one normalized
  batch, avoiding repeated app-wide updates and persistence work for every
  selected file or folder.

## [1.0.0] - 2026-07-20

### Added

- Native local-first disk scanning, classification, review, and recoverable
  Move-to-Bin cleanup workflow for macOS.
- Reproducible SwiftPM and XcodeGen build lanes with direct-download and Mac App
  Store packaging scripts.
- Source-bound Developer ID packaging and an approval-gated notarization
  finalizer that recreates the downloadable ZIP after stapling.
- Contributor, support, security-reporting, and release-readiness guidance.

### Changed

- CI now selects Xcode 26.6 exactly and verifies the pinned XcodeGen 2.45.4
  archive before use.
- Public documentation now reflects the published `v1.0.0` source release
  (source archive and checksums) while noting the notarized macOS binary asset
  is still pending Apple notarization credentials.

[Unreleased]: https://github.com/rsitech-ai/space_lens/compare/v1.0.2...HEAD
[1.0.2]: https://github.com/rsitech-ai/space_lens/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/rsitech-ai/space_lens/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/rsitech-ai/space_lens/releases/tag/v1.0.0
