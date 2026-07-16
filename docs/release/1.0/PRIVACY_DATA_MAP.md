# SpaceLens 1.0 Privacy Data Map

This map describes repository-observable behavior as of 2026-07-15. The owner confirmed the matching Data Not Collected declaration on 2026-07-16.

| Data | Purpose | Storage and retention | Recipient / tracking |
| --- | --- | --- | --- |
| User-selected root path and security-scoped bookmark | Restore authorized scan access | Local Application Support session; replaced by a later session or removed by Forget/clear/app-data removal | On-device only; no tracking |
| File/folder names and paths under the selected root | Display usage and classify cleanup risk | In memory; selected queue paths may persist in the local session | On-device only; no tracking |
| File sizes, allocation, timestamps and structure | Aggregate disk use, sorting and safety evidence | In memory and local aggregate/session context; replaced by later scans | On-device only; no tracking |
| Scan errors | Explain inaccessible or unsafe entries | In memory and user-visible; replaced by later scans | On-device only; no tracking |
| Cleanup queue paths and classifications | Persist review-first cleanup intent | Local session file; cleared after cleanup, invalidation, Forget/clear or app-data removal | On-device only; no tracking |
| Local persistence error diagnostics | Diagnose a failed session save/load | Apple Unified Logging under OS retention | Local device operator; private/hash-masked detail, no file content |

## Repository Reconciliation

- No backend, network service, account, analytics, crash-reporting SDK, advertising SDK, tracking SDK, or third-party package dependency is present.
- File contents and metadata are not uploaded by SpaceLens.
- `NSPrivacyCollectedDataTypes` is empty.
- `NSPrivacyTracking` is `false`; no tracking domains are declared.
- Required-reason API code `3B52.1` covers file timestamps inside user-granted folders.
- The signed exported package contains the same privacy manifest and passes the repository lint.
- Official reference: [Apple privacy manifest documentation](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files).

## Owner Confirmation

The account/privacy owner confirmed Data Not Collected, including that no operational support, web, backend, analytics, crash-reporting, or other workflow outside this repository collects SpaceLens user data. The public privacy policy must continue to match both the shipped app and that operational reality.
