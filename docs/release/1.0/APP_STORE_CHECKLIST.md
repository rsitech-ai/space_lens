# SpaceLens 1.0 App Store Checklist

Checked against Apple documentation on 2026-07-15.

| Item | Status | Evidence / owner action |
| --- | --- | --- |
| App name `SpaceLens` | PASS | Built bundle and metadata draft |
| Bundle ID `com.rsitech.spacelens` | BLOCKED | Local project migrated; a matching Apple identifier and provisioning profile do not yet exist |
| Version 1.0 build 1 | PASS (local) / BLOCKED (ASC) | Built package verified; owner must confirm build availability |
| Utilities category | PASS | `LSApplicationCategoryType` |
| macOS 14.0 minimum | PASS (config) / BLOCKED (runtime) | Deployment target verified; no macOS 14 runtime proof |
| Production toolchain | PASS | Xcode 26.6 (17F113), macOS 26.5 SDK |
| Xcode 27 compatibility | PASS (build) | Beta 3 universal warnings-as-errors build succeeded |
| App icon | PASS | Source and compiled assets present in signed payload |
| Screenshots | PASS (minimum) / OWNER REVIEW | Truthful 1280x800 dark empty-state image; approve freshness and add feature/light images if desired. [Apple screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/) |
| Subtitle | PASS (draft) | `Smarter storage. Safer cleanup` (30 characters) |
| Description, promotional text, keywords | PASS (draft) | `APP_REVIEW_NOTES.md` and `.codex/app-store/metadata.json` |
| What’s New | PASS (draft) | `RELEASE_NOTES.md` |
| Review notes | PASS (draft) | Local-only behavior and disposable-folder flow documented |
| Demo account | NOT APPLICABLE | No account, login, or backend |
| Support URL | PREPARED / BLOCKED (deploy) | `https://rsitech.ai/spacelens/support`; deploy and verify unauthenticated HTTP 200 |
| Privacy Policy URL | PREPARED / BLOCKED (deploy) | `https://rsitech.ai/spacelens/privacy`; deploy and verify against `PRIVACY_DATA_MAP.md` |
| App privacy answers | BLOCKED | Account/privacy owner confirmation required |
| Age rating | BLOCKED | Complete the current App Store Connect questionnaire. [Apple age-rating help](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/) |
| DSA trader status | BLOCKED | Legal/account owner declaration required. [Apple DSA help](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements) |
| Export compliance | BLOCKED | Owner must answer truthfully; repository contains no custom cryptography |
| Content rights | BLOCKED | Owner confirmation required for name, icon, copy and bundled assets |
| Copyright/legal name | PASS | Owner confirmed `Rafal Sikora`; bundle metadata now matches the signing identity |
| Pricing | OWNER CONFIRMED | Free |
| Territories | BLOCKED | Owner has not yet selected storefront availability; recommendation is all available territories |
| Release method | OWNER CONFIRMED | Automatic release after approval |
| Review contact | OWNER CONFIRMED | Rafal Sikora; private email and phone recorded in `APP_REVIEW_NOTES.md` |
| Accessibility nutrition labels | BLOCKED | Complete human QA and enter truthful declarations. [Apple accessibility-label help](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/manage-accessibility-nutrition-labels) |
| App Store Connect record/role | ROLE CONFIRMED / RECORD BLOCKED | Owner confirms upload/submission role; new `com.rsitech.spacelens` record must be created |
| Apple validation/upload/processing | BLOCKED | Requires explicit external authorization and ASC access |
| Processed clean-account install | BLOCKED | Install Apple-processed build and repeat critical smoke |

The local metadata records the prepared URLs, public support address and private App Review contact. The owner confirmed free pricing and automatic release. Territories and legal/privacy/compliance/accessibility declarations remain unset until explicitly confirmed.
