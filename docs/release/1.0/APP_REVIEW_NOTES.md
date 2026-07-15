# SpaceLens 1.0 App Review And Metadata Draft

## Metadata Draft

- Name: SpaceLens
- Subtitle: Smarter storage. Safer cleanup
- Promotional text: Find large files, explain cleanup risk, and review recoverable space locally on your Mac.
- Primary category: Utilities
- Keywords: disk,storage,cleanup,files,space,cache,developer,utility

## Description

SpaceLens is a local-first disk intelligence utility for macOS. Choose a folder, inspect what consumes space, and review clear safety classifications before taking action.

Smart Scan finds common rebuildable caches and generated outputs without treating valuable documents or project data as disposable. SpaceLens keeps file contents and metadata on your Mac, provides evidence for every recommendation, and requires explicit confirmation before cleanup.

Key capabilities:

- Scan user-selected folders and summarize disk usage.
- Find common caches and generated build outputs with Smart Scan.
- Filter, sort, inspect, and queue cleanup candidates.
- Move cleanup-ready items to the Bin after reviewing every target path.
- Restore the last authorized scan context locally.
- Work fully offline with no account, analytics, or tracking SDK.

## Review Notes

SpaceLens has no login, backend, in-app purchase, subscription, or demo credentials.

The app requests folder access only through the standard macOS folder picker. It uses an app-scoped security bookmark to restore access to the folder the reviewer selected. All classification is local. File contents and metadata are not uploaded.

Suggested review flow:

1. Choose a disposable test folder containing a normal document and a generated `.build` directory.
2. Select **Select Folder** and wait for the scan to finish.
3. Inspect the safety explanation in the right inspector.
4. Verify that valuable or unknown content cannot be cleaned.
5. For generated disposable test content, open the Move to Bin confirmation and verify that every target path is listed before cancelling or moving the fixture.

Do not use personal reviewer data for destructive testing. A disposable folder is sufficient.

## Owner-Controlled Fields

Review contact, copyright owner confirmation (including the current `Rafal Sikor` bundle string versus the `Rafal Sikora` signing identity), pricing, territories, release method, age rating, DSA trader status, export compliance, content rights, public Support/Privacy URLs, and final privacy answers require the account owner. These deliberately remain unset in `.codex/app-store/metadata.json` so local validation fails visibly instead of inventing declarations.
