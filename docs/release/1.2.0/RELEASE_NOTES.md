# SpaceLens 1.2.0

- Queue inspected Needs Review and Valuable Data items without treating them as automatically safe.
- Review exact target paths and acknowledge the risk before manually moving data to the Bin.
- Refresh activity checks before every Bin operation. Manual moves force a new probe after folder inspection; automatic batches reuse activity for at most two seconds. Active tools, protected system data, symbolic links, incomplete scans, changed targets and paths outside the authorized scan remain blocked.
- Independently inspect all contents of manually selected folders before moving them, including items omitted from the bounded display tree.
- Keep simulator device state managed by Xcode, simctl or Android Studio; raw device cleanup remains blocked.
- Preserve failed-item messages when other items in a batch move successfully.
- Restore queued manual items as review-required after relaunch. Approval is never persisted.
- Rescan preserves Smart Scan mode.

Developer ID signed direct distribution, hardened runtime, macOS 14 or later. No files are removed automatically; space is reclaimed when the user empties the Bin in Finder.

- Keep selected size and estimated session Moved to Bin totals visible after selection clears. Bin totals do not claim reclaimed disk space.
- Use one final activity probe for reviewed files and fresh probes before/after manual folder checks and defer repeated queue persistence until a cleanup batch finishes.

- Keep checked/files/folders/size/error tiles visible during Smart discovery, showing pending sizing until actual measurement.
