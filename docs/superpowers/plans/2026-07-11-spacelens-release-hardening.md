# SpaceLens 1.0 Release Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce a machine-verified SpaceLens 1.0 build 1 Mac App Store archive, complete repository-owned submission artifacts, and isolate every external blocker precisely.

**Architecture:** Keep SwiftPM as the development/test lane and `project.yml` as the XcodeGen/App Store source of truth. Serialize all repository edits on `feat/andrzej_agent_sota_lab`; read-only agents provide independent evidence, while the release lead integrates fixes and re-verifies every claim.

**Tech Stack:** Swift 6, SwiftUI/AppKit, SwiftPM, XcodeGen, Xcode 26.5, macOS 26.5 SDK, XCTest, shell release scripts, Apple code signing, Mac App Store archive/export.

## Global Constraints

- Shipping platform is macOS only; iOS/watchOS/tvOS/visionOS gates are `NOT APPLICABLE`.
- Preserve macOS 14.0 deployment support.
- Production archive uses Xcode 26.5; Xcode/macOS 27 is a separate compatibility track and cannot be claimed without the unavailable toolchain.
- Preserve local-only processing, no analytics/tracking, and review-first cleanup safety.
- Never test destructive cleanup against real user data.
- Do not submit, release, merge, tag, change storefront/legal/account state, or commit credentials/archives.

---

### Task 1: Freeze the release contract and evidence structure

**Files:**
- Create: `docs/release/1.0/RELEASE_STATUS.md`
- Create: `docs/release/1.0/APP_STORE_CHECKLIST.md`
- Create: `docs/release/1.0/TEST_EVIDENCE.md`
- Create: `docs/release/1.0/PRIVACY_DATA_MAP.md`
- Create: `docs/release/1.0/SECURITY_STATUS.md`
- Create: `docs/release/1.0/APP_REVIEW_NOTES.md`
- Create: `docs/release/1.0/RELEASE_NOTES.md`
- Create: `docs/release/1.0/BLOCKERS.md`
- Create: `docs/release/1.0/RELEASE_MANIFEST.json`

**Interfaces:**
- Consumes: repository configuration, official Apple requirements, local toolchain/account evidence.
- Produces: one canonical gate matrix and evidence paths used by every later task.

- [ ] Record version `1.0`, build `1`, bundle ID `com.rsitech.spacelens`, deployment target `14.0`, installed Xcode/SDK, and official-source check date `2026-07-11`.
- [ ] Add every mission gate with only `PASS`, `FAIL`, `BLOCKED`, `NOT APPLICABLE`, or `NOT YET VERIFIED`, plus command/evidence/owner/next action.
- [ ] Validate JSON syntax with `plutil -lint` or `python3 -m json.tool docs/release/1.0/RELEASE_MANIFEST.json` and expect exit 0.

### Task 2: Run static, build, test, sanitizer, and analysis gates

**Files:**
- Modify if a reproducible failure exists: the smallest relevant file under `Sources/SpaceLens`, `Tests/SpaceLensTests`, `project.yml`, or `script/`.
- Update: `docs/release/1.0/TEST_EVIDENCE.md`

**Interfaces:**
- Consumes: `Package.swift`, `project.yml`, generated Xcode project, existing tests.
- Produces: fresh compiler/test/analyzer/sanitizer evidence and focused regressions for any fix.

- [ ] Run `swift package resolve`, `swift test -Xswiftc -warnings-as-errors`, and `swift build -c release -Xswiftc -warnings-as-errors`; require exit 0 and zero warnings.
- [ ] Run Xcode Debug tests, Release generic-macOS build, and `xcodebuild analyze`; require successful result markers.
- [ ] Run Address Sanitizer and Thread Sanitizer test configurations where the macOS host/test harness supports them; record an exact toolchain blocker instead of weakening settings if unsupported.
- [ ] For each deterministic defect, add one public-behavior regression test, prove RED, implement the minimal fix, then prove GREEN and rerun the parent suite.

### Task 3: Close security, privacy, and supply-chain gates

**Files:**
- Modify if validated: focused source/config/tests only.
- Update: `docs/release/1.0/PRIVACY_DATA_MAP.md`
- Update: `docs/release/1.0/SECURITY_STATUS.md`
- Update: `docs/release/1.0/APP_STORE_CHECKLIST.md`

**Interfaces:**
- Consumes: security scan output, source review, privacy manifest/policy, dependency graph.
- Produces: validated finding dispositions, local data-flow map, privacy-label draft, residual-risk owners.

- [ ] Map file names/paths/sizes/timestamps, bookmarks, cleanup queue, errors, logs, and external support links by source, purpose, storage, retention, deletion, recipient, tracking, and identity linkage.
- [ ] Reconcile the map with `Resources/PrivacyInfo.xcprivacy`, `docs/PRIVACY.md`, release notes, and App Store privacy answers without inventing account-side declarations.
- [ ] Run repository-wide security review plus secret/dependency/license checks; fix Critical/High and release-blocking Medium findings with focused verification.
- [ ] Run the final security diff scan against `origin/main...HEAD` after all changes.

