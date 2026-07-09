# Mac App Store Release Checklist: SpaceLens

Use `verified`, `blocked`, or `not applicable` for each item.

## Account And App Record

| Item | Status | Evidence |
| --- | --- | --- |
| Apple Developer Program team confirmed | verified | Local export used team `2NY8A789TN` (`Rafal Sikora`); keychain also shows the development identity provided by the user. |
| Bundle identifier registered | verified | App Store export created/used `Mac Team Store Provisioning Profile: com.andrzej.spacelens`. |
| App Store Connect app record exists | blocked | Must be confirmed or created for `com.andrzej.spacelens` before upload/submission. |
| Version and build numbers set | verified | `MARKETING_VERSION=1.0`, `CURRENT_PROJECT_VERSION=1` in `project.yml` and generated `Info.plist`. |

## Signing And Sandbox

| Item | Status | Evidence |
| --- | --- | --- |
| Distribution signing configured | verified | Export summary shows Apple Distribution certificate `CB291196A6A812553A4E69C9ABF9FC265FAE1765` and installer signing succeeded. |
| Provisioning profile valid | verified | Export summary shows `Mac Team Store Provisioning Profile: com.andrzej.spacelens`, UUID `56a29891-3085-421e-a1c3-6212c65020fa`, expires `29/06/2027`. |
| App Sandbox enabled | verified | `Config/SpaceLens.entitlements` includes `com.apple.security.app-sandbox=true`. |
| Entitlements minimized and reviewed | verified | Sandbox, user-selected read/write file access, and app-scoped bookmark persistence are configured. |
| Hardened runtime/distribution settings reviewed | verified | `ENABLE_HARDENED_RUNTIME=YES` in `project.yml`; unsigned local builds disable it as expected. |
| `codesign` inspection captured | verified | Temporary ad-hoc sandbox signing inspection showed sandbox, user-selected read/write, and app-scoped bookmark entitlements. |

## Privacy

| Item | Status | Evidence |
| --- | --- | --- |
| Data collection inventory complete | verified | `docs/PRIVACY.md` documents no collection, no tracking, no analytics. |
| Privacy manifest present where required | verified | `Resources/PrivacyInfo.xcprivacy` included in Xcode app resources. |
| Privacy labels drafted in App Store Connect | blocked | Enter no collected data in App Store Connect. |
| Permission purpose strings reviewed | not applicable | Folder access is through `NSOpenPanel`; no TCC purpose string is required for this V1 surface. |
| Third-party SDK privacy reviewed | verified | No third-party SDK dependencies. |
| Logs exclude sensitive data | verified | Session logger reports persistence errors only, not file contents. |

## Product Quality

| Item | Status | Evidence |
| --- | --- | --- |
| Unit tests pass | verified | `swift test` and Xcode test suite. |
| Integration tests or mocks pass | verified | Temporary filesystem scan/cleanup and session restore tests. |
| Release build/archive succeeds | verified | `SPACE_LENS_DEVELOPMENT_TEAM=2NY8A789TN ./script/archive_app_store.sh` produced `build/AppStore/export/SpaceLens.pkg`. |
| Clean launch of release artifact | verified | `./script/build_and_run.sh --verify`. |
| Primary workflow smoke passed | verified | Folder scan, restored cleanup queue, cleanup gates, selection/filtering covered by tests and launch smoke screenshots. |
| Crash/log check after smoke | verified | Launch/test output checked; no crash in smoke. |
| Accessibility pass | blocked | Native controls and labels are used; full VoiceOver/manual accessibility pass remains before submission. |
| Light/Dark/Reduce Motion checked | blocked | Dark UI and native controls verified in screenshots; formal Light Mode and Reduce Motion pass remains. |
| Performance smoke checked | verified | Scan progress throttling, cached visible rows/classifications, and release build validated; full Instruments trace remains optional before submission. |

## App Store Assets

| Item | Status | Evidence |
| --- | --- | --- |
| App icon complete | verified | `Resources/Assets.xcassets/AppIcon.appiconset`. |
| Screenshots prepared | blocked | Main and restore-smoke screenshots exist under `docs/screenshots/`; App Store-size screenshots still need final upload/export. |
| App name/subtitle/description/keywords | blocked | Must be entered in App Store Connect. |
| Category and age rating | blocked | Category configured as Utilities; age rating questionnaire must be completed in App Store Connect. |
| Support URL | verified | `https://github.com/s1korrrr/space_lens/blob/main/docs/SUPPORT.md`. |
| Marketing URL, if used | not applicable | Not required for V1. |
| Review notes and demo credentials, if needed | verified | Suggested review notes exist in `docs/APP_STORE.md`; no credentials needed. |

## Release Decision

- Current readiness label: App Store package exported locally; final submission
  still needs App Store Connect setup and manual release QA.
- Remaining blockers: App Store Connect app record confirmation, privacy
  labels, App Store-size screenshots, metadata, age rating, package upload,
  VoiceOver/accessibility smoke, and Light Mode/Reduce Motion smoke.
- Submission owner: Apple Developer account holder for team `2NY8A789TN`.
- Next action: create or confirm the App Store Connect app record, then upload
  `build/AppStore/export/SpaceLens.pkg` with Transporter, Xcode Organizer, or
  App Store Connect API tooling.
