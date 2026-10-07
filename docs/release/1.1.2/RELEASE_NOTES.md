# SpaceLens 1.1.2

Smart Scan now drains temporary Foundation filesystem objects per discovery entry.
Its discovery stage shows checked filesystem locations and pending sizing, then
transitions to measured candidate files and bytes. Discovery visits stay separate
from the final measured totals.

Cleanup eligibility, activity checks, worktree protection, identity validation,
discovery budgets, and recoverable Bin behavior are unchanged. Incomplete
discovery remains disclosed; no files are removed automatically.
