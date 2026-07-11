# SpaceLens 1.0 Test Evidence

## Preflight

| Check | Result | Evidence |
| --- | --- | --- |
| Initial Git baseline | PASS | Clean `main` at `d6ef7e4`; branch `feat/andrzej_agent_sota_lab` created |
| Project shape | PASS | SwiftPM executable `SpaceLens`; Xcode targets `SpaceLens`, `SpaceLensTests`; one shared scheme |
| Shipping platforms | PASS | macOS only; `SUPPORTED_PLATFORMS=macosx` |
| Architectures | PASS | Release app binary and archive contain `x86_64 arm64` |
| Xcode | PASS | Xcode 26.5 build 17F42 at `/Applications/Xcode.app` |
| SDK | PASS | macOS 26.5 |
| Swift | PASS | Swift 6.3.2 |
| Signing identities | PASS | Apple Development identity available; signed app TeamIdentifier `2NY8A789TN`; Apple Distribution and 3rd Party Mac Developer Installer identities for team `2NY8A789TN` verified |
| Provisioning | PASS | Mac Team Store profile `56a29891-...` is available through 2027-06-29 and matched the successful Store export |
| GitHub | PASS | `gh` 2.85.0 authenticated as `s1korrrr`; remote `s1korrrr/space_lens`; default `main` |
| iOS devices/simulators | NOT APPLICABLE | Repository has no iOS target |
| macOS 27 runtime | BLOCKED | Not installed |

## Automated Verification

| Gate | Result | Fresh evidence from 2026-07-11 |
| --- | --- | --- |
| Repository readiness validator | PASS | `./script/validate_app_store_readiness.sh`; 40 tests, unsigned Xcode Debug build, processed 1.0 (1), packaged privacy manifest |
| SwiftPM tests | PASS | `swift test -Xswiftc -warnings-as-errors`; 40 tests, 0 failures |
| SwiftPM Release | PASS | `swift build -c release -Xswiftc -warnings-as-errors` |
| Xcode static analysis | PASS | Release `xcodebuild ... analyze`; `** ANALYZE SUCCEEDED **` |
| Universal Xcode Release | PASS | `ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`; `** BUILD SUCCEEDED **` |
| Address Sanitizer | PASS | 40 tests; `/tmp/spacelens-final-asan/Logs/Test/` xcresult from 2026-07-11 21:08 |
| Thread Sanitizer | PASS | 40 tests; `/tmp/spacelens-final-tsan/Logs/Test/Test-SpaceLens-2026.07.11_21-09-03-+0200.xcresult` |
| Dependency resolution | PASS | No third-party package dependencies or `Package.resolved` |

The Xcode App Intents metadata extractor emits a benign “No AppIntents.framework dependency found” message because SpaceLens does not link App Intents. No compiler or analyzer warnings remain.

## Native Runtime Evidence

| Check | Result | Evidence / limitation |
| --- | --- | --- |
| Exact signed archive app launch | PASS | Launched `build/AppStore/SpaceLens.xcarchive/Products/Applications/SpaceLens.app` on macOS 26.3 |
| First-run Smart Scan authorization | PASS | Smart Scan opened an `NSOpenPanel` titled “Select a folder for Smart Scan”; no ambient home-folder scan began |
| Primary navigation and controls | PASS | Accessibility tree exposed sidebar filters, folder/Smart Scan/rescan controls, search, filters, selection actions, inspector, Settings, and menus |
| Destructive-action policy | PASS | UI exposes Move to Bin only; the permanent-delete action is absent; exact-path confirmation is unit-tested |
| Privacy and saved-session disclosure | PASS | Runtime Settings state exposes local processing, local session retention, and “Forget Saved Folder and Queue…” |
| Keyboard/accessibility structure | PASS (bounded) | Native AX tree contains named controls, headings, help text, selection states, and disabled states; human VoiceOver usability remains manual |
| Appearance | PASS (dark only) | Current-system dark appearance inspected and screenshot captured; Light, Increased Contrast, and Reduce Motion remain manual environment checks |
| Idle CPU | PASS | Ten consecutive samples reported 0.0% CPU after interaction |
| Memory | PASS (bounded) | RSS stabilized at 146,992 KB; `leaks` reported 65.0 MB physical footprint but could not attach to the hardened process |
| Runtime logs | PASS (bounded) | No app crash/fatal/assertion or raw user-file path emitted; observed DetachedSignatures/CoreFSCache messages are OS framework noise |
| Minimum macOS 14 runtime | BLOCKED | No macOS 14 hardware/VM available |

No cleanup confirmation was accepted during runtime QA. The disposable fixture remained unchanged.

## Signing And Package Evidence

| Check | Result | Evidence |
| --- | --- | --- |
| Archive/export command | PASS (pre-final commit) | `SPACE_LENS_DEVELOPMENT_TEAM=2NY8A789TN ./script/archive_app_store.sh`; archive and export succeeded |
| Archive app | PASS | Development-signed, hardened runtime, team `2NY8A789TN`, strict code-sign verification passed |
| Exported payload | PASS | Apple Distribution: Rafal Sikora (`2NY8A789TN`); strict code-sign verification passed |
| Installer package | PASS | 3rd Party Mac Developer Installer: Rafal Sikora (`2NY8A789TN`); signature valid to 2027-06-29 |
| Entitlements | PASS | App Sandbox, user-selected read/write, and app-scoped bookmarks only |
| Bundle payload | PASS | 1.0 (1), universal `x86_64 arm64`, AppIcon, Assets.car, and PrivacyInfo.xcprivacy |
| Package digest | PASS (pre-final commit) | SHA-256 `1cfd1055009e479e0c378f79cfd5090058455230ea96e5b1b7b6d9dc2df25f40`; rerun after final commit is required |

## Screenshot Evidence

- Accepted-size dark empty-state candidate: `screenshots/SpaceLens-macOS-dark-empty-1280x800.jpeg` (1280x800, SHA-256 `521e092fde912d3e39e098cf1a319bfc0ea94c72d0c453afcd3e3fdfc5367999`).
- Source capture is retained beside it. The accepted-size derivative crops 3 vertical pixels from the live capture and scales it to Apple’s 1280x800 slot; no UI content was composited or generated.
- Additional feature-state and Light appearance screenshots remain an owner/marketing action before submission.
