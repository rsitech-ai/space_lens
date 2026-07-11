# SpaceLens 1.0 Blockers

## External / Account / Legal

| Blocker | Owner | Exact next action |
| --- | --- | --- |
| App Store Connect app record not confirmed | Account owner | Create or confirm the macOS app record for `com.andrzej.spacelens` |
| Build number availability unknown | Account owner | Confirm whether version 1.0 build 1 already exists; increment the build before upload if it does |
| Developer Program membership/role unconfirmed | Account owner | Confirm active membership and a role permitted to upload and submit builds |
| App privacy answers not confirmed | Account/privacy owner | Confirm repository data map matches all real operations, then enter answers in App Store Connect |
| Updated age rating unanswered | Account/content owner | Complete current age-rating questionnaire |
| DSA trader status unknown | Legal/account owner | Make truthful trader/non-trader declaration for EU distribution |
| Export compliance unanswered | Legal/account owner | Answer based on actual cryptography/export facts |
| Content rights unconfirmed | Rights owner | Confirm rights to app name, icon, copy, and bundled assets |
| Pricing, territories, and release mode undecided | Business owner | Choose storefronts, price, and manual/automatic/phased release |
| Review contact unavailable | Account owner | Enter current App Review contact details |
| App Store validation/upload authorization unavailable | Account owner | Authorize upload after local archive validation |
| Public Support and Privacy URLs unavailable | Account/privacy owner | Publish unauthenticated HTTPS pages; Support must include a real contact method |
| Clean-account/TestFlight installation unverified | QA/account owner | Install the processed build through TestFlight/App Store or a disposable clean macOS account and repeat the critical flow |
| Final accessibility declarations incomplete | Accessibility/account owner | Complete human VoiceOver/keyboard/appearance checks and enter truthful App Store accessibility metadata |

## Toolchain / Hardware

| Blocker | Owner | Exact next action |
| --- | --- | --- |
| macOS 14 minimum-runtime machine unavailable | QA owner | Test the final build on macOS 14 hardware/VM before claiming minimum-OS runtime proof |
| Xcode 27/macOS 27 toolchain unavailable | Toolchain owner | Run the separate compatibility track when Xcode 27 and a macOS 27 runtime are installed; do not use beta tooling for production submission unless Apple accepts it |

Locally actionable failures found later in this pass belong in `RELEASE_STATUS.md` as `FAIL`, not in this external blocker ledger.
