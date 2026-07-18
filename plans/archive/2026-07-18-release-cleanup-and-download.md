# SpaceLens Release Cleanup and Download

## Goal

- User-visible outcome: the repository contains only current, relevant release material; the latest verified SpaceLens app is packaged as a portable universal macOS download; and the cleanup reaches `main` through a reviewed pull request.
- How to see it working: inspect the merged repository, download the published ZIP, verify its checksum and metadata, extract it, and launch the contained `SpaceLens.app` successfully.

## Current State

- Relevant paths: repository root, `dist/`, `docs/release/`, release scripts, GitHub releases, and the existing product-quality audit.
- Existing behavior: PR #10 is merged at `130aa93`; source/runtime gates passed; an older `dist/final` artifact exists in the primary checkout history but predates the latest fixes.
- Constraints: work in `/private/tmp/SpaceLens-release-cleanup-20260718` on `feat/andrzej_release-cleanup`; preserve the primary checkout and its untracked `docs/monetization/` and `docs/superpowers/`; remove only proven obsolete generated or release files; do not upload to App Store Connect or perform Apple account mutations.

## Target State

- Desired behavior: one canonical current release artifact set with app, ZIP, checksum, and build provenance; obsolete release residue removed; source and release docs agree; PR reviewed and merged; download URL verified.
- Non-goals: changing product features, deleting user drafts, App Store submission, TestFlight distribution, or inventing Developer ID/notarization proof.

## Risks and Failure Modes

- Cleanup could remove a canonical release dossier or user-authored source rather than generated residue.
- A ZIP could contain stale source, the wrong architectures, wrong version metadata, or an invalid signature.
- A public download could be described as notarized when only ad-hoc or App Store signing was proved.
- The primary dirty checkout could be disturbed by branch synchronization or cleanup.

## Milestones

### M1. Inventory and baseline

- Goal: classify every release/artifact candidate before removal.
- Files / systems: tracked tree, ignored/untracked files, GitHub releases/tags, signing identities, release scripts.
- Changes: none.
- Verification: exact-path inventory, sizes, provenance, Git status, baseline tests, Apple release doctor/inspect.
- Expected result: explicit keep/remove/rebuild list and truthful distribution route.

### M2. Safe repository cleanup

- Goal: remove only obsolete tracked release residue and normalize current release documentation/scripts.
- Files / systems: paths proven obsolete in M1.
- Changes: apply the smallest cleanup diff; preserve canonical source, audit, release dossier, and user drafts.
- Verification: `git diff --check`, no broken references, regenerated project unchanged, tests pass.
- Expected result: coherent reviewable cleanup diff with no product regression.

### M3. Latest downloadable app

- Goal: build one immutable current universal release artifact set.
- Files / systems: Release build, app bundle, ZIP, checksum, provenance note, runtime smoke.
- Changes: create artifacts from the exact reviewed commit in a clean staging directory; never overwrite prior evidence until the new artifact passes.
- Verification: bundle/version/minimum OS, `arm64 x86_64`, privacy manifest, signature classification, ZIP contents, SHA-256, extraction, launch, and scoped logs.
- Expected result: digest-bound download candidate that matches reviewed source.

### M4. PR review, merge, and publication

- Goal: land cleanup through a reviewed PR and make the exact merged artifact downloadable.
- Files / systems: Git branch, PR, remote `main`, GitHub release/download asset.
- Changes: commit intentional files, push branch, create/update PR, reconcile review threads, merge after local gates, publish exact artifact asset.
- Verification: remote/local diff parity, merge commit tree identity, release asset digest and HTTP accessibility.
- Expected result: merged `main` and a working download link with explicit signing/notarization status.

## Verification

- `swift test -Xswiftc -warnings-as-errors`
- `swift build -c release -Xswiftc -warnings-as-errors`
- Xcode Debug tests and Release analyze/build
- `./script/validate_app_store_readiness.sh`
- `bash -n script/*.sh`
- App bundle metadata, architectures, signature, privacy manifest, ZIP listing, SHA-256, extracted launch smoke, and app-subsystem logs
- PR head/base reconciliation, unresolved review threads, merged-tree identity, and published asset download checksum

## Decision Log

- 2026-07-18: Isolate the task from the dirty primary checkout using a fresh `origin/main` worktree.
- 2026-07-18: Treat the latest source as authoritative; older runnable/package artifacts are evidence only and must not be relabeled as current.
- 2026-07-18: Public download signing/notarization claims require artifact proof; otherwise publish as a verified runnable ZIP with the exact limitation stated.
- 2026-07-18: Keep the current July end-to-end audit, README capture, App Store feature capture, privacy map, review flow, release notes, and concise release status. Remove the superseded June audit, its two captures, six other unreferenced captures, and stale point-in-time release/account dossiers.
- 2026-07-18: Remove private App Review contact fields from repository metadata and keep owner-controlled account state in App Store Connect.
- 2026-07-18: No `notarytool` Keychain profile is installed. The direct-download builder therefore proves Developer ID signing and hardened runtime but records notarization as not submitted; it must not make a notarization claim.

## Progress Log

- 2026-07-18: Worktree created at `130aa93`; primary checkout preserved.
- 2026-07-18: Baseline warnings-as-errors SwiftPM suite passed 70 of 70 tests. Apple release inspection found Xcode 26.6, bundle `com.rsitech.spacelens`, team `2NY8A789TN`, and an available Developer ID Application identity.
- 2026-07-18: Inventory completed. Repository cleanup and the reproducible direct-download builder were implemented test-first; the targeted release-packaging suite passed 2 of 2 tests after the expected missing-script failure.
- 2026-07-18: Xcode project regenerated with the new packaging tests. Warnings-as-errors SwiftPM tests passed 72 of 72; SwiftPM Release, Xcode tests 72 of 72, Xcode Release analysis, and universal Release build passed. Plists, shell syntax, public Support/Privacy HTTP 200, references, and private-contact scans passed.
- 2026-07-18: Xcode 26.6 reports that App Intents metadata extraction was skipped because the app has no AppIntents dependency. This is an expected optional-tool diagnostic, not a compiler warning or missing product dependency; the internal warning filter remains disabled so future meaningful metadata warnings stay visible.
- 2026-07-18: Repository implementation is ready for a clean source commit. The readiness wrapper's pre-commit generated-project check stopped only because the new generated project reference was not yet in `HEAD`; rerun it from the clean commit before packaging.

## Rollback / Recovery

- If cleanup classification is uncertain, retain the file and record it as review-only.
- If packaging fails, keep repository cleanup separate and do not publish a partial or stale asset.
- If a published asset digest mismatches, remove only that exact new asset and preserve the immutable local candidate for diagnosis.
- Revert only intentional cleanup commits through a new PR; never reset or discard unrelated user work.
