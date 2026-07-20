# SpaceLens 1.0 Release Status

Status: **release candidate; not published**

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
- The end-to-end application evidence is recorded in
  `docs/audits/2026-07-17-end-to-end-audit.md`.

Historical local artifacts are not evidence for the current source. The
repository has no public tag or GitHub release at this status date.

## Gates before a public open-source release

| Gate | Status | Required evidence or decision |
| --- | --- | --- |
| Repository tests and builds | Pending final verification | Clean warnings-as-errors SwiftPM, Xcode, project-generation, and release-build checks on the final commit. |
| Hosted CI | Blocked externally | A new GitHub Actions run must start and complete; current jobs are blocked by the account billing/spending state before any step executes. |
| License | Blocked: owner decision | Approve the license, licensor/copyright holder, and contribution terms; add `LICENSE`. |
| Asset provenance | Blocked: owner confirmation | Confirm rights and intended license coverage for all app icons and screenshots listed in `docs/ASSET_PROVENANCE.md`. |
| Security scan | Not performed | Excluded at owner direction; do not claim security-scan completeness. |
| App Store age rating metadata | Needs reconciliation | `.codex/app-store/metadata.json` says the age rating is not declared while the owner attestation says it is complete; verify the live declaration before upload. |
| Developer ID package | Blocked externally | Build from the final clean commit with an available Developer ID Application identity. |
| Apple notarization | Blocked externally | Accepted notarization result, stapler validation, Gatekeeper acceptance, and checksums for the post-stapling ZIP. |
| Repository visibility | Private | Owner must explicitly approve changing visibility. |
| Canonical repository owner | Pending owner decision | Confirm whether the current personal repository remains canonical or is transferred to the RSI Tech organization. |
| GitHub release | Not published | Create `v1.0.0` and publish only the source-bound accepted/stapled artifact, checksum, build info, and release notes. |

## App Store boundary

App Store Connect validation, upload, processing, TestFlight, review, and
release control are separate owner-approved actions. Private review contacts,
verification codes, legal/account declarations, and live account state do not
belong in the repository.
