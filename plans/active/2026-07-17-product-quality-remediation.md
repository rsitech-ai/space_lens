# SpaceLens Product Quality Remediation

## Goal

- User-visible outcome: SpaceLens restores its saved scan location without another picker, adapts cleanly at supported widths, respects Reduce Motion, explains empty/recovery states, and completes the scan/queue/cancel flow without app-originated runtime faults.
- Authority boundary: work only in the isolated audit worktree; preserve the primary checkout; use disposable fixtures; stop destructive native flows at Cancel; update and merge PR #10 only after local and hosted gates pass.

## Scope

- Production: scan-root authorization, SwiftUI command/focus flow, adaptive table controls, motion policy, empty states, help and support copy, and generated Xcode project integrity.
- Tests: restored session, empty-state presentation, layout/motion policy, and support URL.
- Evidence: SwiftPM/Xcode gates, native fixture interaction, app-subsystem logs, official Apple documentation, audit report, and hosted PR checks.
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

### M4. Verification and publication — in progress

- SwiftPM/Xcode suites, analyze, Release, build-and-run, native smoke, and app-subsystem logs pass.
- Remaining: final post-edit verification, commit, clean-tree readiness, push, hosted check, exact PR review, conditional merge.

## Decisions

- Preserve explicit user-initiated scanning; saved authorization removes redundant selection but does not trigger automatic disk work.
- Treat security-scoped access as one boundary and retain balanced start/stop behavior in the scan service.
- Provide static scan feedback under Reduce Motion rather than removing status feedback.
- Classify the three geometry pairs as controlled SwiftUI/accessibility-harness noise only after minimal reproduction ruled out SpaceLens content, commands, window constraints, package path, and build lane. Keep SpaceLens-owned width clamps regardless.
- Distinguish a clean `com.rsitech.spacelens` subsystem from unrelated Apple-service messages; do not describe the entire unified log as silent.
- Treat the old signed package as historical because it does not contain the current remediation.
- Never merge around a red hosted gate; a zero-step/no-log job is `blocked:external`, not a local pass.

## Verification

- `swift test -Xswiftc -warnings-as-errors`
- `swift build -c release -Xswiftc -warnings-as-errors`
- Xcode Debug tests, analyze, and fresh universal Release build
- `./script/build_and_run.sh --verify`
- `./script/validate_app_store_readiness.sh` after the generated project is committed
- `bash -n script/*.sh`, secret/debt scans, and `git diff --check`
- Native: scan, search/filter/categories, queue, confirmation Cancel, support, relaunch/rescan restore, zoomed/minimum windows, and scoped unified logs
- GitHub: fresh Actions result and exact PR diff/review before merge

## Rollback / recovery

- The remediation is isolated to one feature branch and worktree. Revert only its intentional commit if a regression appears; never discard unrelated primary-checkout work.
- If hosted infrastructure again creates a zero-step/no-log failure, preserve the evidence and stop before merge.
