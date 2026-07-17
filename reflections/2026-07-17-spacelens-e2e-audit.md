# Reflection: SpaceLens end-to-end audit

## Task

- **ID / title:** 2026-07-17 SpaceLens end-to-end audit and ship gate
- **Date:** 2026-07-17
- **Scope:** Filesystem scan, classification, cleanup queue, session restoration, SwiftUI state flow, packaging, native runtime, and publication gates.
- **Authority boundary:** Local fixes, tests, recoverable disposable cleanup, branch/PR/push/merge as explicitly requested; no real user-file deletion or Apple account mutation.

## Success and risk

- **Success criteria:** Truthful byte/candidate counts, safe authorization boundaries, clean native workflow and logs, warning-free source builds, and merge only after local/hosted gates.
- **Hypothesis 1:** Cleanup candidates overlap or outlive the authorized root.
- **Hypothesis 2:** Broad classification rules make valuable data queueable.
- **Hypothesis 3:** SwiftUI source and derived state publish in conflicting transactions.
- **Rollback path:** Revert the isolated audit commit/PR; the user's primary checkout remains untouched.

## Candidate directions

| Candidate | Expected benefit | Main risk | Evidence before choice | Decision |
| --- | --- | --- | --- | --- |
| Normalize cleanup roots once and reuse the utility | Consistent selection, queue, restore, and statistics semantics | Incorrect path containment could omit valid siblings | UI showed recoverable bytes larger than total; red parent/child tests | Retained with canonical component-boundary checks |
| Patch each call site independently | Smaller local diffs | Semantics drift and repeated bugs | Four consumers needed identical behavior | Rejected |
| Make derived SwiftUI values computed on every render | Eliminates nested publishers | Repeated filtering/classification over large scans | Runtime faults came from synchronous derived publishers | Partially retained only for small selected-root derivation |
| Use one observable transaction and non-publishing cached projections | Preserves performance and fixes update ordering | Requires explicit source setters | Publisher-count tests measured 3-6 events per mutation | Retained |

## Evidence

- **First meaningful failure signal:** The running fixture reported 2.1 MB recoverable from 1.1 MB total.
- **Commands or runtime checks:** Red/green focused tests, full SwiftPM/Xcode suites, native Computer Use workflow, exact unified-log queries, App Store readiness validation, signed identity inspection, and static signature scans.
- **What the evidence ruled in or out:** The UI discrepancy ruled in overlapping parent/child accounting. Exact runtime timestamps tied SwiftUI faults to synchronous projection publishing and restored sidebar binding writes, not scan concurrency or a crash.

## Decision

- **Root cause or remaining unknown:** Cleanup semantics were duplicated across consumers, and `@Published` property observers synchronously published additional derived properties while SwiftUI was updating views.
- **Retained fix / direction:** Shared cleanup-root normalization; one observable transaction per projection mutation; selection pruning inside that transaction; deferred sidebar binding writes; location-sensitive log safety; honest scan error accumulation.
- **Post-review hardening:** The first shared normalizer fixed correctness but performed quadratic comparisons and repeated filesystem canonicalization. The reviewed implementation canonicalizes once per input and uses a prefix-aware sorted traversal; a 2,004-input regression locks that boundary down.
- **Why alternatives were rejected:** Per-call-site normalization would drift; fully computed large projections would move scan-sized work into rendering; suppressing logs would hide undefined behavior.
- **Residual risk:** Xcode/macOS development services emit App Intents/Core Spotlight noise for the development bundle. The signed App Store archive passed; hosted CI remains a separate publication gate.
- **Rollback trigger:** Any regression in scan responsiveness, selection synchronization, cleanup containment, signed archive validation, or hosted checks.

## Reusable lesson

- **Pattern to retain:** Treat selected cleanup rows as a filesystem antichain and assert recoverable bytes never exceed scanned bytes.
- **Pattern to avoid:** Mutating one `@Published` property from another `@Published` property's observer when SwiftUI owns a binding to the source.
- **Where it applies next:** Native file-management apps with hierarchical selection, cached projections, and persisted authorization.
