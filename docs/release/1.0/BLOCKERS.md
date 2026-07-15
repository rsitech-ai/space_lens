# SpaceLens 1.0 Blockers

All currently runnable non-security repository gates pass. The final security scan is intentionally pending. No current `com.rsitech.spacelens` App Store package exists.

## External / Owner-Controlled

| ID | Blocker | Owner | Exact next action |
| --- | --- | --- | --- |
| EXT-001 | Apple identifier, matching profile and App Store Connect record do not exist locally | Account owner | After exact-action approval, create `com.rsitech.spacelens`, obtain a matching profile, and create version 1.0 under team `2NY8A789TN` |
| EXT-002 | Version 1.0 build 1 availability is unknown | Account owner | Check the new App Store Connect record; increment before upload if build 1 is unavailable |
| EXT-003 | Public Support URL is prepared but not deployed | Support/account owner | Publish `https://www.rsitech.ai/spacelens/support` and verify signed-out HTTP 200 |
| EXT-004 | Public Privacy URL is prepared but not deployed | Privacy/account owner | Publish `https://www.rsitech.ai/spacelens/privacy` and verify signed-out HTTP 200 and content parity |
| EXT-006 | App privacy answers are not owner-confirmed | Privacy/account owner | Confirm the recommended Data Not Collected answer against the final scan/build, then enter it |
| EXT-007 | Age rating questionnaire is incomplete | Content/account owner | Answer all truthful content frequencies; current recommendation is None for every category and the lowest resulting rating |
| EXT-008 | DSA trader status is unknown | Legal/account owner | Make the truthful EU trader/non-trader declaration |
| EXT-009 | Export-compliance answer is not owner-confirmed | Legal/account owner | Confirm No restricted encryption; the bundle now declares `ITSAppUsesNonExemptEncryption=false` |
| EXT-010 | Content rights are not owner-confirmed | Rights owner | Confirm rights to the name, icon, copy and bundled assets |
| EXT-013 | Accessibility nutrition labels are incomplete | Accessibility/account owner | Complete human QA and enter only labels supported by evidence |
| EXT-014 | Apple validation, upload and processing have not run | Account owner | After the new identifier/profile/record and a current package exist, approve the exact package digest for validation/upload |
| EXT-015 | Apple-processed clean-account install is absent | QA/account owner | Install the processed build and repeat the critical workflow |
| EXT-016 | GitHub Actions cannot allocate a runner | GitHub account owner | Latest run `29418432116`, job `87362390763`, executed zero steps due billing/spending state; rerun after the account issue is fixed |

## Manual / Runtime QA

| ID | Blocker | Owner | Exact next action |
| --- | --- | --- | --- |
| QA-001 | Minimum macOS 14 runtime is unverified | QA owner | Test the final build on macOS 14 hardware or VM |
| QA-003 | Light appearance and human keyboard-focus sweep are incomplete | QA owner | Verify Light appearance and focus order with system keyboard navigation enabled |
| QA-004 | Human VoiceOver/accessibility pass is incomplete | Accessibility owner | Run the critical workflow with VoiceOver and verify labels, state and announcements |
| QA-005 | Screenshot marketing approval is missing | Marketing owner | Approve the truthful feature-state screenshot and add a Light capture only if desired |
| SEC-001 | Current branch security disposition is pending | Release owner | Run the requested final security scan after this non-security dossier is committed |

## Resolved Owner Decisions

- Legal name: `Rafal Sikora`.
- Public support: `info@rsitech.ai`.
- Private App Review contact: `Rafal Sikora`, `info@rsitech.ai`, `private contact stored only in App Store Connect`.
- Pricing: free.
- Territories: all available.
- Release: automatic after approval.
- Agreements, tax, banking, developer-program membership and upload/submission role: owner-confirmed current.
- GitHub CI exception: proceed with fresh local CI-equivalent evidence while the external billing/spending blocker remains visible; this does not turn the failed workflow green.

Website deployment, branch push, Apple identifier/profile/record creation, upload, TestFlight changes, submission, merge, tag and public release remain separate external actions.
