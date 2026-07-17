# App E2E Audit Report: SpaceLens

## Scope and authority

- Audit date: 2026-07-17.
- Source: `feat/andrzej_end-to-end-audit` in an isolated worktree; the user's primary checkout was not modified.
- Product: native SwiftUI macOS app, deployment target macOS 14+, bundle identifier `com.rsitech.spacelens`.
- Toolchain: macOS 27, Xcode 26.6 (17F113), Swift 6.3.3.
- Runtime artifact: `/private/tmp/SpaceLens-end-to-end-audit-20260717/dist/SpaceLens.app`.
- Cleanup boundary: the native smoke used only a disposable fixture and stopped the product cleanup flow at the exact-path confirmation and Cancel. Existing automated cleanup integration tests use unique disposable files only.

## Official documentation baseline

- [Apple: Accessing files from the macOS App Sandbox](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox)
- [Apple: Security-scoped resource access](https://developer.apple.com/documentation/foundation/url/startaccessingsecurityscopedresource%28%29)
- [Apple: Focused values](https://developer.apple.com/documentation/swiftui/focusedvalues)
- [Apple: Focused scene values](https://developer.apple.com/documentation/swiftui/view/focusedscenevalue%28_%3A_%3A%29)
- [Apple: Command groups](https://developer.apple.com/documentation/swiftui/commandgroup)
- [Apple: ContentUnavailableView](https://developer.apple.com/documentation/swiftui/contentunavailableview)
- [Apple: Reduce Motion environment value](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion)
- [Apple: Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)

SpaceLens keeps filesystem access user-selected and security-scoped, persists only a bookmark and app-owned session data, performs analysis locally with deterministic rules, and uses recoverable Bin cleanup. It has no analytics SDK, account system, external inference service, or third-party package dependency.

## Findings and retained fixes

| Severity | Area | Reproduced failure | Retained fix | Verification |
| --- | --- | --- | --- | --- |
| High | Cleanup safety | A queue could contain a directory and its descendant, double-count projected bytes, and later target a child already moved with its parent. | Canonicalize once, component-sort, and collapse descendants to the smallest independent roots while preserving presentation order. | Queue, persistence, statistics, identity, and 2,004-input canonicalization regressions. |
| High | Authorization/state | Starting a scan under a different security-scoped root left stale results and queued targets actionable. | Clear stale scan-owned state only after access to the new root succeeds. | `AppStateScanTests.testStartingScanForDifferentRootClearsStaleResultsAndQueue`. |
| High | Restored scan flow | After relaunch, Rescan ignored the resolved bookmark and opened the folder picker again. | Use one `authorizedScanRoot` for full rescan, smart scan, and cleanup boundaries. | Restored-session regression plus quit/relaunch native Rescan: no picker, exact queue restored. |
| High | Classification | Any old `.log`, including a document in `Documents`, became cleanup-ready. | Require both age and a known temporary/cache location; otherwise classify the log as review-only. | Rule-engine regression and fixture projection. |
| High | SwiftUI state flow | Selection, search, filters, queue changes, and restored sidebar selection synchronously republished derived caches during view updates. | Keep projections non-publishing, update the observable transaction once, normalize selection there, and defer restored sidebar writes one main-run-loop turn. | Publisher-count regressions and native interaction replay with no app-subsystem diagnostic. |
| Medium | Layout | The filter label collapsed and the control row became cramped at ordinary and minimum widths; computed scan-bar widths could become negative. | Stack controls below 1,120 points, hide only the picker's visual label while retaining its accessibility label, and clamp computed widths to zero. | Layout-policy tests; zoomed and actual minimum 825 x 674 native sweeps. |
| Medium | Accessibility | Continuous scan animation ignored Reduce Motion, and Cmd-F did not focus search. | Switch to a static scan equivalent under Reduce Motion and expose a focused scene action through the standard Find command. | Motion-policy tests and native Cmd-F focus/filter proof. |
| Medium | Empty/recovery states | Zero-result categories reused generic messaging, toolbar actions lacked explanations, trust copy said vague `Local intelligence`, and Help had no direct support action. | Add category/search/filter-aware empty states, concise help text, accurate local rule-based copy, and a verified direct support link. | Presentation/support tests and native sidebar, toolbar, and Settings sweep. |
| Medium | Project integrity | SwiftPM compiled new source files while the checked-in Xcode project omitted them, causing the production Xcode build to fail. | Regenerate the project from `project.yml` and keep the generated diff checked in. | Fresh Xcode Debug test, analyze, and universal Release build. |
| Medium | Error honesty | Smart-scan enumerator errors were silently discarded. | Accumulate discovery errors while continuing enumeration. | `SmartCleanupScannerTests.testSmartScanCountsDiscoveryPermissionErrors`. |
| Polish | Build logs | App Store validation selected an ambiguous macOS destination. | Select the host architecture explicitly. | Readiness validation without duplicate-destination output. |

## Automated and static verification

| Gate | Result |
| --- | --- |
| SwiftPM tests, warnings as errors | 70 tests, 0 failures |
| SwiftPM Release build, warnings as errors | Passed |
| Xcode Debug tests | 70 tests, 0 failures |
| Xcode analyze | Passed |
| Fresh Xcode universal Release build | Passed |
| Generated-project/build-and-run verification | Passed |
| Shell syntax | `bash -n script/*.sh` passed |
| Secret and private-key signature scan | No repository match |
| Source debt/unsafe construct scan | No `TODO`, `FIXME`, `HACK`, forced try/cast, `fatalError`, or debug-print match |
| Support integration | `https://www.rsitech.ai/spacelens/support` returned HTTP 200 |

The clean-tree repository readiness script passed for the remediation commit: metadata and entitlements parsed, the generated Xcode project matched source of truth, 70 SwiftPM tests passed, the Xcode build succeeded, the privacy manifest was embedded unchanged, the binary was universal, and bundle version 1.0 (1) matched `project.yml`.

Xcode invokes its App Intents metadata processor and reports that extraction is skipped because SpaceLens has no AppIntents dependency. SpaceLens does not implement App Intents; the build and analyzer complete successfully.

## Native end-to-end evidence

Fixture: `/private/tmp/SpaceLens-PQ-20260717.IqSdbM`, with a `.build` directory, a disposable temporary log, a review-only document log, ordinary files, an empty directory, and a symlink.

| Scenario | Actual | Status |
| --- | --- | --- |
| Full scan | 10 items, 1 MB, 0 errors; symlink not followed | Passed |
| Classification | Three independent cleanup roots: `.build`, `financial-audit.log`, and `Documents/important.log`; document log remains review-only until explicitly selected | Passed |
| Search and categories | Cmd-F focused search; `important` produced one row; Scan Errors showed contextual main and inspector empty states | Passed |
| Queue and confirmation | Select All produced three exact roots; Move to Bin listed all paths; Cancel left the fixture intact | Passed |
| Restored session | Quit/relaunch, then Rescan reused the bookmark without a picker and restored the three queue roots | Passed |
| Settings/support | Privacy & Help displayed the live `Open SpaceLens Support` action | Passed |
| Window adaptation | Zoomed and actual minimum 825 x 674 layouts remained readable with reachable controls | Passed |
| Runtime health | No crash; no app-originated warning, error, or fault under subsystem `com.rsitech.spacelens` | Passed |

### Runtime-log classification

The global macOS log is not completely silent. Accessibility inspection of any minimal SwiftUI window on this host reproducibly emits three AppKit negative-width/height messages; replacing the entire SpaceLens content with one `Text` and testing a separate one-line Xcode SwiftUI app preserved the same signal, while Calculator did not. The signal is therefore classified as a SwiftUI-window/accessibility-harness interaction, not a SpaceLens layout fault. The retained clamp and adaptive-layout fixes still prevent negative values in SpaceLens-owned calculations.

The host also emits Apple-service Core Spotlight donation, BaseBoard task-port, and Xcode-test `linkd.autoShortcut` messages. They are not emitted by the SpaceLens subsystem and do not correlate with a failed product operation. This report deliberately distinguishes that controlled system noise from the clean app-originated log rather than claiming that the entire unified log is clean.

## Code review result

The reviewed surface includes traversal and symlink handling, security-scope lifecycle, cancellation and scan identity, classification precedence, byte accounting, exact cleanup boundaries, session quarantine/restoration, SwiftUI state ownership, accessibility, adaptive layout, scripts, entitlements, privacy metadata, and generated-project consistency.

No unresolved repository-actionable correctness, security, data-loss, maintainability, performance, or accessibility finding remains in the local change set. Cleanup still rejects the authorized root itself, out-of-root paths, symlinks, missing scan identity, and targets whose filesystem identity changed after scanning. Cleanup remains explicit, review-first, and recoverable through the Bin.

## Release and publication status

- Current source label before publication: `runtime-proven`, `repo-ready`.
- Package label: the previously exported signed package predates this remediation and is historical evidence only; the updated source is not claimed `package-ready`.
- Apple review label: not claimed; App Store Connect upload and review are external.
- GitHub label: `blocked:external`. The fresh remediation-head run `29606585215` ended after three seconds without starting a runner or executing any step. Its GitHub check annotation says the job was not started because recent account payments failed or the account spending limit must be increased. The job log is consequently absent (`404 BlobNotFound`).
- Merge status: intentionally not performed. Source, runtime, review, and local readiness gates pass, but changing GitHub billing or spending limits is an owner action and the required hosted gate remains red.
