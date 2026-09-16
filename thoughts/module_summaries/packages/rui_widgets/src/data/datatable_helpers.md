# packages/rui_widgets/src/data/datatable_helpers.nim

## Purpose

Pure logic behind the tabular widgets: filter matching, value comparison for
sorting, and cell formatting. No rui imports at all — it depends only on
`std/[json, strutils, tables]`, which is what keeps it testable in isolation.

## Public interface

- `FilterKind*` — `fkNone`, `fkEquals`, `fkContains`, `fkStartsWith`,
  `fkEndsWith`, `fkGreater`, `fkLess`, `fkBetween`, `fkIn`.
- `Filter*` — a variant object keyed on `FilterKind`, carrying `text`, `value`,
  `min`/`max` or `values` as appropriate.
- `TableRow*` — `id`, `values: Table[string, JsonNode]`.
- `SortOrder*` — `soNone`, `soAscending`, `soDescending`. **Shared** by
  DataTable and DataGrid.
- Value access: `getStringValue*`, `getNumericValue*`, `isStringValue*`,
  `isNumericValue*`, `hasColumn*`.
- Matching: `matchesEquals*`, `matchesContains*`, `matchesStartsWith*`,
  `matchesEndsWith*`, `matchesIn*`, `matchesGreater*`, `matchesLess*`,
  `matchesBetween*`, `matchesFilter*`, `matchesColumnFilter*`, `isNoneFilter*`.
- Comparison: `compareStrings*`, `compareNumbers*`, `compareValues*`,
  `compareRows*`.
- Formatting: `formatCellValue*`, `getCellText*`, `getFilterKindLabel*`,
  `getFilterValueText*`.
- Scrollbar maths: `calcScrollbarThumbHeight*`, `calcScrollbarThumbY*`,
  `calcScrollFromMouseY*`, `isRowVisible*` — **superseded by
  [virtual_rows](../virtual_rows.md)**; kept for now, but new code should use
  `RowViewport`.
- Re-exports `toggleSelection`, `setSingleSelection` and `updateSelection` from
  [list_input](../list_input.md).

## Usage pattern

```nim
var values = initTable[string, JsonNode]()
values["name"] = %"ada"
let row = TableRow(id: "ada", values: values)

if row.matchesColumnFilter("name", Filter(column: "name",
                                          kind: fkStartsWith, text: "a")):
  ...
```

## Circumstances

Survived `a4bcc18`'s deletion sweep intact and compiled unchanged when the rest
of the data widgets were restored 2026-09-15 — it has no rui dependencies to go
stale.

Two changes since:

- **`SortOrder` moved here** (2026-09-16). DataTable and DataGrid each declared
  their own, which made `soNone` and friends ambiguous once both were exported
  from `data.nim`. Note that `std/algorithm` also exports a `SortOrder`, so
  modules needing `sort` import it with `from std/algorithm import sort` rather
  than plainly.
- **Selection moved out to `list_input`** and is re-exported from here, because
  ListBox, ListView and FilePicker need the same rules and this module is not
  where a non-table widget should be reaching.
</content>
