# SpaceLens 1.0 Test Evidence

Fresh evidence captured on 2026-07-15 from product source `791fe6c53ba74e68a46eafbbca8d9df2ecd52b0f`.

## Environment

| Check | Result | Evidence |
| --- | --- | --- |
| Product source | PASS | Clean commit `791fe6c`; branch `feat/andrzej_spacelens-release-final` |
| Shipping platform | PASS | macOS only; iOS is not applicable |
| Production toolchain | PASS | Xcode 26.6 (17F113), macOS 26.5 SDK, Swift 6.3.3 |
| Compatibility toolchain | PASS (build) | Xcode 27 beta 3 (27A5218g), macOS 27 SDK |
| Host | INFO | Apple M3 Max, macOS 27 beta build 26A5378j |
| XcodeGen | PASS | 2.45.4, release scripts pin/verify the version |
| Signing identities | PASS | Apple Development, Apple Distribution and Mac installer identities for team `2NY8A789TN` |
| Dependencies | PASS | No third-party Swift package dependencies or `Package.resolved` |

## Automated Verification

| Gate | Result | Command / artifact |
| --- | --- | --- |
| SwiftPM tests | PASS | `swift test -Xswiftc -warnings-as-errors`; 49 tests, 0 failures |
| Repository readiness validator | PASS | `SPACE_LENS_VALIDATION_DERIVED_DATA=/private/tmp/SpaceLens-final-validation-791fe6c ./script/validate_app_store_readiness.sh`; 49/49, generated-project parity, unsigned Xcode Debug, bundle 1.0 (1), privacy manifest |
| Signed Xcode tests | PASS | 49/49; `/private/tmp/SpaceLens-final-791fe6c-tests.xcresult` |
| Xcode Release analyze | PASS | Universal target, warnings as errors; `/private/tmp/SpaceLens-final-analyze-791fe6c`; `ANALYZE SUCCEEDED` |
| Universal Xcode 26 Release | PASS | Analyzer output contains `x86_64 arm64` |
| Xcode 27 beta compatibility build | PASS | Universal target build with `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`; `/private/tmp/SpaceLens-final-xcode27-werror-a6c839d`; `BUILD SUCCEEDED` |
| Address Sanitizer | PASS | `swift test --sanitize=address -Xswiftc -warnings-as-errors`; 49/49 |
| Thread Sanitizer | PASS | `swift test --sanitize=thread -Xswiftc -warnings-as-errors`; 49/49 |

Two Xcode scheme-level universal-build attempts and one Xcode ASan scheme attempt stalled during Xcode package loading before compilation and were interrupted. The direct Xcode target builds succeeded, and the final sanitizer evidence is the fresh SwiftPM ASan/TSan suites above; no Xcode sanitizer result bundle is claimed.

## Runtime Evidence

| Check | Result | Evidence / limitation |
| --- | --- | --- |
| Unsandboxed Release launch | PASS | Built and launched on the current Mac; evidence under `/private/tmp/SpaceLens-AgentB` |
| Main navigation and controls | PASS (bounded) | Navigation, Settings, About and destructive confirmation cancel path exercised |
| Destructive-action policy | PASS | No cleanup accepted; app exposes Move to Bin, exact-path confirmation, and no permanent deletion |
| Responsiveness | PASS (bounded) | App remained responsive for an 11-minute observation |
| Idle resources | PASS (bounded) | Idle CPU 0%; RSS approximately 69–72 MiB |
| Final sandboxed real-folder flow | BLOCKED (manual) | Folder picker, real scan, confirmation/cancel and no-destructive-execution proof still required |
| Appearance/layout | BLOCKED (manual) | Dark was observed; Light, minimum window and final layout sweep remain |
| Keyboard/VoiceOver | BLOCKED (manual) | Final focus-order and human VoiceOver checks remain |
| Minimum macOS 14 | BLOCKED | No compatible hardware/VM evidence |

## Signing And Package Evidence

Archive/export command:

```text
SPACE_LENS_ARCHIVE_ROOT=/private/tmp/SpaceLens-final-AppStore-791fe6c
SPACE_LENS_DEVELOPMENT_TEAM=2NY8A789TN
./script/archive_app_store.sh
```

| Check | Result | Evidence |
| --- | --- | --- |
| Clean-source invariant | PASS | Script captured `791fe6c53ba74e68a46eafbbca8d9df2ecd52b0f` and rechecked SHA/tree after export |
| Archive | PASS | `/private/tmp/SpaceLens-final-AppStore-791fe6c/SpaceLens.xcarchive` |
| Installer package | PASS | `/private/tmp/SpaceLens-final-AppStore-791fe6c/export/SpaceLens.pkg` |
| Package digest/size | PASS | SHA-256 `a108ee50640d65f3e6f8427b7d343143a674125bc28774442d4d4df2b548326a`; 1,420,625 bytes |
| Exported payload signature | PASS | Strict/deep verification; Apple Distribution: Rafal Sikora (`2NY8A789TN`) |
| Installer signature | PASS | 3rd Party Mac Developer Installer: Rafal Sikora (`2NY8A789TN`); certificate expires 2027-06-29 |
| Provisioning | PASS | Mac Team Store profile, team match, expiry 2027-06-29 |
| Entitlements | PASS | Sandbox, user-selected read/write, app-scoped bookmarks; no `get-task-allow` |
| Bundle | PASS | 1.0 (1), `x86_64 arm64`, hardened runtime, privacy manifest |
| Privacy manifest | PASS | No collection/tracking; timestamp reason `3B52.1` |
| Gatekeeper install assessment | EXPECTED REJECTION | Mac App Store package is not independently notarized/distributed; App Store Connect validation is still required |

## Screenshot Evidence

- Candidate: `screenshots/SpaceLens-macOS-dark-empty-1280x800.jpeg`.
- It is a truthful app capture at an accepted Mac screenshot size, not a generated or composited feature state.
- Final freshness, feature-state coverage and marketing approval remain owner/manual gates.

## External CI

- Draft PR: <https://github.com/s1korrrr/space_lens/pull/9>
- Workflow run `29418223217`, job `87361686258`: `BLOCKED`; the job completed in three seconds with no runner, no logs and zero steps.
- GitHub annotation: the job did not start because recent account payments failed or the spending limit must be increased.

This is external account state, not a source/test failure. Local CI-equivalent tests, project regeneration/parity, analyzer, universal builds and packaging pass. After the account owner resolves billing/spending state, rerun this workflow.
