# packages/rui_widgets/src/virtual_rows.nim

## Purpose

The arithmetic behind every scrollable row list: which row is under the
pointer, how far the list can scroll, which slice needs drawing, and where to
scroll so a given row is on screen. Extracted because seven widgets each had
their own copy, none of them reachable by a test.

## Public interface

- `RowViewport*` — a window onto a uniform-height row list. Fields: `top`
  (screen y of the first row), `height`, `rowHeight`, `scrollY`.
- `rowViewport*(top, height, rowHeight, scrollY: float32): RowViewport` —
  constructor. Asserts `rowHeight > 0`, because a zero row height maps every
  pointer position to row 0.
- `rowAt*(v, mouseY: float32, rowCount: int): int` — row under `mouseY`, or
  **-1** above the list or past the last row. Callers index straight into their
  data with the result, so a `< 0` check is the only guard they need.
- `contentHeight*(v, rowCount: int): float32`
- `maxScroll*(v, rowCount: int): float32` — zero when everything already fits.
- `clampScroll*(v, scrollY: float32, rowCount: int): float32`
- `scrolledBy*(v, wheelDelta: float32, rowCount: int, rowsPerNotch = 3.0): float32`
  — new offset after a wheel notch, already clamped.
- `rowTop*(v, index: int): float32` — screen y of a row, which may be off screen.
- `isRowVisible*(v, index: int): bool`
- `visibleRange*(v, rowCount: int, buffer = 0): Slice[int]` — the rows worth
  drawing. **Empty lists yield `1 .. 0`**, which iterates zero times; it never
  yields `0 .. -1`, which a loop would read as row 0.
- `scrollToShow*(v, index, rowCount: int): float32` — smallest offset that puts
  a row fully on screen, leaving an already-visible row's offset alone.
- `nearEnd*(v, rowCount: int, threshold = 0.8): bool` — false when there is
  nothing to scroll, so a short list never asks a lazy loader for more forever.

## Usage pattern

```nim
# Inside a widget, via a template, because the widget type does not exist until
# definePrimitive has expanded:
template viewportOf*(widget: untyped): RowViewport =
  rowViewport(top = widget.bounds.y, height = widget.bounds.height,
              rowHeight = widget.itemHeight, scrollY = widget.scrollY)

# Hit-testing:
let idx = viewportOf(widget).rowAt(event.mousePos.y, widget.totalItems)
if idx < 0: return false

# Scrolling:
widget.scrollY = viewportOf(widget).scrolledBy(event.wheelDelta, total)

# Drawing — iterate the range directly; it cannot produce a missing index, so
# no bounds check inside the loop:
let v = viewportOf(widget)
for i in v.visibleRange(total, buffer = 5):
  drawListItem(Rect(x: b.x, y: v.rowTop(i), width: b.width, height: h), ...)
```

## Circumstances

2026-09-16. ListBox, ListView, TreeView, DataTable, DataGrid, FileDialog and
FilePicker each carried the same four calculations inside their
`definePrimitive` bodies, where `nimtools cyc` could not see them and no test
could reach them. Written as part of the refactor pass that brought
`rui_widgets` under `cyc --gate 5`.

Tested by `tests/test_virtual_rows.nim` (20 cases). Paired with
[list_input](list_input.md), which owns what a click or key press *means*
while this module owns where things are.
</content>
