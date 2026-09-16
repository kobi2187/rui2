# packages/rui_widgets/src/dialogs/filedialog.nim

## Purpose

Modal file open / save / choose-directory dialog with a working directory
listing, click-to-navigate and filtering. The modal counterpart of FilePicker.

## Public interface

- `FileDialogMode*` — `fdOpen`, `fdSave`, `fdDirectory`.
- `newFileDialog*(title = "Select File", mode = fdOpen, filters: seq[string] = @[],
  initialPath = ".", dialogWidth = 600.0, dialogHeight = 400.0,
  onSelect, onCancel)`.
- `show*(widget: FileDialog)` — display it **and read the starting directory**.
  The listing is not populated until this is called.
- `listRect*(panel)`, `okRect*(panel)`, `cancelRect*(panel)` — hit-testing and
  painting share these.
- `listViewport*(list: Rect, scrollY: float32): RowViewport`.
- `openDirectory*(widget, path)` — move and re-read, dropping the selection and
  scroll that belonged to the directory you left.
- State: `isVisible`, `currentPath`, `selectedIndex`, `hoverIndex`, `scrollY`,
  `files`, `accepted`.

`filters` are `*.ext` globs, e.g. `@["*.nim", "*.txt"]`; empty accepts all.
Escape cancels. The modal swallows every click.

## Usage pattern

```nim
let dialog = newFileDialog(title = "Open a Nim file", mode = fdOpen,
                           filters = @["*.nim"], initialPath = ".")
dialog.onSelect = some(proc(files: seq[string]) {.closure.} = ...)
dialog.onCancel = some(proc() {.closure.} = ...)
dialog.show()
```

Add it **last** among its siblings so it composites over them.

## Circumstances

Restored 2026-09-15 from `a4bcc18`. It had **never listed a directory** — the
`files` field was rendered but nothing ever filled it, and the list area was
`# TODO: Use ListView widget to show files`. Scanning now goes through
[file_listing](file_listing.md).

Sizes its bounds to the whole screen so the dim overlay has somewhere to go;
see [modal](modal.md) for why. Refactored 2026-09-16 onto `RowViewport` and
`navigatedPath`.
</content>
