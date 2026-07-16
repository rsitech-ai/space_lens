# SpaceLens 1.0 Test Evidence

Fresh non-security evidence captured on 2026-07-15 and 2026-07-16 from product source `6d9f314eb7a92a54de94e6c88b50542f5398ac1b`. The signed package was built from release revision `0df601ffffc3c0fb97482df4b1abd7722e69e3d4`, which contains the verified product source plus release-dossier changes.

## Environment

| Check | Result | Evidence |
| --- | --- | --- |
| Product source | PASS | Clean commit `6d9f314`; branch `feat/andrzej_spacelens-release-final` |
| Shipping platform | PASS | macOS only; iOS is not applicable |
| Production toolchain | PASS | Xcode 26.6 (17F113), macOS 26.5 SDK, Swift 6.3.3 |
| Host | INFO | Apple M3 Max, current macOS 27 beta host |
| XcodeGen | PASS | 2.45.4; generated-project parity validated |
| Dependencies | PASS | No third-party Swift package dependencies or `Package.resolved` |

## Automated Verification

| Gate | Result | Command / artifact |
| --- | --- | --- |
| SwiftPM warnings-as-errors | PASS | `swift test -Xswiftc -warnings-as-errors`; 50 tests, 0 failures |
| Repository readiness validator | PASS | Fresh 2026-07-16 run: `SPACE_LENS_VALIDATION_DERIVED_DATA=/private/tmp/SpaceLens-dossier-validation-20260716 ./script/validate_app_store_readiness.sh`; 50/50 plus unsigned Xcode Debug and project parity |
| Signed Xcode tests | PASS | 50/50; `/private/tmp/SpaceLens-presecurity-6d9f314-tests.xcresult` |
| Universal Xcode Release | PASS | Warnings as errors; `/private/tmp/SpaceLens-presecurity-release-6d9f314`; `x86_64 arm64` |
| Bundle identity/export key | PASS | Built app reports `com.rsitech.spacelens` and `ITSAppUsesNonExemptEncryption=false` |
| Xcode Release analyze | PASS | `/private/tmp/SpaceLens-presecurity-analyze-6d9f314`; `ANALYZE SUCCEEDED` |
| Address Sanitizer | PASS | `swift test --sanitize=address -Xswiftc -warnings-as-errors`; 50/50 |
| Thread Sanitizer | PASS | `swift test --sanitize=thread -Xswiftc -warnings-as-errors`; 50/50 |
| Development bundle smoke | PASS | `./script/build_and_run.sh --verify`; `dist/SpaceLens.app` built, ad-hoc signed and launched |
| Release CLI inspection | PASS | Doctor: Xcode 26.6; scheme `SpaceLens`; bundle `com.rsitech.spacelens`; team `2NY8A789TN`; archive rebuild required |

The first universal-build invocation failed before compilation because Xcode requires `-scheme` when `-derivedDataPath` is supplied. Adding the repository scheme resolved the command-contract issue; the corrected universal build and analyzer both passed. This was not a source failure.

## Runtime Evidence

| Check | Result | Evidence / limitation |
| --- | --- | --- |
| Sandboxed folder picker and scan | PASS (synthetic fixture) | Selected a disposable fixture; scan completed with 6 items and 0 errors |
| Queue and exact-path confirmation | PASS | Queued disposable `.build`; Move to Bin dialog listed the exact target; canceled |
| No unintended mutation | PASS | Fixture hashes were unchanged after cancel |
| Bookmark restore | PASS | Selected folder restored after relaunch |
| Main controls and accessibility tree | PASS (automated) | Main controls expose labels/help in the macOS accessibility tree |
| Dark appearance | PASS | Current app observed in Dark appearance |
| Minimum window | PASS | Resized to 820x620; no clipping or unusable controls observed |
| Light appearance | BLOCKED (human/system setting) | Current app remained Dark; changing the system appearance requires a separate interactive action |
| Keyboard/VoiceOver | BLOCKED (human/system setting) | Automated labels pass; system keyboard-navigation and human VoiceOver proof remain |
| Minimum macOS 14 | BLOCKED | No macOS 14 hardware/VM evidence |

## Signing And Package Boundary

A current Mac App Store archive and installer package were produced successfully:

- Archive: `/private/tmp/SpaceLens-AppStore-20260716-0df601f/SpaceLens.xcarchive`
- Export: `/private/tmp/SpaceLens-AppStore-20260716-0df601f/export`
- Installer: `/private/tmp/SpaceLens-AppStore-20260716-0df601f/export/SpaceLens.pkg`
- Package SHA-256: `e2e5f484ffa7f648a2019b7a8cbf75babc96835dbddfcb76378a87ff7904af05`
- Expanded inspection: `/private/tmp/SpaceLens-Package-Inspect-e2e5f484`

Inspection passed for Apple Distribution app signature, 3rd Party Mac Developer Installer package signature, team `2NY8A789TN`, `com.rsitech.spacelens`, version 1.0 (1), minimum macOS 14.0, `x86_64 arm64`, App Sandbox, user-selected read-write access, app-scope security-scoped bookmarks, absence of `get-task-allow`, `PrivacyInfo.xcprivacy`, matching dSYMs/binary UUIDs and absence of quarantine.

The export embedded a matching Xcode-managed Store profile for `2NY8A789TN.com.rsitech.spacelens`, expiring 2027-06-29. The separately created and installed portal profile is `SpaceLens Mac App Store 2026`, portal ID `YPR4Y4YH4S`, UUID `8ae0f808-5c80-4c7c-8075-927c15c8de44`, also expiring 2027-06-29.

This package has not been validated with App Store Connect or uploaded. It remains on hold until final security, record creation and fresh exact-digest authorization.

The old package at `/private/tmp/SpaceLens-final-AppStore-791fe6c/export/SpaceLens.pkg`, SHA-256 `a108ee50640d65f3e6f8427b7d343143a674125bc28774442d4d4df2b548326a`, is quarantined evidence for the retired `com.andrzej.spacelens` identity and must not be uploaded.

## Screenshot Evidence

- Selected candidate: `screenshots/SpaceLens-macOS-dark-feature-1280x800.jpeg`.
- It is a truthful feature-state app capture at an accepted 1280x800 Mac screenshot size.
- Owner/marketing approval remains external.

## External CI

- Draft PR: <https://github.com/s1korrrr/space_lens/pull/9>
- Latest remote run: `29481267996`, job `87565329735`, head `0df601ffffc3c0fb97482df4b1abd7722e69e3d4`.
- The job completed with zero steps. GitHub reports recent account-payment failure or an insufficient spending limit.
- Owner-approved exception: proceed with fresh local CI-equivalent evidence while keeping this external gate red. This exception does not validate the remote workflow or cover unpushed commits.

## Security Boundary

Security is deliberately not claimed here. `SECURITY_STATUS.md` remains `PENDING_RESCAN` until the requested final scan runs against the completed non-security branch state.
