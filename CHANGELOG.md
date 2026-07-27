# Changelog

All notable SpaceLens changes will be documented in this file. The format is
based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and published
versions will use [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/rsitech-ai/space_lens/compare/v1.0.1...HEAD
[1.0.1]: https://github.com/rsitech-ai/space_lens/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/rsitech-ai/space_lens/releases/tag/v1.0.0
