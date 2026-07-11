# SpaceLens Privacy Policy

Effective date: 2026-06-26

SpaceLens is a local-first macOS disk intelligence app. It scans folders that
you explicitly select, calculates file and folder metadata, and classifies
cleanup risk on your Mac.

## Data Collection

SpaceLens does not collect, sell, share, or transmit personal data.

SpaceLens does not use analytics SDKs, advertising SDKs, tracking SDKs, or
third-party telemetry services.

## Local File Access

SpaceLens accesses only folders you select through the macOS file picker. For
those selected folders, SpaceLens reads filesystem metadata such as:

- file and folder names
- paths inside the selected folder
- file sizes and allocated disk usage
- modification and creation dates
- folder structure
- scan errors reported by macOS

SpaceLens uses this metadata locally to show disk usage, explain cleanup risk,
and help you decide what to review.

SpaceLens does not upload file contents or file metadata to external servers.

## Local Storage And Retention

SpaceLens stores the last folder you selected as an app-scoped security
bookmark, together with saved cleanup queue paths and a save timestamp, in the
app's local Application Support directory. This information stays on your Mac
and is used only to restore your review context after relaunch.

Use **Settings > General > Forget Saved Folder and Queue** to remove the saved
bookmark and queue. Removing SpaceLens app data also removes this local state.

## Cleanup Actions

SpaceLens 1.0 can move cleanup-ready files to the Bin only after you confirm
the exact target paths. Permanent deletion is not available in the Store v1
interface. Cleanup actions are limited by local safety classification rules and
your explicit selection.

## Contact

The public support contact required for App Store submission is not yet
configured. The release blocker must be closed with a durable public support
page before this policy is submitted to App Store Connect.
