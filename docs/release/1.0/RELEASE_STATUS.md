# SpaceLens 1.0 Release Status

Status: **source release v1.0.0 published; notarized macOS binary not published**

Last repository review: 2026-07-20

## Source of truth

- Bundle identifier: `com.rsitech.spacelens`
- Version/build: `1.0 (1)`
- Minimum macOS: 14.0
- Architectures: `arm64 x86_64`
- Project generator: XcodeGen 2.45.4
- Production toolchain: Xcode 26.6
- Direct-download and Mac App Store packages are independent artifacts with
  independent signing and external validation evidence.

## Current evidence

- SwiftPM and Xcode suites cover scanning, authorization, persistence,
  classification, cleanup boundaries, empty states, layout/motion policy,
  support integration, and release-script contracts.
- The release build embeds `Resources/PrivacyInfo.xcprivacy` unchanged.
- Direct-download packaging binds `BUILD_INFO.txt` to an exact clean source
  commit and tree, uses hardened-runtime Developer ID signing, and generates a
  checksum for the pre-notarization ZIP.
- `script/notarize_direct_download.sh` fails closed on mismatched source or
  artifact provenance, submits the exact input ZIP, requires Apple acceptance,
  staples and validates a copy of the app, runs Gatekeeper assessment, then
  creates a new final ZIP.

Historical local artifacts are not evidence for the current source. The
repository has a published `v1.0.0` tag and GitHub source release (source
archive and checksums) at this status date. A notarized downloadable macOS
binary is not part of that release and remains blocked on Apple notarization
credentials.

## Gates before a public open-source release

| Gate | Status | Required evidence or decision |
| --- | --- | --- |
| Repository tests and builds | Passed | Warnings-as-errors SwiftPM, Xcode tests/analyze, project-generation, runtime smoke, and universal release-build checks passed for the release-readiness branch. |
| Hosted CI | Passed | PR #14 completed on Xcode 26.6 with SwiftPM tests, Xcode tests, universal Release build, and metadata validation. |
| License | Complete | Apache License 2.0; copyright 2026 Rafal Sikora. Contributions use the same terms. |
| Asset provenance | Complete | The owner confirmed Apache-2.0 coverage for the seven app icons and two repository screenshots on 2026-07-20. |
| Secret scan | Passed | Gitleaks 8.30.1 found no leaks across the working tree and full Git history. Broader static/security-completeness coverage is not claimed. |
| App Store age rating metadata | Needs reconciliation | Verify the live age-rating declaration in App Store Connect before upload. |
| Developer ID package | Ready to build | A valid `Developer ID Application: Rafal Sikora (2NY8A789TN)` identity is installed; build from the final clean commit. |
| Apple notarization | Blocked externally | Store a `notarytool` credential profile, then obtain an accepted result, stapler validation, Gatekeeper acceptance, and post-stapling ZIP checksums. |
| Repository visibility | Approved for public release | The owner explicitly approved public visibility and publication of the existing Git author metadata. |
| Canonical repository owner | Complete | Repository transferred to `rsitech-ai/space_lens`. |
| GitHub source release | Published | `v1.0.0` is published with the source archive `space_lens-1.0.0-source.tar.gz` and `SOURCE-SHA256SUMS.txt`. |
| Notarized macOS binary asset | Blocked externally | Not yet published; build the source-bound accepted/stapled artifact with checksums once Apple notarization credentials are available, then attach it to the release. |

## App Store boundary

App Store Connect validation, upload, processing, TestFlight, review, and
release control are separate owner-approved actions. Private review contacts,
verification codes, legal/account declarations, and live account state do not
belong in the repository.