### Task 4: Prove native macOS runtime and accessibility behavior

**Files:**
- Modify if validated: focused SwiftUI/AppState/tests only.
- Create: real-app screenshots under `docs/release/1.0/screenshots/` at an Apple-accepted 16:10 Mac size.
- Update: `docs/release/1.0/TEST_EVIDENCE.md`

**Interfaces:**
- Consumes: `script/build_and_run.sh`, synthetic scan fixture, Computer Use accessibility state.
- Produces: interaction matrix, current screenshots, runtime/log/accessibility/performance evidence.

- [ ] Build and launch with `./script/build_and_run.sh --verify`; confirm the exact process and visible window.
- [ ] Exercise empty state, synthetic folder scan, Smart Scan safety boundaries, search/filter/sort, selection, queue, inspector, Settings, menus, shortcuts, resize, relaunch, and destructive confirmation/cancel paths.
- [ ] Verify Dark/Light, Reduce Motion, increased contrast, keyboard navigation, accessibility names/order, and minimum/typical/large layouts; record unavailable human VoiceOver judgment separately.
- [ ] Inspect unified logs after storage/cleanup flows and capture bounded CPU/RSS plus app-owned retention evidence.
- [ ] Capture truthful 16:10 screenshots from the real current build and validate pixel dimensions.

### Task 5: Produce and inspect the Mac App Store archive

**Files:**
- Modify if validated: `project.yml`, `Config/*`, `Resources/*`, or release scripts.
- Update: `docs/release/1.0/TEST_EVIDENCE.md`
- Update: `docs/release/1.0/RELEASE_MANIFEST.json`

**Interfaces:**
- Consumes: installed team `2NY8A789TN`, Apple Distribution identity, Mac App Store profile, Xcode 26.5.
- Produces: uncommitted `.xcarchive` and exported package plus signing/resource inspection evidence.

- [ ] Run `SPACE_LENS_DEVELOPMENT_TEAM=2NY8A789TN ./script/archive_app_store.sh`; require archive/export success or capture the first exact distribution blocker.
- [ ] Inspect archive Info.plist, app Info.plist, architectures, resources, privacy manifest, entitlements, hardened runtime, certificate chain, profile, nested code, dSYMs, quarantine attributes, and installer signature.
- [ ] Use Apple-supported validation when App Store Connect authentication permits it; never equate archive/export success with App Store validation.
- [ ] Keep `build/`, archives, profiles, signing material, and private logs out of Git.

### Task 6: Complete metadata and review artifacts

**Files:**
- Update: all Markdown/JSON files under `docs/release/1.0/`
- Modify when needed: `docs/APP_STORE.md`, `docs/app-store-release-checklist.md`, `docs/production-plan.md`, `README.md`

**Interfaces:**
- Consumes: verified functionality, current official metadata limits, actual screenshots, account/legal unknowns.
- Produces: truthful submission copy, review instructions, release notes, blocker ledger, exact next action.

- [ ] Draft name, subtitle, promotional text, description, keywords, category, What’s New, review notes, privacy/support URLs, and screenshot inventory from verified behavior.
- [ ] Mark privacy labels, age rating, export compliance, content rights, DSA trader status, pricing, territories, release mode, contact, and App Store Connect record as owner/account confirmations when not verifiable locally.
- [ ] Remove stale readiness claims and reconcile signing-team/version/blocker statements across active docs.

### Task 7: Final review, verification, commit, push, and draft PR

**Files:**
- Update: `docs/release/1.0/RELEASE_STATUS.md`
- Update: `docs/release/1.0/RELEASE_MANIFEST.json`

**Interfaces:**
- Consumes: all final code/docs, security diff review, independent reviewer feedback, GitHub checks.
- Produces: final verdict and reviewable draft PR without merge/tag/release.

- [ ] Re-read this plan and mission, inspect `git diff --check`, `git status`, and `git diff --stat origin/main...HEAD`, and close every gate row with current evidence.
- [ ] Re-run the full test suite, warnings-as-errors Release build, Xcode analyze, App Store validator, signed archive/export, signing/entitlement/resource inspection, runtime smoke, logs, and screenshot dimension checks at the final SHA.
- [ ] Request independent code review for `origin/main...HEAD`, technically validate feedback, and fix all Critical/Important or release-blocking issues.
- [ ] Stage only intentional files, commit cohesive changes, push `feat/andrzej_agent_sota_lab`, and open a draft PR targeting `main`.
- [ ] Inspect PR checks/logs and update the release report with PR URL, head SHA, CI status, exact verdict, remaining human-only decisions, and next submission action.
