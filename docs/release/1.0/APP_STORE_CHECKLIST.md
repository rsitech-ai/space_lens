# SpaceLens 1.0 App Store Checklist

Checked against the release repository on 2026-07-15.

| Item | Status | Evidence / owner action |
| --- | --- | --- |
| App name `SpaceLens` | PASS | Built bundle and metadata draft |
| Bundle ID `com.rsitech.spacelens` | PASS (repo) / BLOCKED (Apple) | Local project is consistent; create the matching Apple identifier, profile and app record |
| Version 1.0 build 1 | PASS (repo) / BLOCKED (ASC) | Config and fresh builds pass; remote build-number availability remains unknown |
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
| Support URL | PREPARED / BLOCKED (deploy) | `https://www.rsitech.ai/spacelens/support`; publish and verify signed-out HTTP 200 |
| Privacy Policy URL | PREPARED / BLOCKED (deploy) | `https://www.rsitech.ai/spacelens/privacy`; publish and verify signed-out HTTP 200 |
| App privacy answers | RECOMMENDED / OWNER CONFIRMATION | Data Not Collected, based on verified local-only operation |
| Age rating | RECOMMENDED / OWNER CONFIRMATION | All content-frequency answers None; accept Apple’s lowest resulting rating |
| DSA trader status | BLOCKED | Legal/account owner declaration required |
| Export compliance | REPO PREPARED / OWNER CONFIRMATION | No restricted encryption found; `ITSAppUsesNonExemptEncryption=false` |
| Content rights | BLOCKED | Owner confirmation required for name, icon, copy and assets |
| Copyright/legal name | OWNER CONFIRMED | `Rafal Sikora` in bundle metadata |
| Pricing | OWNER CONFIRMED | Free |
| Territories | OWNER CONFIRMED | All available territories |
| Release method | OWNER CONFIRMED | Automatic after approval |
| Accessibility labels | BLOCKED | Automated AX labels and minimum window pass; Light, focus and VoiceOver human proof remain |
| Security | PENDING | Final scan intentionally runs after all other local fixes |
| GitHub CI | EXTERNAL FAILURE / EXCEPTION RECORDED | Latest run started zero steps due billing/spending state; fresh local equivalents pass |
| Apple validation/upload/processing | BLOCKED | Requires current signed package plus exact external authorization |
| Processed build install | BLOCKED | No Apple-processed build exists |

The stale package for `com.andrzej.spacelens` must never be uploaded. The next package must be built only after the new identifier and matching Store profile exist.
