# SpaceLens 1.0 Release Status

## Verdict

`BLOCKED:EXTERNAL — PACKAGE-READY PRE-SECURITY`

Status date: 2026-07-16

All currently runnable non-security repository gates pass at product source `6d9f314`. A correctly signed Store package was built from release revision `0df601f` and is package-ready for the final security gate. It is not a release candidate and must not be uploaded yet. App Store Connect record `6791508081` now exists as `SpaceLens: Disk Cleanup`, with macOS 1.0 in Prepare for Submission and no uploaded builds. DSA Trader status and the public contact details are owner-approved and entered; Apple sent a verification code to the approved phone number, and the workflow is paused at code entry. Final security, macOS 14 and human accessibility checks, Apple validation/processing and processed-build install also remain.

## Release Identity

- Product: SpaceLens for macOS
- Public App Store name: SpaceLens: Disk Cleanup
- App Store Connect Apple ID: `6791508081`
- Bundle identifier: `com.rsitech.spacelens`
- Version/build: 1.0 (1)
- Minimum macOS: 14.0
- Product source: `6d9f314eb7a92a54de94e6c88b50542f5398ac1b`
- Package source: `0df601ffffc3c0fb97482df4b1abd7722e69e3d4`
- Release branch: `feat/andrzej_spacelens-release-final`
- Legal owner: Rafal Sikora
- Public support: `info@rsitech.ai`
- Pricing/territories/release: free, all available territories, automatic

## Gate Summary

| Gate | Status | Evidence / next action |
| --- | --- | --- |
| Repository/config | PASS | Clean committed product source; XcodeGen parity; `com.rsitech.spacelens`; export key false |
| SwiftPM/Xcode tests | PASS | 50/50 in warnings-as-errors and signed Xcode lanes |
| Static analysis | PASS | Universal Release analyze succeeded |
| Address/Thread Sanitizers | PASS | Fresh 50/50 suites |
| Universal Release | PASS | `x86_64 arm64`, warnings as errors |
| Runtime workflow | PASS (bounded) | Synthetic sandboxed picker/scan/queue/exact-dialog/cancel, unchanged hashes and bookmark restore |
| Layout/accessibility | PARTIAL | Automated AX labels and 820x620 pass; Light, focus and VoiceOver human proof remain |
| Minimum macOS 14 | BLOCKED | No compatible runtime proof |
| Security | PENDING | Owner requested scan after all other fixes; previous reports are historical only |
| Privacy/metadata | PASS (owner/web) / BLOCKED (ASC entry) | Data Not Collected, age-rating None, export compliance and content rights owner-confirmed; public Support and Privacy URLs return signed-out HTTP 200; DSA phone verification code remains |
| GitHub CI | BLOCKED (external exception) | Run `29481267996`, job `87565329735`, zero steps due billing/spending; local equivalents pass |
| Signing/package | PASS | Apple ID and Store profiles match; signed universal package SHA-256 `e2e5f484ffa7f648a2019b7a8cbf75babc96835dbddfcb76378a87ff7904af05` |
| App Store Connect record | PASS | Apple ID `6791508081`; `SpaceLens: Disk Cleanup`; English (U.S.); `com.rsitech.spacelens`; SKU `SPACELENS-MAC-001`; macOS 1.0 Prepare for Submission; no uploaded builds |
| DSA Trader verification | BLOCKED (owner code) | Approved public address, `info@rsitech.ai` and `private contact stored only in App Store Connect` were entered; Apple sent an SMS code and the open workflow is paused at code entry |
| App Store validation/upload | BLOCKED | Requires final security disposition, completed DSA verification and fresh approval of the exact package digest |
| Processed install | BLOCKED | No Apple-processed build exists |

## Public Pages

- Support: <https://www.rsitech.ai/spacelens/support> — signed-out HTTP 200.
- Privacy: <https://www.rsitech.ai/spacelens/privacy> — signed-out HTTP 200.

## Stale Package — Never Upload

`/private/tmp/SpaceLens-final-AppStore-791fe6c/export/SpaceLens.pkg` and SHA-256 `a108ee50640d65f3e6f8427b7d343143a674125bc28774442d4d4df2b548326a` belong to the retired `com.andrzej.spacelens` identity and pre-fix source. They are not a release candidate.

## Current Package — Hold Before Upload

- Archive: `/private/tmp/SpaceLens-AppStore-20260716-0df601f/SpaceLens.xcarchive`
- Installer: `/private/tmp/SpaceLens-AppStore-20260716-0df601f/export/SpaceLens.pkg`
- SHA-256: `e2e5f484ffa7f648a2019b7a8cbf75babc96835dbddfcb76378a87ff7904af05`
- Identity: `com.rsitech.spacelens`, team `2NY8A789TN`, version 1.0 (1)

This is the current package-ready artifact, but security and App Store Connect gates are still open. Upload requires a fresh exact-digest approval.

## Next Sequence

1. Enter the SMS verification code Apple sent to the approved phone number.
2. Complete any remaining Apple email, address or document verification steps that Apple presents.
3. Complete human macOS 14/Light/focus/VoiceOver checks and screenshot approval.
4. Commit this evidence update, then run the requested final security scan against the exact branch state and fix any validated release blocker.
5. If security changes code or packaging inputs, rebuild and record a new digest; otherwise retain the inspected package above.
6. Enter the confirmed metadata and declarations in App Store Connect.
7. With fresh exact-digest authorization, validate/upload only the approved package and wait for Apple processing.
8. Install the Apple-processed build and repeat the critical workflow, then request separate approval before Submit for Review.

The latest authorization covered the exact public Trader address, email and phone entry and advancement to Apple’s verification-code boundary. It did not authorize supplying an unknown code or document, package upload, TestFlight mutation, submission, tag or public release.
