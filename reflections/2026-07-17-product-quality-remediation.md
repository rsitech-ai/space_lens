# Reflection: SpaceLens product-quality remediation

## Task

- **ID / title:** SpaceLens end-to-end remediation and PR gate
- **Date:** 2026-07-17
- **Scope:** Restored scans, adaptive SwiftUI layout, accessibility/recovery polish, Xcode project parity, runtime evidence, and PR publication.
- **Authority boundary:** Isolated branch/worktree; disposable fixtures; native cleanup confirmation cancelled; merge only after green local and hosted gates.

## Success and Risk

- **Success criteria:** Correct restored authorization, stable native flow, accurate user-facing states, warning-free repository builds, app-originated logs clean, reviewed PR green before merge.
- **Hypothesis 1:** The negative geometry log came from the compressed SpaceLens control row.
- **Hypothesis 2:** A SpaceLens window constraint or command/configuration path emitted the geometry log independently of content.
- **Hypothesis 3:** The accessibility probe and SwiftUI host interaction emitted the geometry log independently of SpaceLens code.
- **Rollback path:** Keep diagnostic simplifications uncommitted, restore each controlled variable, and retain only fixes supported by tests and native behavior.

## Candidate Directions

| Candidate | Expected benefit | Main risk | Evidence before choice | Decision |
|---|---|---|---|---|
| Fix SpaceLens layout calculations and adaptive controls | Removes real compression and protects owned dimensions | Could falsely claim all AppKit diagnostics fixed | Visible compression and an unclamped computed width were real | Retained |
| Continue simplifying SpaceLens until the log disappears | Could identify an app-owned emitter | Destructive churn and a false causal story | Signal survived replacement of the entire content, commands, constraints, delegate, and packaging | Rejected |
| Build a minimal independent SwiftUI reproduction | Separates framework/harness behavior from product logic | Environment-specific conclusion | One-line Xcode SwiftUI app emitted the same three pairs during the same accessibility query | Retained as classification evidence |

## Evidence

- **First meaningful failure signal:** Accessibility inspection coincided with repeated negative width/height AppKit messages and a visibly compressed filter control.
- **Commands or runtime checks:** SwiftPM/Xcode builds, minimal-view substitutions, separate one-line Xcode SwiftUI app, Calculator control, Computer Use accessibility queries, and subsystem-scoped unified-log queries.
- **What the evidence ruled in or out:** It ruled in a real SpaceLens adaptive-layout issue, but ruled out SpaceLens content, commands, window constraints, delegate, package path, and build lane as the source of the remaining three-pair log signal.

## Decision

- **Root cause or remaining unknown:** SpaceLens-owned compression and width safety were fixed. The remaining geometry signal is a host-specific SwiftUI/accessibility-harness interaction; the underlying Apple-framework mechanism is outside repository scope.
- **Retained fix / direction:** Keep stacked controls, accessible label handling, clamped dimensions, focused search, and honest scoped-log reporting.
- **Why alternatives were rejected:** Removing correct product architecture did not affect the signal and would weaken the app without increasing certainty.
- **Residual risk:** A future OS or accessibility implementation may change the system signal; visual/runtime checks remain authoritative for SpaceLens behavior.
- **Rollback trigger:** Revert only if adaptive layout, keyboard focus, or scanning regresses in supported macOS builds.

## Reusable Lesson

- **Pattern to retain:** Correlate logs to exact interactions, isolate framework behavior with a minimal independent executable, and keep app-subsystem evidence separate from global system noise.
- **Pattern to avoid:** Treat temporal correlation between a framework log and a visible product defect as proof that both share one cause.
- **Where it applies next:** SwiftUI runtime audits that use accessibility automation or unified-log fault counts as a release gate.
