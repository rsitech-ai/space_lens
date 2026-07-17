# App E2E Audit Report: SpaceLens

## Scope and decision boundary

- Audit date: 2026-07-17.
- Source: `feat/andrzej_end-to-end-audit`, isolated from the user's primary checkout.
- Product: native SwiftUI macOS app, deployment target macOS 14+, bundle identifier `com.rsitech.spacelens`.
- Toolchain exercised: macOS 27, Xcode 26.6 (17F113), Swift 6.3.3.
- Runtime artifact: `/private/tmp/SpaceLens-end-to-end-audit-20260717/dist/SpaceLens.app`.
- Cleanup authority: real user files were never touched. UI cleanup stopped at the exact-path confirmation and Cancel. A separate automated integration test moved only a unique disposable test file to the Bin and removed that test artifact afterward.

## Official documentation baseline

- [Apple: Accessing files from the macOS App Sandbox](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox)
- [Apple: NSURL bookmarks and security-scoped URLs](https://developer.apple.com/documentation/foundation/nsurl)
- [Apple: Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)
- [Apple: Adding a privacy manifest to an app](https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk)
- [Apple: Describing use of required-reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
- [Apple: Restoring an app's state with AppKit](https://developer.apple.com/documentation/appkit/restoring-your-app-s-state-with-appkit)

The implementation continues to use user-selected file access, a security-scoped bookmark for relaunch authorization, App Sandbox entitlements, a local privacy manifest, and `FileManager.trashItem` for recoverable cleanup. No network dependency, analytics SDK, account system, or external inference service is present.

## Findings and retained fixes

| Severity | Area | Reproduced failure | Retained fix | Verification |
| --- | --- | --- | --- | --- |
| High | Cleanup safety | A queue could contain a directory and its descendant, double-count projected bytes, and later target a child already moved with its parent. The scan summary also showed 2.1 MB recoverable from a 1.1 MB fixture. | Normalize selected, queued, restored, and statistical candidates to the smallest non-overlapping cleanup roots. | Red/green queue, persistence, and statistics regressions; final UI reports 1.1 MB total and 1.1 MB recoverable across two cleanup roots. |
| High | Authorization/state | Starting a scan under a different security-scoped root left old results and queued targets actionable. | Clear the prior scan, selection, queue, statistics, intelligence summary, and pending restored paths only after access to the new root succeeds. | `AppStateScanTests.testStartingScanForDifferentRootClearsStaleResultsAndQueue`. |
| High | Classification | Any old `.log`, including a document in `Documents`, became cleanup-ready. | Require both age and a known temporary/cache location; otherwise classify the log as review-only. | `RuleEngineTests.testOldLogInUserDocumentsStillRequiresReview`; disposable `/private/tmp` log remains correctly queueable. |
| High | SwiftUI state flow | Selection, search, filters, queue changes, and AppKit-restored sidebar selection synchronously republished derived `@Published` caches during view updates. Unified logs recorded repeated undefined-behavior faults. | Make projection updates one explicit observable transaction, keep derived caches non-publishing, normalize selection within that transaction, and defer SwiftUI sidebar binding writes to the next main-run-loop turn. | Publisher-count regressions plus a fresh native scan/search/sidebar/select/queue replay with zero `Publishing changes from within view updates` entries. Relaunch now starts on `All Files`. |
| Medium | Error honesty | Smart-scan enumerator errors were silently discarded. | Accumulate discovery errors while continuing enumeration. | `SmartCleanupScannerTests.testSmartScanCountsDiscoveryPermissionErrors`. |
| Polish | Build logs | App Store validation selected an ambiguous macOS destination and emitted duplicate-destination warnings. | Select the host architecture explicitly. | Readiness validation rerun without the destination warning. |
| Polish | Maintainability | An unused test-only cleanup progress recorder remained in the suite. | Remove the dead helper. | Static search and warnings-as-errors build. |

## Automated and static verification

| Gate | Result | Evidence |
| --- | --- | --- |
| SwiftPM tests, warnings as errors | 60 tests, 0 failures | `/private/tmp/SpaceLens-swift-test-final-20260717.log` |
| SwiftPM Release build, warnings as errors | Passed | `/private/tmp/SpaceLens-swift-release-final-20260717.log` |
| Xcode Debug clean test, warnings as errors | 60 tests, 0 failures | `/private/tmp/SpaceLens-xcode-test-final-20260717.log` |
| Xcode Release clean analyze, warnings as errors | Passed | `/private/tmp/SpaceLens-xcode-analyze-final-20260717.log` |
| App Store metadata/readiness | Passed; version 1.0 (1); generated project unchanged | `/private/tmp/SpaceLens-app-store-readiness-final-20260717.log` |
| Shell syntax | Passed for every script | `bash -n script/*.sh` |
| Secret/material scan | No credential or private-key matches | Repository-local `rg` signature scan |
| Unsafe/debt scan | No source `TODO`, `FIXME`, forced cast, forced try, or fatal-error match | Repository-local `rg` scan |
| Dependencies | No third-party package dependency | `Package.swift` and generated Xcode project inspection |
| Signing identities | Apple Development, Apple Distribution, Mac Installer Distribution, and Developer ID Application identities present | `security find-identity` |

Xcode 26.6 invokes the App Intents metadata processor for this SwiftUI app and prints `Metadata extraction skipped. No AppIntents.framework dependency found.` SpaceLens does not implement App Intents, and the build/analyzer/readiness command succeeds. This is an Xcode tool step, not a source diagnostic or missing product integration.

## Native end-to-end evidence

Fixture: `/private/tmp/SpaceLens-E2E-20260717.gjdYOR`, containing a 1 MiB `.build` artifact, an old disposable log, ordinary source/documents, an empty directory, and a symlink.

| Scenario | Expected | Actual | Status |
| --- | --- | --- | --- |
| Fresh launch | Honest unscanned state | `No Scan Yet`, zero queue, disabled Cancel/Reveal actions | Passed |
| Full fixture scan | Do not follow symlink; truthful totals | 10 items, 1.1 MB, 0 errors, 2 independent cleanup roots, 1.1 MB recoverable | Passed |
| Safe selection | Parent/child rows may be visibly selected but cleanup roots and bytes must collapse | 3 visible rows selected, 2 cleanup-ready roots, 1.1 MB | Passed |
| Sidebar projections | Seven categories consistently project the table | Safe 3, Review 6, Valuable 0, Active 0, Errors 0, Queue 2; All 9 visible | Passed |
| Search and filters | Update rows and prune stale selection | `financial` produced one row; Cleanup Ready produced 2; Large produced 0; folder/file options present and automated projection tests pass | Passed |
| Queue | Add only independent safe roots and persist them | 2 candidates, 1.1 MB projected; quit/relaunch/rescan restored exactly 2 | Passed |
| Cleanup confirmation | Show every exact target and make cancellation safe | Sheet listed `.build` and `financial-audit.log`; Cancel left both intact | Passed |
| Disposable cleanup integration | Move an unchanged authorized descendant to the Bin | Source disappeared, resulting Bin URL existed, unique test artifact was removed | Passed |
| Settings | Product claims match behavior | General and Privacy & Help panes verified; forget-session sheet states it does not delete selected-folder files; Cancel preserves session | Passed |
| Window adaptation | Normal and zoomed layouts remain usable | Compact two-column table and expanded six-column table both readable; controls remained reachable | Passed |
| Relaunch | Start cleanly and restore only app-owned session data | `All Files` on launch; bookmark location retained; queue restored after rescan | Passed |
| Runtime logs | No app crash or unexplained app fault | Zero SwiftUI publishing faults after final launch and interaction replay; no crash report | Passed |

Final screenshot: [fixture scan with safe selection](screenshots/2026-07-17-final-fixture-queue.jpeg).

The macOS 27 development environment also logs failed `linkd.autoShortcut`/Core Spotlight registration and a missing `/private/var/db/DetachedSignatures` database for the ad-hoc development bundle. These messages originate from Apple services, occur before product interaction, and are not accompanied by an app crash or failed SpaceLens feature. The separately signed Xcode and App Store archive lanes are the authoritative packaging gates.

## Code review result

The final source review covered filesystem traversal, symlink and identity validation, security scope lifecycle, cancellation, concurrent scan identity, classification precedence, byte accounting, cleanup boundaries, session quarantine/restoration, SwiftUI source-of-truth flow, accessibility labels, adaptive layout, scripts, entitlements, privacy metadata, and generated-project drift.

No unresolved correctness, security, data-loss, maintainability, or performance finding remains in the reviewed change set. The cleanup path still rejects the authorized root itself, out-of-root paths, symlinks, missing scan identity, and items whose filesystem identity changed after scanning. Cleanup remains explicit, review-first, and recoverable through the Bin.

## Release and publication status

- Repository/runtime label: `runtime-proven` and `repo-ready`; signed archive is the remaining local packaging gate.
- Apple review label: not claimed; App Store Connect upload and review are external.
- GitHub label: branch is local until the final gates pass; PR/check/merge evidence will be recorded here before completion.
