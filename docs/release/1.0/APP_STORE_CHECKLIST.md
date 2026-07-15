# SpaceLens 1.0 App Store Checklist

Checked against Apple documentation on 2026-07-15.

| Item | Status | Evidence / owner action |
| --- | --- | --- |
| App name `SpaceLens` | PASS | Built bundle and metadata draft |
| Bundle ID `com.andrzej.spacelens` | PASS | Project configuration, profile and signed payload |
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
| Support URL | BLOCKED | Publish a public unauthenticated HTTPS support page with a real contact method |
| Privacy Policy URL | BLOCKED | Publish a public unauthenticated HTTPS policy matching `PRIVACY_DATA_MAP.md` |
| App privacy answers | BLOCKED | Account/privacy owner confirmation required |
| Age rating | BLOCKED | Complete the current App Store Connect questionnaire. [Apple age-rating help](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/) |
| DSA trader status | BLOCKED | Legal/account owner declaration required. [Apple DSA help](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements) |
| Export compliance | BLOCKED | Owner must answer truthfully; repository contains no custom cryptography |
| Content rights | BLOCKED | Owner confirmation required for name, icon, copy and bundled assets |
| Copyright/legal name | BLOCKED | Bundle says `Rafal Sikor`; signer says `Rafal Sikora`; owner must provide the exact legal string |
| Pricing, territories, release method | BLOCKED | Business/account decisions |
| Review contact | BLOCKED | Account owner provides current contact details |
| Accessibility nutrition labels | BLOCKED | Complete human QA and enter truthful declarations. [Apple accessibility-label help](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/manage-accessibility-nutrition-labels) |
| App Store Connect record/role | BLOCKED | Confirm app record and upload/submission role |
| Apple validation/upload/processing | BLOCKED | Requires explicit external authorization and ASC access |
| Processed clean-account install | BLOCKED | Install Apple-processed build and repeat critical smoke |

The metadata file intentionally leaves owner-controlled URLs, contacts, legal declarations, pricing, territories, and release mode unset. Local validation must expose missing decisions instead of inventing them.
