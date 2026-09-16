# packages/rui_widgets/src/modern/dragdroparea.nim

## Purpose

A drop target for files and directories, with drag-over feedback and a
click-to-browse fallback. Filters drops by kind, extension and size.

## Public interface

- `DropMode*` — `dmFiles`, `dmDirectories`, `dmBoth`.
- `DroppedItem*` — `path`, `isDirectory`, `size`.
- `DropVerdict*` — `accepted`, `item`, `reason`. One path's decision.
- `DropBatch*` — `accepted`, `rejected`, `reason`. One drop event's outcome.
- `newDragDropArea*(mode = dmFiles, acceptedExtensions: seq[string] = @[],
  maxFileSize = 100_000_000, multiple = true, promptText, hoverText,
  borderWidth = 2.0, borderDashed = true, cornerRadius = 8.0, intent,
  onFilesDropped, onFilesRejected, onClick)`.
- **`pollFileDrops*(widget: DragDropArea)` — call once per frame.**
- The policy, testable without a widget:
  `judgeDrop*(mode, allowed: seq[string], maxSize: int64, path: string): DropVerdict`,
  `modeRejection*(mode, isDir): string`,
  `extensionRejection*(path, allowed): string`.

## Usage pattern

```nim
let drop = newDragDropArea(mode = dmFiles, acceptedExtensions = @[".nim"],
                           promptText = "Drag .nim files here")
drop.onFilesDropped = some(proc(files: seq[DroppedItem]) {.closure.} = ...)
drop.onFilesRejected = some(proc(files: seq[string], reason: string) {.closure.} = ...)

# Drops are not GuiEvents, so the app asks for them each frame:
app.onFrame = some(proc() {.closure.} = drop.pollFileDrops())
```

## Circumstances

Restored 2026-09-15 from `a4bcc18`, where it called raylib's `IsFileDropped()`
from inside `render` — so a drop was noticed only on frames where the widget
happened to be repainting, and the callbacks fired mid-paint.

**`App.onFrame` was added for this widget** (`packages/rui/src/app.nim`), since
window file drops never reach `handleInput`: they are not `GuiEvent`s and the
event manager has no source for them.

Refactored 2026-09-16: `classify` was doing two jobs at cc=10, deciding *and*
accumulating. `judgeDrop` takes the rules rather than the widget, which is what
makes the policy testable — there was previously no way to ask "is a 2GB .txt
accepted here" without a window and a real drop event.
</content>
