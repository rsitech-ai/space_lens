# SpaceLens 1.1.1

Full-folder scans now retain at most 10,000 result nodes across the hierarchy,
with up to 256 children per folder. Every accessible descendant is measured;
folders beyond the detail budget are measured without constructing a result
object for every file. Large scans disclose the limited detail and direct users
to a smaller folder or Smart Scan for additional cleanup candidates.

- Directory enumeration streams entries and drains temporary Foundation objects.
- The scan shows traversal, application activity checks, candidate safety checks,
  and summary preparation as distinct phases.
- Stopping a scan cancels classification as well as filesystem traversal.
- Full Scan rejects folders that resolve outside the selected root and skips
  duplicate Data-volume aliases during a whole-drive scan.
- Scan Errors includes an affected parent when unreadable descendants were
  omitted from retained details. Skipped aliases and inaccessible folders appear
  as warnings; a completed scan does not imply that macOS permitted every read.

Cleanup rules, fresh activity checks, identity validation, and recoverable Bin
operations continue to apply. No worktree is assumed disposable because of age.

## Limits

Cleanup estimates cover retained candidates rather than every file that was
measured. Smart Scan independently searches known cleanup locations. Symlinks
are measured without following their targets. macOS privacy controls can block
system or user folders; affected trees remain unavailable for cleanup.

Full-drive totals count accessible files through canonical folder paths. Allocated
sizes are filesystem metadata estimates; APFS clones, hard links, compression,
and purgeable storage can differ from physical reclaimable space.
