# SpaceLens 1.0 Blockers

All completed automated and package gates pass. The items below require account state, an owner declaration, Apple processing, another runtime, or human interaction evidence.

## External / Owner-Controlled

| ID | Blocker | Owner | Exact next action |
| --- | --- | --- | --- |
| EXT-001 | App Store Connect app record and role unavailable | Account owner | Confirm the macOS record for `com.andrzej.spacelens` and an upload/submission-capable role |
| EXT-002 | Version 1.0 build 1 availability unknown | Account owner | Check whether build 1 already exists; increment before upload if necessary |
| EXT-003 | Public Support URL missing | Support/account owner | Publish an unauthenticated HTTPS page with a working contact method |
| EXT-004 | Public Privacy URL missing | Privacy/account owner | Publish an unauthenticated HTTPS policy matching actual operations |
| EXT-005 | App Review contact missing | Account owner | Enter current reviewer contact details |
| EXT-006 | App privacy answers unconfirmed | Privacy/account owner | Reconcile all operational data flows and enter truthful answers |
| EXT-007 | Age rating unanswered | Content/account owner | Complete the current questionnaire |
| EXT-008 | DSA trader status unknown | Legal/account owner | Make the truthful EU trader/non-trader declaration |
| EXT-009 | Export compliance unanswered | Legal/account owner | Answer based on the shipped cryptography facts |
| EXT-010 | Content rights unconfirmed | Rights owner | Confirm rights to the name, icon, copy and bundled assets |
| EXT-011 | Legal copyright/name mismatch | Legal owner | Resolve bundle `Rafal Sikor` versus signer `Rafal Sikora`; provide the exact legal string |
| EXT-012 | Pricing, territories and release mode undecided | Business/account owner | Select storefronts, price and manual/automatic/phased release |
| EXT-013 | Accessibility nutrition labels incomplete | Accessibility/account owner | Complete human QA and enter truthful labels |
| EXT-014 | Apple validation, upload and processing not performed | Account owner | After approval, validate/upload the recorded package and review processing warnings |
| EXT-015 | Processed clean-account/TestFlight install absent | QA/account owner | Install Apple-processed build and repeat the critical workflow |
| EXT-016 | GitHub Actions cannot allocate a runner | GitHub account owner | Resolve failed account payments or increase the spending limit, then rerun PR #9 workflow `29418223217`; job `87361686258` executed zero steps |

## Manual / Runtime QA

| ID | Blocker | Owner | Exact next action |
| --- | --- | --- | --- |
| QA-001 | Minimum macOS 14 runtime unverified | QA owner | Test the final build on macOS 14 hardware or VM |
| QA-002 | Final sandboxed real-folder workflow unverified | QA owner | Exercise picker, scan, exact confirmation and cancel; do not execute cleanup on personal data |
| QA-003 | Light/Dark, minimum-window and keyboard-focus sweep incomplete | QA owner | Verify both appearances, smallest supported layout and focus order |
| QA-004 | Human VoiceOver/accessibility pass incomplete | Accessibility owner | Run the critical workflow with VoiceOver and verify labels, state and announcements |
| QA-005 | Screenshot freshness/marketing approval missing | Marketing owner | Approve the truthful screenshot set and add feature/light captures if desired |

These are release blockers, not permission to mutate external systems. Upload, TestFlight changes, submission, merge, tag and public release each remain outside this pass.
