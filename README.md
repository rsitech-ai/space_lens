# SpaceLens

SpaceLens is a native macOS disk intelligence app. It scans filesystem
metadata, explains large disk consumers, classifies cleanup risk with local
rules, and queues review candidates before cleanup.

## Run

```bash
./script/build_and_run.sh --verify
```

## Test

```bash
swift test
```

## Workflow

- Click table headers to sort scanned files.
- Use search and the filter segmented control to narrow visible results.
- Use Select All or Select Safe to build a multi-selection.
- Use the bottom action bar to queue, move to Bin, or permanently delete only
  cleanup-ready items.

## Safety

Cleanup is safety-gated. SpaceLens enables Move to Bin and Delete Forever only
for items classified as safe temp, rebuildable cache, or generated output. Move
to Bin asks for confirmation; Delete Forever requires typing `DELETE`.
