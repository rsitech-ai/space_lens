# Changelog

All notable SpaceLens changes will be documented in this file. The format is
based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and published
versions will use [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
- Public documentation no longer claims a GitHub release exists before a tag
  and release assets are actually published.

[Unreleased]: https://github.com/rsitech-ai/space_lens/compare/main...HEAD
