# SpaceLens End-to-End Audit and Ship Gate

## Goal

- User-visible outcome: SpaceLens is audited against its documented behavior, current Apple guidance, repository standards, and real macOS runtime behavior; validated defects are fixed; the resulting branch is reviewed and shipped through a pull request only if all required gates pass.
- How to see it working: fresh builds and tests pass without warnings, the app launches through the project script, fixture-backed scan and cleanup workflows behave truthfully in the native UI, logs remain free of unexplained errors, and the audit report records evidence and any external blockers.

## Current State

- Relevant paths: `Sources/SpaceLens/`, `Tests/SpaceLensTests/`, `project.yml`, `Package.swift`, `script/`, `docs/release/1.0/`, and `docs/production-plan.md`.
- Existing behavior: SpaceLens is a native macOS SwiftUI disk-inspection and cleanup app with SwiftPM and Xcode project lanes, an App Sandbox configuration, fixture-oriented tests, a build/run script, and historical 1.0 release evidence.
- Constraints: the primary checkout contains unrelated untracked monetization and planning drafts and must remain untouched. Work is isolated in `/private/tmp/SpaceLens-end-to-end-audit-20260717` on `feat/andrzej_end-to-end-audit`. No real user files may be deleted; destructive UI is limited to confirmation/cancel and disposable audit fixtures. Push, PR creation, review, and merge are authorized by the user, but GitHub tooling and hosted checks must still be available and green.

## Target State

- Desired behavior: architecture and data flow are internally consistent; boundary inputs are validated; scanning, classification, queueing, cleanup, persistence, navigation, settings, error states, and relaunch behavior match product intent; privacy, sandbox, signing, accessibility, performance, and logging are release-grade; no known blocker/high correctness issue remains.
- Non-goals: adding new product features, changing monetization, deleting user data, changing Apple or GitHub account configuration, or claiming Apple review approval.

## Risks and Failure Modes

- Filesystem traversal, symlink, permission, race, and size-accounting edge cases can produce incorrect or unsafe cleanup decisions.
- SwiftUI state and background scanning can race, update off-main, retain stale selections, or misreport empty/error results.
- Historical release evidence can mask toolchain, signing, package, or runtime drift.
- Native UI controls may compile but be unreachable, ambiguous, clipped, or inconsistent under resize, keyboard, accessibility, and relaunch.
- GitHub CLI is absent; connector availability or hosted CI may block PR creation or merge despite repo-local success.

## Milestones

### M1. Baseline and contract map

- Goal: establish current source, Git, project, toolchain, and product-contract truth.
- Files / systems: repository metadata, README, production/release docs, SwiftPM/Xcode manifests, scripts, official Apple documentation.
- Changes: none except this plan and audit scaffolding.
- Verification: Git status/diff, scheme/package discovery, toolchain versions, repository instruction scan, and current official documentation links.
- Expected result: a bounded workflow and API/architecture map with no user changes at risk.

### M2. Static and test audit

- Goal: inspect implementation line by line at risk boundaries and run stronger-than-existing automated checks.
- Files / systems: all Swift sources and tests, plist/entitlements/privacy manifest, build scripts and project generation.
- Changes: add focused regression tests and minimal fixes only for reproduced findings.
- Verification: `swift test -Xswiftc -warnings-as-errors`, Xcode build/test/analyze with isolated DerivedData, project regeneration drift check, shell syntax checks, and targeted edge-case tests.
- Expected result: zero unexplained warnings/failures and explicit coverage of validated edge cases.

### M3. Native runtime and E2E sweep

- Goal: prove the app visibly launches and its reachable workflows behave correctly.
- Files / systems: built `.app`, disposable fixtures, native UI, unified logs, app persistence.
- Changes: smallest coherent fixes for runtime or UI findings.
- Verification: `./script/build_and_run.sh --verify`, native interaction matrix covering launch/relaunch, navigation, scan states, queue/cancel paths, settings, menus/shortcuts, resizing, hover/help, and logs after high-risk actions.
- Expected result: interaction-clean runtime with truthful empty/success/error behavior and no unexplained app log errors.

### M4. Release, security, performance, and maintainability gates

