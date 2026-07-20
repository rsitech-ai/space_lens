# SpaceLens 1.0 Release Notes

## What’s New

SpaceLens 1.0 helps you understand storage use on your Mac with local folder scanning, Smart Scan suggestions for common rebuildable caches and generated outputs, and clear evidence for each cleanup classification.

Review and filter candidates before taking action. Cleanup-ready items move to the Bin only after an exact-path confirmation, so the operation remains recoverable.

SpaceLens works locally, with no account, analytics, advertising, or tracking SDK.

## Known Limitations

- SpaceLens scans only folders the user explicitly selects and cannot override
  macOS privacy, sandbox, permission, or filesystem errors.
- Safety classifications are deterministic guidance, not a guarantee that a
  file is unimportant. Review every exact path before cleanup.
- Cleanup moves eligible items to the Bin; it does not permanently erase them
  or empty the Bin.
- Smart Scan focuses on known rebuildable caches and generated outputs. It does
  not attempt to discover every application-specific cleanup location.
- Version 1.0 has no background scanning, network sync, cloud account, or
  telemetry.

## Publication Status

These are release-candidate notes. No public `v1.0.0` tag or GitHub release has
been published yet. A downloadable artifact must be built from the final clean
commit, signed with Developer ID, accepted by Apple notarization, stapled,
Gatekeeper-assessed, and checksummed before publication.
