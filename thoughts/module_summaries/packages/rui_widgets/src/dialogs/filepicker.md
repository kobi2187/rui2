# packages/rui_widgets/src/dialogs/filepicker.nim

## Purpose

An **embeddable** file picker: path strip on top, scrollable directory listing
below. Not modal, no buttons — drop it into any container and listen to
`onSelect`.

## Public interface

- `FilePickerMode*` — `fpOpen`, `fpSave`, `fpDirectory`.
- `newFilePicker*(mode = fpOpen, filters: seq[string] = @[], initialPath = ".",
  multiSelect = false, intent = Default, onSelect, onPathChange)`.
- `refresh*(widget: FilePicker)` — re-read the current directory, e.g. after
  something on disk changed.
- `listTopOf*(widget)`, `viewportOf*(widget): RowViewport`,
  `openDirectory*(widget, path)`.
- State: `currentPath`, `selectedFiles: HashSet[string]` (**full paths**, not
  indices), `fileList`, `scrollY`, `hoverIndex`, `loaded`.

**The directory is read on first `layout`**, not at construction: a widget
built by the DSL constructor has no chance to run code of its own before then.
`loaded` is the once-only flag.

## Usage pattern

```nim
let picker = newFilePicker(mode = fpOpen, filters = @["*.nim"],
                           initialPath = ".", multiSelect = true)
picker.bounds = Rect(x: 0, y: 0, width: 600, height: 260)
picker.onSelect = some(proc(paths: HashSet[string]) {.closure.} = ...)
picker.onPathChange = some(proc(path: string) {.closure.} = ...)
```

## Circumstances

Restored 2026-09-15 from `a4bcc18`, where it wrapped raygui's `GuiListView` and,
like FileDialog, never actually scanned anything — `fileList` was a
`# in real implementation, scan directory` comment.

Refactored 2026-09-16 onto `RowViewport`, `navigatedPath` and `list_input`.
Selecting by path rather than index is why `list_input`'s selection helpers are
generic over the key.
</content>
