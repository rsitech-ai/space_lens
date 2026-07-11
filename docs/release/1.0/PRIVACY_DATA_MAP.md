# SpaceLens 1.0 Privacy Data Map

This map describes repository-observable behavior. App Store declarations still require owner confirmation.

| Data | Source | Purpose | Storage | Retention / deletion | Recipient | Tracking / identity |
| --- | --- | --- | --- | --- | --- | --- |
| User-selected root path and security-scoped bookmark | macOS folder picker | Restore authorized scan access | Local Application Support session file | Replaced by later session; removed with app data | None | No tracking; not linked off-device |
| File/folder names and paths inside selected root | Local file metadata | Display disk usage and classify cleanup risk | In memory during session; selected queue paths persisted locally | Cleared/replaced by later scans; app data removal clears persistence | None | No tracking |
| File sizes, allocation, timestamps, structure | Local file metadata | Aggregate disk use, sorting, safety evidence | In memory; aggregate snapshot/session context locally | Cleared/replaced by later scans | None | No tracking |
| Scan errors | Local filesystem APIs | Explain inaccessible paths | In memory; user-visible | Cleared/replaced by later scans | None | No tracking |
| Cleanup queue paths and classification | User selection plus local rules | Persist review-first cleanup intent | Local Application Support session file | Removed after cleanup/invalid path or with app data | None | No tracking |
| Unified log error text | Local persistence failures | Diagnose failed session persistence | Apple unified log according to OS retention | OS-managed | Local device operator | Localized error detail is private and hash-masked; no file contents are logged |
| App Store support navigation | User opens the Store product-page Support URL outside SpaceLens | Contact support | No app-side storage | Not retained by SpaceLens | Public support host selected by owner | SpaceLens has no tracking SDK; destination policy must be disclosed |

## Manifest Reconciliation

- `NSPrivacyCollectedDataTypes`: empty.
- `NSPrivacyTracking`: false.
- File timestamp reason: `3B52.1`, for metadata inside user-granted folders.
- No third-party packages or SDKs are declared in `Package.swift` or `project.yml`.
- Official source checked 2026-07-11: <https://developer.apple.com/documentation/bundleresources/privacy-manifest-files>

## Owner Confirmation

The account owner must confirm that no separate backend, analytics, crash-reporting, ad, or support workflow collects SpaceLens user data outside this repository before entering “Data Not Collected” in App Store Connect.
