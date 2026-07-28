# SpaceLens 1.0.2 Release Notes

## What’s Improved

SpaceLens 1.0.2 makes large scan results easier to identify and safer to review.
Every Name cell now shows a compact home-relative parent location beneath the
file or folder name. Hover help and accessibility retain the full absolute path.

Selected rows and cleanup-queued rows now remain visually and accessibly
distinct, including when both states apply to one item. The result table uses
reusable native AppKit cells so the two-line layout, sorting, filtering,
selection, queue state, and responsive columns stay synchronized as cells are
reused.

Queue membership is cached by item identifier, avoiding a linear queue scan for
every visible row.

## Verification

- The warnings-as-errors Swift suite passes 99 tests, including native AppKit
  lifecycle tests for queue updates, selection, row reordering, sort state,
  accessibility state, and wide-to-compact transitions.
- The packaged app was exercised with duplicate filenames in separate parent
  folders. Home-relative paths, selected and queued states, combined state,
  sorting, filtering, keyboard navigation, tooltips, and accessibility labels
  passed.
- The release artifact must be built from the final merged `main` commit and
  independently pass universal architecture, Developer ID signing, Apple
  notarization, stapling, Gatekeeper, checksum, and public-download checks
  before publication.

## Download

Download `SpaceLens-1.0.2-macOS-universal.zip` with `SHA256SUMS.txt` and
`BUILD_INFO.txt` from the `v1.0.2` release. Verify the checksum before
extracting and opening `SpaceLens.app`.

SpaceLens supports Apple silicon and Intel Macs running macOS 14 or later.

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