- Goal: validate sandbox/privacy/signing/package assumptions and complete a full code review.
- Files / systems: release scripts, entitlements, privacy manifest, archive/package, performance and log evidence, complete branch diff.
- Changes: hardening fixes and documentation/evidence updates when required.
- Verification: App Store readiness script, archive/package checks where local identities permit, signature/entitlement inspection, dependency/secret/dead-code scans, launch/scan timing and resource sanity, and diff-based review.
- Expected result: `ready`, `ready with noted risk`, or `not ready` decision backed by exact evidence.

### M5. PR and merge gate

- Goal: publish only an approved, stable, reviewable change set.
- Files / systems: Git branch, GitHub PR, hosted checks and review state, `main`.
- Changes: archive this plan, commit intentional files, push branch, create a ready-for-review PR, inspect the PR diff/checks, resolve findings, and merge only when required checks are green.
- Verification: clean branch status, fresh full verification after final fixes, PR diff matches local intent, hosted checks/review state, and post-merge `origin/main` confirmation.
- Expected result: merged `main` when all gates pass, otherwise an exact external blocker without overstating readiness.

## Verification

- `swift test -Xswiftc -warnings-as-errors`
- `xcodebuild -project SpaceLens.xcodeproj -scheme SpaceLens -configuration Debug -derivedDataPath /private/tmp/SpaceLens-DD-debug clean build test`
- `xcodebuild -project SpaceLens.xcodeproj -scheme SpaceLens -configuration Release -derivedDataPath /private/tmp/SpaceLens-DD-release clean analyze`
- `bash -n script/*.sh`
- `./script/build_and_run.sh --verify`
- `./script/validate_app_store_readiness.sh`
- Manual smoke: disposable non-empty, empty, unreadable/permission, symlink, queue/cancel/cleanup, navigation, settings, resize, keyboard/menu, and quit/relaunch scenarios with native UI evidence and post-action logs.

## Decision Log

- 2026-07-17: Use a separate worktree because the primary checkout contains unrelated untracked drafts.
- 2026-07-17: Treat historical 1.0 release artifacts as context, never as current verification.
- 2026-07-17: Permit cleanup only inside a disposable audit fixture; do not delete user data.
- 2026-07-17: Treat GitHub availability and hosted checks as external gates; do not merge around failures.

## Progress Log

- 2026-07-17: Completed session bootstrap, skill routing, memory/context review, initial Git inventory, and isolated branch creation.
- 2026-07-17: Completed source/contract mapping, official Apple documentation review, static scans, build/test/analyze baselines, and App Store metadata validation.
- 2026-07-17: Reproduced and fixed overlapping cleanup roots/byte inflation, stale-root authorization state, over-broad old-log safety, silently discarded smart-scan errors, ambiguous validation destination selection, and nested SwiftUI projection publishing.
- 2026-07-17: Completed fixture-backed native launch, scan, search/filter, seven-category sidebar, selection, queue, exact-path confirmation/cancel, settings, resize, and quit/relaunch/queue-restoration proof. A disposable cleanup integration test exercised the successful Bin path.
- 2026-07-17: Final native replay is free of app runtime-issue faults. Final SwiftPM/Xcode test, build, analyze, App Store readiness, shell, secret, and debt gates passed.
- 2026-07-17: Signed App Store archive/export passed from `ef75269f6c0128424860100668ca1453290753a4`; the exported package and embedded app passed signature, entitlement, privacy-manifest, architecture, dSYM, provisioning-profile, and provenance checks.
- 2026-07-17: Published ready-for-review PR #10. Its first hosted workflow completed as a failure without exposing any job steps or downloadable logs; the final evidence commit will retrigger the workflow before the merge decision.
- 2026-07-17: PR review identified quadratic cleanup-root normalization. Replaced it with canonicalize-once component sorting and prefix collapse; a 2,004-input regression, 61-test SwiftPM/Xcode suites, Release build/analyze, and signed archive from reviewed source `6c92bc6cd79731251ffa139f0d7bbbee8fe42b8d` all passed. The review thread is resolved.

## Rollback / Recovery

- If this fails: leave the primary checkout unchanged; stop the audit app; preserve logs and the branch for inspection; report the first exact blocker.
- Safe fallback: abandon the isolated worktree and branch only after confirming no unique evidence or intentional fixes would be lost. Never reset or discard the user's primary checkout.
