# SpaceLens 1.0 App Store Checklist

Checked against the release repository and current Apple/web state on 2026-07-16.

| Item | Status | Evidence / owner action |
| --- | --- | --- |
| Public App Store name | PASS | `SpaceLens: Disk Cleanup` in App Store Connect record `6791508081` |
| Bundle ID `com.rsitech.spacelens` | PASS | Repository, explicit Apple ID, Store profile and signed package agree |
| Version 1.0 build 1 | PASS (package/record) | Signed package is 1.0 (1); App Store Connect version 1.0 exists and currently has no uploaded builds |
| Utilities category | PASS | `LSApplicationCategoryType` |
| macOS 14.0 minimum | PASS (config) / BLOCKED (runtime) | Deployment target verified; no macOS 14 runtime proof |
| Production toolchain | PASS | Xcode 26.6 (17F113), macOS 26.5 SDK |
| Xcode 27 compatibility | PASS (historical build) | Beta 3 universal warnings-as-errors build succeeded; not rerun after metadata-only changes |
| App icon | PASS | Source and compiled assets present |
| Screenshots | PASS (minimum) / OWNER REVIEW | Truthful 1280x800 feature-state image at `screenshots/SpaceLens-macOS-dark-feature-1280x800.jpeg` |
| Subtitle | PASS (draft) | `Smarter storage. Safer cleanup` |
| Description, keywords and What’s New | PASS (draft) | `.codex/app-store/metadata.json` and `RELEASE_NOTES.md` |
| Review notes/contact | OWNER CONFIRMED | Rafal Sikora; private email and phone in `APP_REVIEW_NOTES.md` |
| Demo account | NOT APPLICABLE | No account, login or backend |
| Support URL | PASS | <https://www.rsitech.ai/spacelens/support> returns signed-out HTTP 200 |
| Privacy Policy URL | PASS | <https://www.rsitech.ai/spacelens/privacy> returns signed-out HTTP 200 |
| App privacy answers | OWNER CONFIRMED / PENDING ASC ENTRY | Data Not Collected, based on verified local-only operation |
| Age rating | OWNER CONFIRMED / PENDING ASC ENTRY | All content-frequency answers None; accept Apple’s lowest resulting rating |
| DSA trader status | OWNER CONFIRMED / PHONE CODE PENDING | Trader selected; approved address, email and phone entered; Apple sent an SMS code and the workflow is paused at code entry |
| Export compliance | OWNER CONFIRMED | No restricted encryption; bundle declares `ITSAppUsesNonExemptEncryption=false` |
| Content rights | OWNER CONFIRMED | Owner confirmed rights to the name, icon, copy and bundled assets |
| Copyright/legal name | OWNER CONFIRMED | `Rafal Sikora` in bundle metadata |
| Pricing | OWNER CONFIRMED | Free |
| Territories | OWNER CONFIRMED | All available territories |
| Release method | OWNER CONFIRMED | Automatic after approval |
| Accessibility labels | BLOCKED | Automated AX labels and minimum window pass; Light, focus and VoiceOver human proof remain |
| Security | PENDING | Final scan intentionally runs after all other local fixes |
| GitHub CI | EXTERNAL FAILURE / EXCEPTION RECORDED | Latest run started zero steps due billing/spending state; fresh local equivalents pass |
| Store archive/package | PASS / HOLD | Signed universal package exists; hold until final security and exact-digest upload approval |
| App Store validation/upload/processing | BLOCKED | Requires final security, completed DSA verification and fresh exact-digest authorization |
| Processed build install | BLOCKED | No Apple-processed build exists |

The stale package for `com.andrzej.spacelens` must never be uploaded. The current inspected package is `/private/tmp/SpaceLens-AppStore-20260716-0df601f/export/SpaceLens.pkg`, SHA-256 `e2e5f484ffa7f648a2019b7a8cbf75babc96835dbddfcb76378a87ff7904af05`.
