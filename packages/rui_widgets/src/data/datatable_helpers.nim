## DataTable helpers -- the barrel.
##
## This was a 329-line module holding filtering, sorting, cell formatting,
## selection and two superseded copies of the scrolling arithmetic. It is three
## focused modules now, re-exported here because DataTable, DataGrid and the
## tests all reach for them through this name:
##
##   table_values.nim   reading a cell: JSON accessors and display formatting
##   table_filters.nim  the filter language and what each kind matches
##   table_sorting.nim  SortOrder and the comparisons
##
## Deleted rather than moved: calcTotalHeight, calcMaxScroll,
## calcVisibleStart/End/Range, calcRowY, isRowVisible, calcScrollbarThumbHeight,
## calcScrollbarThumbY and calcScrollFromMouseY. Nothing called any of them.
## RowViewport in ../virtual_rows.nim and ScrollExtent in
## ../containers/scroll_geometry.nim answer the same questions with viewports
## and extents as values rather than as loose float parameters, and are what the
## widgets actually use. This module's own isRowVisible was already shadowed by
## RowViewport's.

import table_values
import table_filters
import table_sorting
import ../list_input

export table_values, table_filters, table_sorting

# Selection is not table-specific -- ListBox, ListView and FilePicker need the
# same rules -- so it lives in ../list_input and is re-exported here for the
# callers and tests that already reach for it through this module.
export list_input.toggleSelection, list_input.setSingleSelection,
       list_input.updateSelection
