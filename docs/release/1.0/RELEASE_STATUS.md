# SpaceLens 1.0 Release Status

## Current source

- Bundle identifier: `com.rsitech.spacelens`
- Version: 1.0
- Build: 1
- Minimum macOS: 14.0
- Architectures: `arm64 x86_64`
- Distribution paths: direct-download ZIP and Mac App Store package are
  independent artifacts and require separate evidence.

## Direct download

The canonical user download is the `SpaceLens-1.0-macOS-universal.zip` asset on
the repository's [GitHub Releases page](https://github.com/s1korrrr/space_lens/releases).
The same release includes:

- `SHA256SUMS.txt` for integrity verification.
- `BUILD_INFO.txt` with the exact source commit, source tree, bundle metadata,
  architectures, signing identity, hardened-runtime state, and notarization
  state.

The ZIP is built only from a clean commit by `script/build_direct_download.sh`.
It must not be described as notarized unless Apple accepts the exact signed
artifact and `stapler validate` plus Gatekeeper assessment pass afterward.

## Repository and runtime evidence

- The warnings-as-errors SwiftPM and Xcode suites cover scanning, authorization,
  persistence, classification, cleanup boundaries, empty states, layout/motion
  policy, support integration, and release-script configuration.
- The release build embeds `Resources/PrivacyInfo.xcprivacy` unchanged.
- Cleanup remains exact-path, confirmation-gated, Move-to-Bin only, and rejects
  changed identities, symlinks, unauthorized roots, and non-queueable data.
- The current end-to-end evidence is recorded in
  `docs/audits/2026-07-17-end-to-end-audit.md`.

## External release boundaries

- Apple notarization is an approval-bound upload of an exact Developer ID-signed
  artifact; it is not inferred from local signing.
- App Store Connect validation, upload, processing, TestFlight, review, and
  release controls are separate owner-approved actions.
- Private review contacts, verification codes, legal/account declarations, and
  live account state do not belong in the repository.
