# File Table Location and Row States

## Outcome

Make every file-table row answer two questions without requiring the inspector:

1. Where does this item come from?
2. Is this item currently selected or already in the cleanup queue?

The change applies to the existing macOS SwiftUI file table. It does not change
scan coverage, cleanup eligibility, queue semantics, or deletion behavior.

## Current Problem

The Name column shows only the final path component. Large scans contain many
identically named build artifacts, so the filename alone is ambiguous. The
inspector contains the absolute path, but it is too long for rapid comparison
and requires selecting each row.

The native table selection is subtle, particularly when the window is not the
active key window. Queue membership is communicated mainly in the inspector and
bottom action bar, so a user can lose track of queued items while reviewing the
table.

## Approved Design

### Name Cell

Each Name cell uses two lines:

- The first line is the existing filename or folder name.
- The second line is the parent directory expressed relative to the current
  user's home directory.

For example:

```text
pack-93637d62255-caf3f93a3439cf5cb6e76f451501d.pack
~/dev/apps/ksef-merge-overpay/…/GRDB.swift/.build/repositories
```

The location line omits the filename because the first line already presents
it. Paths inside the home directory replace the home prefix with `~`. Paths
outside the home directory remain absolute so the displayed location is never
misleading. The location uses middle truncation, preserving both its origin and
the nearest parent folders. Hover help exposes the complete absolute path.

The filename remains the sorting key. The additional location is presentation
metadata and must not change table ordering.

### Selected State

The existing native macOS table selection remains the authoritative selection
state and continues to cover the row. The Name cell adds a visible accent
selection marker so selection remains recognizable when the native highlight
becomes inactive gray.

Selection remains keyboard- and multi-selection-compatible. The implementation
must not replace the native `Table` selection binding or introduce independent
UI selection state.

### Queued State

An item in the cleanup queue receives a persistent green visual treatment in
the Name cell:

- a green checkmark or tray-check indicator;
- a compact `Queued` label when available width permits it;
- a restrained green tint that remains distinguishable from selection.

When an item is both selected and queued, the accent selection treatment remains
primary and the green queue indicator remains visible. Selection and queue
membership must never be represented by the same color or icon.

Queue membership lookup must be constant-time for row rendering. The table can
display hundreds of thousands of rows, so rendering a cell must not linearly
scan the cleanup queue.

### Responsive Behavior

The two-line Name cell is used at all supported table widths:

- Typical and wide layouts show the filename, location, queue icon, and `Queued`
  label.
- Compact layouts retain the filename and location but may omit the text label,
  keeping the queue icon.
- Both lines use middle truncation instead of shrinking to illegibility.

The change must not add a separate Location or Status column. Existing Size,
Kind, Modified, Safety, and Recommendation columns retain their responsive
breakpoints.

### Accessibility

The row's Name cell exposes a combined accessibility description containing:

- the full filename;
- the complete absolute path;
- `Selected` when selected;
- `Queued for cleanup` when queued.

Color is never the only state indicator. Selection and queue membership each
have a distinct icon and text or accessibility description.

## Architecture

Pure presentation logic will format a file's parent path and describe its row
state. The SwiftUI cell consumes that presentation instead of recomputing path
rules inline.

`AppState` remains the source of truth for selection and cleanup queue
membership. It will expose queue membership through a set or equivalent cached
lookup keyed by the scanned node identity. Updating the queue must update this
lookup in the same observable state transition.

The feature must not perform filesystem I/O during row rendering.

## Performance Constraints

- Path presentation is derived from already-scanned node metadata.
- Queue checks are `O(1)` per rendered row.
- No synchronous filesystem calls occur in `body` or cell helpers.
- No per-row animation is added.
- Table virtualization and existing sort caching remain intact.

These constraints are required because realistic scans can contain more than
100,000 visible items.

## Testing

Focused automated tests will cover:

1. A path inside the home directory becomes a `~/…` parent location.
2. The home directory itself displays as `~`.
3. A path outside the home directory remains absolute.
4. The filename is omitted from the secondary location line.
5. Queue membership becomes visible immediately after queueing and disappears
   after removal.
6. Selected, queued, and combined states produce distinct presentation and
   accessibility descriptions.
7. Existing responsive layout thresholds and table selection behavior remain
   unchanged.

Tests for new pure behavior will be written and observed failing before
production implementation.

## Runtime Verification

The built app will be exercised with a fixture containing repeated filenames in
different nested directories. Verification will confirm:

- home-relative paths distinguish duplicate filenames;
- narrow and wide window layouts remain readable;
- selection is clearly visible;
- queue state persists after selection moves to another row;
- selected-and-queued state remains unambiguous;
- filtering and sorting continue to work;
- no cleanup action is executed during UI verification.

## Non-Goals

- Changing Smart Scan or full-scan coverage.
- Changing cleanup classification or safety policy.
- Automatically moving queued items to the Bin.
- Adding path-based grouping, breadcrumbs, or a new table column.
- Redesigning the inspector.
