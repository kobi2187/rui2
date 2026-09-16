# packages/rui_widgets/src/data/datagrid.nim

## Purpose

DataTable's simpler sibling: columns addressed by index, rows carrying one
`JsonNode` per column, no per-column filters — but it can page rows in on
demand through `onLoadMore`, which DataTable cannot.

## Public interface

- `GridColumn*` — `id`, `title`, `width`, `sortable`, `formatFunc`.
- `GridRow*` — `id`, `values: seq[JsonNode]` (one per column, by index).
- `newDataGrid*(columns, data, totalRowCount = -1, rowHeight = 24.0,
  headerHeight = 28.0, showHeader, showGrid, alternateRowColor,
  visibleRows = 12, intent, onSort, onSelect, onLoadMore, onScrollNearEnd)`.
- `totalRowCount = -1` means "use `data.len`"; anything else is the claimed size
  of a lazily-loaded set, which is what makes the scrollbar the right length
  before the tail has been fetched.
- `GridMetrics*` + `metricsOf*(widget)` — `headerH`, `totalRows`, and a
  `rows: RowViewport`.
- `isSortable*`, `nextSortFor*`, `columnAt*` — as in DataTable, over `GridColumn`.
- State: `order: seq[int]` — display order into `data`, rebuilt in `layout`.

**The types are `GridColumn` / `GridRow`, not `Column` / `Row`**: `Column` is
already the name of the vertical-layout container widget, and both are exported
from `rui_widgets`.

## Usage pattern

```nim
let grid = newDataGrid(
  columns = @[GridColumn(id: "n", title: "#", width: 70.0, sortable: true)],
  data = rows, rowHeight = 22.0, visibleRows = 6)
grid.onSort = some(proc(column: int, order: SortOrder) {.closure.} = ...)

# Lazy loading: claim the full size, deliver rows as they are asked for.
let grid = newDataGrid(columns = cols, data = firstPage, totalRowCount = 100_000)
grid.onLoadMore = some(proc(startIndex, count: int) {.closure.} = ...)
```

## Circumstances

Restored 2026-09-15 from `a4bcc18`, refactored 2026-09-16 onto `GridMetrics`
and `RowViewport`.

**Sorting is deliberately skipped while lazily loading.** Ordering a set where
only a prefix is in memory would sort the visible slice and silently mis-order
everything still to be fetched, so `layout` leaves `order` alone unless
`totalRowCount < 0` or the whole set is present. `tests/test_restored_widgets.nim`
pins this down ("DataGrid leaves a lazily-loaded set unsorted").
</content>
