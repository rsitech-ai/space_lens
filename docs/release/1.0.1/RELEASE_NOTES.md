# SpaceLens 1.0.1 Release Notes

## What’s Improved

SpaceLens 1.0.1 makes Smart Scan queueing substantially more responsive for
large selections. Adding many files or folders now normalizes and publishes the
cleanup queue once instead of repeating app-wide updates and persistence work
for every selected item.

The cleanup safety model is unchanged: SpaceLens still classifies items
locally, shows exact paths for review, and moves confirmed cleanup-ready items
to the Bin rather than permanently deleting them.

## Verification

- A regression test verifies that queueing 64 selected items publishes one
  queue mutation rather than one mutation per item.
- A realistic Smart Scan fixture with 128 selected `.build` folders was queued
  successfully while preserving all 128 paths.
- The full Swift test suite, Xcode release build, static analysis, and packaged
  app verification pass with warnings treated as errors.

## Known Limitations

- SpaceLens scans only folders the user explicitly selects and cannot override
  macOS privacy, sandbox, permission, or filesystem errors.
- Safety classifications are deterministic guidance, not a guarantee that a
  file is unimportant. Review every exact path before cleanup.
- Cleanup moves eligible items to the Bin; it does not permanently erase them
  or empty the Bin.
- Smart Scan focuses on known rebuildable caches and generated outputs. It does
  not attempt to discover every application-specific cleanup location.
- SpaceLens has no background scanning, network sync, cloud account, or
  telemetry.

## Publication Status

The public `v1.0.1` release includes a universal macOS app built from commit
`ef2fc0d7c01ff9fdfd3dbc4d435ec1236626c9ea`, signed with Developer ID,
accepted by Apple notarization, stapled, Gatekeeper-assessed, checksummed, and
verified through a fresh public download.
