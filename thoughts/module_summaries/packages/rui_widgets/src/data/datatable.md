# packages/rui_widgets/src/data/datatable.nim

## Purpose

Tabular data with per-column filtering, click-to-sort headers and virtual
scrolling, sized for large datasets: only the rows on screen are ever drawn.
The filter/sort sibling of DataGrid, which trades filters for lazy loading.

## Public interface

- `ColumnDef*` — `id`, `title`, `width`, `sortable`, `filterable`,
  `filterKinds`, `formatFunc: Option[proc(JsonNode): string]`.
- `newDataTable*(columns, data, rowHeight = 24.0, headerHeight = 28.0,
  filterHeight = 26.0, showHeader, showFilter, showGrid, alternateRowColor,
  visibleRows = 12, intent, onSort, onFilter, onSelect)` — the generated
  constructor.
- State worth knowing: `selected: HashSet[int]` (indices into `data`, **not**
  into the filtered view, so a selection survives a change of filter),
  `filters: Table[string, Filter]`, `sortColumn: string`, `sortOrder`,
  `filteredIndices: seq[int]`.
- `TableMetrics*` + `metricsOf*(widget)` — band geometry: `filterH`, `headerH`,
  `headerTop`, and a `rows: RowViewport` that owns all the row arithmetic.
- `passesFilters*(row: TableRow, filters): bool` — the conjunction.
- `isSortable*(columns, idx): bool`, `nextSortFor*(columns, idx, currentColumn,
  currentOrder): SortOrder` — the header-click cycle, pure and testable.
- `columnAt*(columns, originX, mouseX): int` — column under the pointer, or -1.
- Re-exports `datatable_helpers` (Filter, TableRow, SortOrder, matching,
  comparison) and `virtual_rows`.

## Usage pattern

```nim
let table = newDataTable(
  columns = @[ColumnDef(id: "name", title: "Name", width: 160.0,
                        sortable: true, filterable: true)],
  data = rows, rowHeight = 22.0, visibleRows = 5)

# Filters are set from code; the strip displays what is active. Editing a
# filter through the UI is NOT wired up.
table.filters["role"] = Filter(column: "role", kind: fkContains, text: "engineer")

table.onSelect = some(proc(selected: HashSet[int]) {.closure.} = ...)
```

## Circumstances

Restored 2026-09-15 from `a4bcc18` and ported. Two things were wrong in the
original beyond the raygui removal: it rebuilt the filtered index list from
scratch inside `render`, over the whole dataset, on every frame — that now
happens in `layout`, when the data or filters change. And it re-declared
`Filter`/`TableRow` locally with a second matcher that guarded every string
test with `value.kind == JString`, so a numeric cell silently passed every text
filter; it now uses `datatable_helpers`.

Refactored 2026-09-16: geometry into `TableMetrics`, the sort cycle into pure
procs, and the row arithmetic onto `RowViewport`. `cyc` reported "0 routines"
for this file before that, because everything lived inside the macro body.
</content>
