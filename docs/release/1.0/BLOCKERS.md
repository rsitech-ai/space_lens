# SpaceLens 1.0 Blockers

All currently runnable non-security repository gates pass. A current signed `com.rsitech.spacelens` Store package exists and has been inspected. The final security scan is intentionally pending, and no package has been uploaded.

## External / Owner-Controlled

| ID | Blocker | Owner | Exact next action |
| --- | --- | --- | --- |
| EXT-008 | DSA Trader phone verification code is pending | Legal/account owner | Enter the SMS code Apple sent to `private contact stored only in App Store Connect`, then complete any further Apple verification steps presented |
| EXT-013 | Accessibility nutrition labels are incomplete | Accessibility/account owner | Complete human QA and enter only labels supported by evidence |
| EXT-014 | Apple validation, upload and processing have not run | Account owner | After record creation and final security, approve the exact package digest for validation/upload |
| EXT-015 | Apple-processed clean-account install is absent | QA/account owner | Install the processed build and repeat the critical workflow |
| EXT-016 | GitHub Actions cannot allocate a runner | GitHub account owner | Latest run `29481267996`, job `87565329735`, executed zero steps due billing/spending state; rerun after the account issue is fixed |

## Manual / Runtime QA

| ID | Blocker | Owner | Exact next action |
| --- | --- | --- | --- |
| QA-001 | Minimum macOS 14 runtime is unverified | QA owner | Test the final build on macOS 14 hardware or VM |
| QA-003 | Light appearance and human keyboard-focus sweep are incomplete | QA owner | Verify Light appearance and focus order with system keyboard navigation enabled |
| QA-004 | Human VoiceOver/accessibility pass is incomplete | Accessibility owner | Run the critical workflow with VoiceOver and verify labels, state and announcements |
| QA-005 | Screenshot marketing approval is missing | Marketing owner | Approve the truthful feature-state screenshot and add a Light capture only if desired |
| SEC-001 | Current branch security disposition is pending | Release owner | Run the requested final security scan after this evidence update is committed |

## Completed External Setup

- Explicit App ID `2NY8A789TN.com.rsitech.spacelens` exists.
- Mac App Store provisioning profile `SpaceLens Mac App Store 2026` was created and installed; it expires 2027-06-29.
- A matching Xcode-managed Store profile was embedded during successful archive export.
- Support and Privacy pages are published and return signed-out HTTP 200.
- App Store Connect record `6791508081` exists as `SpaceLens: Disk Cleanup`, English (U.S.), SKU `SPACELENS-MAC-001`, Full Access, macOS version 1.0 Prepare for Submission.
- The new App Store Connect record has no uploaded builds; package build 1 remains unconsumed.
- The release branch is pushed at package source `0df601ffffc3c0fb97482df4b1abd7722e69e3d4`; draft PR #9 exists.

## Resolved Owner Decisions

- Legal name: `Rafal Sikora`.
- Public support: `info@rsitech.ai`.
- Private App Review contact: `Rafal Sikora`, `info@rsitech.ai`, `private contact stored only in App Store Connect`.
- App privacy: Data Not Collected.
- Age rating: all content-frequency answers None; accept Apple’s lowest resulting rating.
- Export compliance: no restricted/non-exempt encryption.
- Content rights: confirmed.
- DSA status: Trader.
- Trader public email/phone: `info@rsitech.ai`, `private contact stored only in App Store Connect`; the physical address is approved for public display and entered in Apple’s workflow.
- Pricing: free.
- Territories: all available.
- Release: automatic after approval.
- Agreements, tax, banking, developer-program membership and upload/submission role: owner-confirmed current.
- GitHub CI exception: proceed with fresh local CI-equivalent evidence while the external billing/spending blocker remains visible; this does not turn the failed workflow green.

The completed authorization included App Store record creation, Trader selection and entry of the approved public contact details. Apple sent an SMS verification code and the workflow is paused at code entry. Package upload, TestFlight changes, submission, tag and public release remain separate external actions.
