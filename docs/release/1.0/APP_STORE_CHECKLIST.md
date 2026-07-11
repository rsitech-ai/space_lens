# SpaceLens 1.0 App Store Checklist

Checked against official Apple sources on 2026-07-11.

| Item | Status | Evidence / owner action |
| --- | --- | --- |
| App name `SpaceLens` | PASS | Repository bundle display name |
| Bundle ID `com.andrzej.spacelens` | PASS | `project.yml` and profile inventory |
| Version 1.0 build 1 | PASS | `project.yml` and `Config/Info.plist` |
| Utilities category | PASS | `LSApplicationCategoryType` |
| macOS 14.0 minimum | PASS | SwiftPM and XcodeGen configuration |
| 1024px app icon source | PASS | Source asset present and compiled `AppIcon.icns`/`Assets.car` verified in package rehearsal; final archive recheck required |
| Mac screenshots | PASS (minimum) | Actual dark empty-state capture prepared at 1280x800; additional feature/light captures remain marketing work. Apple source: <https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/> |
| Subtitle | NOT YET VERIFIED | Draft in `APP_REVIEW_NOTES.md`; owner approves final marketing copy |
| Promotional text | NOT YET VERIFIED | Draft in `APP_REVIEW_NOTES.md` |
| Description | NOT YET VERIFIED | Draft in `APP_REVIEW_NOTES.md` |
| Keywords | NOT YET VERIFIED | Draft in `APP_REVIEW_NOTES.md` |
| What’s New | NOT YET VERIFIED | Draft in `RELEASE_NOTES.md` |
| Support URL | BLOCKED | Existing private-repository URL returns 404; publish a public HTTPS page with a real contact method |
| Privacy Policy URL | BLOCKED | Existing private-repository URL returns 404; publish a public HTTPS policy page |
| App privacy answers | BLOCKED | Account owner must confirm local-only/no-collection declaration in App Store Connect |
| Updated age-rating questionnaire | BLOCKED | Account owner must answer current questions; Apple deadline has passed |
| DSA trader status for EU | BLOCKED | Legal/account owner declaration required |
| Export compliance | BLOCKED | Account owner must answer truthfully; repository uses no custom cryptography |
| Content rights | BLOCKED | Owner confirmation required |
| Pricing and territories | BLOCKED | Business/account decision |
| Release method | BLOCKED | Owner chooses manual/automatic/phased release |
| Review contact | BLOCKED | Account owner provides contact in App Store Connect |
| Demo account | NOT APPLICABLE | App has no account/login/backend |
| Review notes | NOT YET VERIFIED | Draft in `APP_REVIEW_NOTES.md` |
| App Store Connect record | BLOCKED | Account state not accessible in this run |
| Uploaded/processed build | BLOCKED | Requires validated archive plus account authorization |
