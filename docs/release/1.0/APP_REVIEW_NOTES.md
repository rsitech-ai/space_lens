# SpaceLens 1.0 App Review And Metadata Draft

## Metadata Draft

- Name: SpaceLens
- Subtitle: Smarter storage. Safer cleanup
- Promotional text: Find large files, understand cleanup risk, and review recoverable space locally on your Mac.
- Primary category: Utilities
- Keywords: disk,storage,cleanup,files,space,cache,developer,utility

## Description

SpaceLens is a local-first disk intelligence utility for macOS. Choose a folder, inspect what consumes space, and review clear safety classifications before taking action.

Smart Scan finds common rebuildable caches and generated outputs without treating valuable documents or project data as disposable. SpaceLens keeps file contents and metadata on your Mac, provides evidence for every recommendation, and requires explicit confirmation before cleanup.

Key capabilities:

- Scan user-selected folders and summarize disk usage.
- Find common caches and generated build outputs with Smart Scan.
- Filter, sort, inspect and queue cleanup candidates.
- Move cleanup-ready items to the Bin after reviewing every target path.
- Restore the last authorized scan context locally.
- Work offline with no account, analytics, advertising or tracking SDK.

## App Review Notes

SpaceLens has no login, backend, in-app purchase, subscription or demo credentials. It requests access only through the standard macOS folder picker and uses an app-scoped security bookmark to restore access to the folder the reviewer selected. Classification runs locally; file contents and metadata are not uploaded.

Suggested review flow:

1. Create a disposable folder containing a normal document and a generated `.build` directory.
2. Use **Select Folder** and wait for the scan to finish.
3. Inspect the safety explanation in the right-side inspector.
4. Verify that valuable, unknown, inaccessible and symlink content cannot be queued for cleanup.
5. Select disposable generated content, open the **Move to Bin** confirmation and verify that every exact target path is listed.
6. Cancel, or move only the disposable fixture. SpaceLens has no permanent-delete operation.

Do not use personal reviewer data for destructive testing. A disposable test folder is sufficient.

## Owner-Controlled Fields

Owner-confirmed release details: legal name `Rafal Sikora`; private App Review contact `Rafal Sikora`, `info@rsitech.ai`, `private contact stored only in App Store Connect`; free pricing; automatic release; current agreements, tax, banking, developer-program membership and upload/submission role. Public support uses `info@rsitech.ai`. The Privacy and Support URLs are prepared at `https://rsitech.ai/spacelens/privacy` and `https://rsitech.ai/spacelens/support`, but must not be entered in App Store Connect until deployment is independently verified. Privacy answers, age rating, DSA trader status, export compliance, content rights, territories and accessibility labels still require explicit owner/account confirmation.
