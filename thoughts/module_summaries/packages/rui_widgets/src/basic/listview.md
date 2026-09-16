# packages/rui_widgets/src/basic/listview.nim

## Purpose

Scrollable list with mouse selection and an optional scrollbar — the
mouse-driven sibling of ListBox (which adds keyboard navigation and a focus
row). Virtual rendering: a list of ten thousand rows costs the same to draw as
a list of ten.

## Public interface

- `newListView*(items: seq[string] = @[], totalItemCount = -1, itemHeight = 24.0,
  visibleRows = 8, multiSelect = false, showScrollbar = true, disabled = false,
  intent = Default, onSelect, onItemClick, onLoadMore, onScrollNearEnd)`.
- `totalItems*(widget)`, `viewportOf*(widget): RowViewport`.
- State: `selection: HashSet[int]`, `hoverIndex`, `scrollY`,
  `visibleStart` / `visibleEnd`.
- Re-exports `virtual_rows` and `list_input`.

Rows past the loaded tail draw as `"Loading..."` rather than being skipped, so
the scrollbar stays honest while a lazy loader catches up.

## Usage pattern

```nim
var rows: seq[string]
for i in 0 ..< 10_000: rows.add("row " & $i)

let view = newListView(items = rows, itemHeight = 24.0, visibleRows = 6,
                       multiSelect = true)
view.onSelect = some(proc(selection: HashSet[int]) {.closure.} = ...)
```

## Circumstances

Restored 2026-09-15 from `a4bcc18`, same render-time input polling as ListBox
and the same fix. Refactored 2026-09-16 onto `RowViewport` and `list_input`.

Note the width reservation: when the content is taller than the view and
`showScrollbar` is set, rows are drawn `ScrollbarWidth` narrower so text does
not run under the bar.
</content>
