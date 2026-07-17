# SpaceLens Product Quality Remediation

## Goal

- User-visible outcome: SpaceLens restores its saved scan location without another picker, adapts cleanly at supported widths, respects Reduce Motion, explains empty/recovery states, and completes the scan/queue/cancel flow without app-originated runtime faults.
- Authority boundary: work only in the isolated audit worktree; preserve the primary checkout; use disposable fixtures; stop destructive native flows at Cancel; update and merge PR #10 after the strongest local, runtime, and review gates pass. The owner explicitly waived the account-blocked GitHub Actions signal on 2026-07-17.

## Scope

- Production: scan-root authorization, SwiftUI command/focus flow, adaptive table controls, motion policy, empty states, help and support copy, and generated Xcode project integrity.
- Tests: restored session, empty-state presentation, layout/motion policy, and support URL.
- Evidence: SwiftPM/Xcode gates, native fixture interaction, app-subsystem logs, official Apple documentation, audit report, and exact PR review.
- Non-goals: visual redesign, new classification rules, broader filesystem authority, automatic launch scanning, live cleanup of user files, or App Store upload.

## Milestones

### M1. Restored scan authorization — complete

- Unified full scan, smart scan, and cleanup around `authorizedScanRoot`.
- Added relaunch/bookmark regression coverage.
- Native quit/relaunch Rescan reused the bookmark and restored the exact queue without opening a picker.

### M2. Adaptive layout and accessibility — complete

- Added a deterministic stacked-control breakpoint and nonnegative scan-bar dimensions.
- Preserved an accessible Filter label while avoiding visual compression.
- Added Reduce Motion behavior and standard Cmd-F focused search.
- Verified zoomed and actual minimum 825 x 674 windows.

### M3. Trust, recovery, and project integrity — complete

- Added contextual category/search/filter empty states, toolbar help, accurate rule-based wording, and direct support.
- Regenerated the Xcode project so production Xcode builds include the new sources and tests.
- Verified the support destination returns HTTP 200.

### M4. Verification and publication — complete

- Fresh SwiftPM and Xcode suites pass 70/70 with warnings as errors; Xcode analyze and SwiftPM Release pass.
- The verified app rebuild launched at the actual minimum 825 x 674 window size, the disposable fixture remained intact, and the app subsystem emitted no diagnostic.
- Generated-project regeneration, shell syntax, source-debt scan, diff hygiene, exact remote/local file reconciliation, and review-thread reconciliation pass.
- GitHub Actions remains account-blocked before runner allocation. The owner explicitly directed that this signal not block completion or merge.

## Decisions

- Preserve explicit user-initiated scanning; saved authorization removes redundant selection but does not trigger automatic disk work.
- Treat security-scoped access as one boundary and retain balanced start/stop behavior in the scan service.
- Provide static scan feedback under Reduce Motion rather than removing status feedback.
- Classify the three geometry pairs as controlled SwiftUI/accessibility-harness noise only after minimal reproduction ruled out SpaceLens content, commands, window constraints, package path, and build lane. Keep SpaceLens-owned width clamps regardless.
- Distinguish a clean `com.rsitech.spacelens` subsystem from unrelated Apple-service messages; do not describe the entire unified log as silent.
- Treat the old signed package as historical because it does not contain the current remediation.
- Preserve the GitHub account-level failure in the audit, but do not treat a job that ran zero repository steps as a code finding after the owner explicitly waived it.

## Verification

- `swift test -Xswiftc -warnings-as-errors`
- `swift build -c release -Xswiftc -warnings-as-errors`
- Xcode Debug tests and Release analyze
- `./script/build_and_run.sh --verify`
- `./script/validate_app_store_readiness.sh`
- `bash -n script/*.sh`, secret/debt scans, project regeneration, and `git diff --check`
- Native: scan, search/filter/categories, queue, confirmation Cancel, support, relaunch/rescan restore, zoomed/minimum windows, fixture integrity, and scoped unified logs
- Pull request: exact remote/local file list, mergeability, and unresolved review threads

## Rollback / recovery

- If a regression appears after merge, revert only the intentional PR commits through a new reviewed change; never discard unrelated primary-checkout work.
- Keep the audit evidence and disposable fixture paths available for a focused reproduction before rollback.
