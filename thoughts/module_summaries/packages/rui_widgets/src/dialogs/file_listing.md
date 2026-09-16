# packages/rui_widgets/src/dialogs/file_listing.nim

## Purpose

Reading a directory and deciding what a click on an entry means. Shared by
FileDialog and FilePicker, neither of which had ever actually scanned a
directory before this existed — both rendered an always-empty `files` field.

## Public interface

- `ParentEntry* = ".."` — the first entry of every listing.
- `listEntries*(path: string, filters: seq[string] = @[], dirsOnly = false): seq[string]`
  — `".."` first, then sorted directories (each with a trailing `/`), then
  sorted files that pass the filter. **An unreadable path yields just `@[".."]`
  rather than raising**, so a dialog pointed at a directory it cannot open still
  lets the user navigate out. Asserts the parent entry is first.
- `isDirectoryEntry*(entry: string): bool` — `".."` or a trailing `/`.
- `navigatedPath*(currentPath, entry: string): string` — where clicking `entry`
  takes you, or **`""` when it is a plain file** and the click is a selection
  instead. Walking up from the root stays at the root.
- `matchesAnyFilter*(name: string, filters: seq[string]): bool` — an empty
  filter list accepts everything.
- `matchesFilter*(name, filter: string): bool` — one filter, one name. Only the
  `*.ext` shape is treated as a glob (case-insensitive); anything else is
  compared literally.

## Usage pattern

```nim
widget.files = listEntries(widget.currentPath, widget.filters,
                           dirsOnly = widget.mode == fdDirectory)

# On a click, let the entry decide whether this is navigation or selection:
let dest = navigatedPath(widget.currentPath, widget.files[idx])
if dest.len > 0:
  widget.openDirectory(dest)     # widget-local template: re-reads, resets scroll
else:
  widget.selectedIndex = idx
```

## Circumstances

Created 2026-09-15 while restoring FileDialog and FilePicker from the widgets
deleted in `a4bcc18`. Both widgets rendered a `files` / `fileList` field that
nothing ever filled in, so the file lists were permanently empty.

`navigatedPath` and `isDirectoryEntry` were added 2026-09-16, when the refactor
pass found the same `".." → parentDir, trailing slash → descend` rule spelled
out in both dialogs.

Tested in `tests/test_restored_widgets.nim` under "restored dialogs": filter
matching (including that `notes.txtx` does **not** match `*.txt`), a real
directory scan, and the unreadable-path case.
</content>
