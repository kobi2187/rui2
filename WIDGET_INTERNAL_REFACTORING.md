# Widget Internal Refactoring Pattern

## Overview

Separating widget **behavior** from **internal implementation** by splitting each widget into two files:
- `widget_name.nim` - Public API, props, state, actions, event handlers
- `widget_name_internal.nim` - Internal rendering logic, helper functions, calculations

## Benefits

1. **Cleaner Code**: Main widget file focuses on interface and behavior
2. **Better Testing**: Internal logic can be tested independently
3. **Easier Maintenance**: Implementation changes don't affect public API
4. **Implicit Imports**: Macro automatically imports internal file
5. **Separation of Concerns**: Behavior vs implementation

## File Structure

```
widgets/
├── basic/
│   ├── checkbox.nim              # Public API + behavior
│   ├── checkbox_internal.nim     # Internal implementation
│   ├── slider.nim
│   ├── slider_internal.nim
│   └── ...
├── containers/
│   ├── panel.nim
│   ├── panel_internal.nim
│   └── ...
└── data/
    ├── datagrid.nim
    ├── datagrid_internal.nim
    └── ...
```

## Example: Checkbox Widget

### Before (Current Monolithic Style)

```nim
# widgets/basic/checkbox.nim
import ../../core/widget_dsl_v2
import std/options
when defined(useGraphics):
  import raylib

definePrimitive(Checkbox):
  props:
    text: string = ""
    initialChecked: bool = false
    disabled: bool = false

  state:
    checked: bool
    hovered: bool

  actions:
    onToggle(checked: bool)

  events:
    on_mouse_down:
      if not widget.disabled:
        widget.checked.set(not widget.checked.get())
        if widget.onToggle.isSome:
          widget.onToggle.get()(widget.checked.get())

    on_mouse_enter:
      widget.hovered.set(true)

    on_mouse_leave:
      widget.hovered.set(false)

  render:
    when defined(useGraphics):
      var checked = widget.checked.get()
      let result = GuiCheckBox(
        widget.bounds,
        widget.text.cstring,
        addr checked
      )
      if result:
        widget.checked.set(checked)
        if widget.onToggle.isSome:
          widget.onToggle.get()(checked)
    else:
      let checkedStr = if widget.checked.get(): "[X]" else: "[ ]"
      echo checkedStr, " ", widget.text
```

### After (Separated Style)

#### widgets/basic/checkbox.nim (Behavior Only)
```nim
import ../../core/widget_dsl_v2
import std/options
import ./checkbox_internal  # Implicitly imported by macro

definePrimitive(Checkbox):
  props:
    text: string = ""
    initialChecked: bool = false
    disabled: bool = false

  state:
    checked: bool
    hovered: bool

  actions:
    onToggle(checked: bool)

  events:
    on_mouse_down:
      handleCheckboxClick(widget)  # Defined in internal

    on_mouse_enter:
      handleCheckboxHoverEnter(widget)

    on_mouse_leave:
      handleCheckboxHoverLeave(widget)

  render:
    renderCheckbox(widget)  # Defined in internal
```

#### widgets/basic/checkbox_internal.nim (Implementation)
```nim
import ../../core/widget_dsl_v2
import std/options
when defined(useGraphics):
  import raylib

# Internal helper functions
proc handleCheckboxClick*(widget: CheckboxWidget) =
  if not widget.disabled:
    let newChecked = not widget.checked.get()
    widget.checked.set(newChecked)
    if widget.onToggle.isSome:
      widget.onToggle.get()(newChecked)

proc handleCheckboxHoverEnter*(widget: CheckboxWidget) =
  widget.hovered.set(true)

proc handleCheckboxHoverLeave*(widget: CheckboxWidget) =
  widget.hovered.set(false)

proc renderCheckbox*(widget: CheckboxWidget) =
  when defined(useGraphics):
    var checked = widget.checked.get()
    let result = GuiCheckBox(
      widget.bounds,
      widget.text.cstring,
      addr checked
    )
    if result:
      widget.checked.set(checked)
      if widget.onToggle.isSome:
        widget.onToggle.get()(checked)
  else:
    let checkedStr = if widget.checked.get(): "[X]" else: "[ ]"
    echo checkedStr, " ", widget.text
```

## Complex Example: DataGrid with Virtual Scrolling

### widgets/data/datagrid.nim (Behavior Only)
```nim
import ../../core/widget_dsl_v2
import std/[options, sets, json]
import ./datagrid_internal

defineWidget(DataGrid):
  props:
    columns: seq[Column]
    data: seq[Row]
    rowHeight: float = 24.0
    headerHeight: float = 28.0
    alternateRowColor: bool = true

  state:
    selected: HashSet[int]
    sortColumn: int
    sortOrder: SortOrder
    scrollY: float
    visibleStart: int
    visibleEnd: int
    hovered: int

  actions:
    onSort(column: int, order: SortOrder)
    onSelect(selected: HashSet[int])

  events:
    on_mouse_down:
      handleDataGridClick(widget, GetMousePosition())

  render:
    renderDataGrid(widget)
```

### widgets/data/datagrid_internal.nim (Implementation)
```nim
import ../../core/widget_dsl_v2
import std/[options, sets, json, math]
when defined(useGraphics):
  import raylib

# Virtual scrolling calculations
proc calculateVisibleRange*(widget: DataGridWidget): tuple[start, end: int] =
  let scroll = widget.scrollY.get()
  let rowH = widget.rowHeight
  let viewHeight = widget.bounds.height - widget.headerHeight

  let bufferRows = 10
  let visStart = max(0, int(scroll / rowH) - bufferRows)
  let visEnd = min(widget.data.len - 1, int((scroll + viewHeight) / rowH) + bufferRows)

  result = (visStart, visEnd)

# Mouse interaction handling
proc handleDataGridClick*(widget: DataGridWidget, mousePos: Vector2) =
  # Complex click handling logic
  if CheckCollisionPointRec(mousePos, widget.bounds):
    # Determine if header click (sort) or row click (select)
    if mousePos.y < widget.bounds.y + widget.headerHeight:
      handleHeaderClick(widget, mousePos)
    else:
      handleRowClick(widget, mousePos)

proc handleHeaderClick(widget: DataGridWidget, mousePos: Vector2) =
  # Calculate which column was clicked
  var x = widget.bounds.x
  for colIdx, col in widget.columns:
    if mousePos.x >= x and mousePos.x < x + col.width:
      # Toggle sort
      if colIdx == widget.sortColumn.get():
        widget.sortOrder.set(
          if widget.sortOrder.get() == soAscending:
            soDescending
          else:
            soAscending
        )
      else:
        widget.sortColumn.set(colIdx)
        widget.sortOrder.set(soAscending)

      if widget.onSort.isSome:
        widget.onSort.get()(colIdx, widget.sortOrder.get())
      break
    x += col.width

proc handleRowClick(widget: DataGridWidget, mousePos: Vector2) =
  # Calculate which row was clicked
  let scroll = widget.scrollY.get()
  let rowH = widget.rowHeight
  let dataAreaY = widget.bounds.y + widget.headerHeight
  let relY = mousePos.y - dataAreaY + scroll
  let rowIdx = int(relY / rowH)

  if rowIdx >= 0 and rowIdx < widget.data.len:
    let ctrlDown = IsKeyDown(KEY_LEFT_CONTROL) or IsKeyDown(KEY_RIGHT_CONTROL)
    var newSelection = widget.selected.get()

    if ctrlDown:
      if rowIdx in newSelection:
        newSelection.excl(rowIdx)
      else:
        newSelection.incl(rowIdx)
    else:
      newSelection = [rowIdx].toHashSet

    widget.selected.set(newSelection)

    if widget.onSelect.isSome:
      widget.onSelect.get()(newSelection)

# Rendering implementation
proc renderDataGrid*(widget: DataGridWidget) =
  when defined(useGraphics):
    # All the complex rendering logic
    drawDataGridBackground(widget)
    drawDataGridHeader(widget)
    drawDataGridRows(widget)
    drawDataGridScrollbar(widget)
  else:
    printDataGridDebug(widget)

proc drawDataGridBackground(widget: DataGridWidget) =
  DrawRectangleRec(widget.bounds, Color(r: 255, g: 255, b: 255, a: 255))

proc drawDataGridHeader(widget: DataGridWidget) =
  var x = widget.bounds.x
  for colIdx, col in widget.columns:
    let headerRect = Rectangle(
      x: x,
      y: widget.bounds.y,
      width: col.width,
      height: widget.headerHeight
    )
    # ... header rendering logic
    x += col.width

proc drawDataGridRows(widget: DataGridWidget) =
  let (visStart, visEnd) = calculateVisibleRange(widget)
  widget.visibleStart.set(visStart)
  widget.visibleEnd.set(visEnd)

  BeginScissorMode(
    widget.bounds.x.cint,
    widget.bounds.y.cint,
    widget.bounds.width.cint,
    widget.bounds.height.cint
  )

  # Only render visible rows
  for rowIdx in visStart..visEnd:
    # ... row rendering logic

  EndScissorMode()

proc drawDataGridScrollbar(widget: DataGridWidget) =
  # ... scrollbar rendering logic
  discard

proc printDataGridDebug(widget: DataGridWidget) =
  echo "DataGrid: ", widget.data.len, " rows"
  echo "  Visible: ", widget.visibleStart.get(), " to ", widget.visibleEnd.get()
```

## Macro Support

The `definePrimitive` and `defineWidget` macros should be enhanced to:

1. **Auto-detect** `{widget_name}_internal.nim` file
2. **Auto-import** if it exists
3. **Provide type** to internal file (e.g., `CheckboxWidget`)

### Enhanced Macro Pseudocode

```nim
macro definePrimitive*(name: untyped, body: untyped): untyped =
  let widgetName = name.strVal
  let internalFile = widgetName.toLowerAscii() & "_internal.nim"

  result = newStmtList()

  # Check if internal file exists
  if fileExists(getCurrentDir() / internalFile):
    result.add quote do:
      import `.` / `internalFile`

  # Generate widget type (accessible to internal file)
  result.add quote do:
    type `name`Widget* = ref object of Widget
      # ... generated fields

  # Rest of macro expansion
  # ...
```

## Migration Strategy

1. **Phase 1**: Create internal files for complex widgets first
   - DataGrid, DataTable, TreeView
   - Canvas, MapWidget, Timeline

2. **Phase 2**: Refactor simpler widgets
   - All basic widgets
   - All container widgets

3. **Phase 3**: Update macro to auto-import
   - Detect `_internal.nim` files
   - Generate proper types
   - Add import statements

4. **Phase 4**: Update documentation and examples
   - Show both patterns
   - Recommend internal files for complex widgets

## Testing Strategy

### Test Internal Functions Independently
```nim
# tests/test_datagrid_internal.nim
import ../widgets/data/datagrid_internal
import unittest

suite "DataGrid Internal Functions":
  test "calculateVisibleRange with small dataset":
    var widget = newDataGrid(...)
    widget.scrollY.set(0.0)
    let (start, end) = calculateVisibleRange(widget)
    check start == 0
    check end == 10

  test "calculateVisibleRange with scroll offset":
    var widget = newDataGrid(...)
    widget.scrollY.set(240.0)  # 10 rows * 24px
    let (start, end) = calculateVisibleRange(widget)
    check start == 0   # buffer
    check end == 20
```

## Advantages

1. **Testability**: Internal functions can be unit tested
2. **Readability**: Main file shows "what", internal shows "how"
3. **Modularity**: Implementation can be swapped without changing API
4. **Documentation**: Behavior is clear in main file
5. **Maintenance**: Bugs in rendering don't affect event handling
6. **Collaboration**: Different developers can work on behavior vs implementation

## Example File Sizes

Before (Monolithic):
- `datagrid.nim`: 450 lines (behavior + rendering + logic)

After (Separated):
- `datagrid.nim`: 80 lines (behavior only)
- `datagrid_internal.nim`: 370 lines (rendering + logic)

**Result**: Main file is 5x smaller and much easier to understand!

## Implementation Checklist

- [ ] Enhance macro to detect `_internal.nim` files
- [ ] Enhance macro to auto-import internal files
- [ ] Generate widget type definitions accessible to internal
- [ ] Refactor DataGrid as proof of concept
- [ ] Refactor DataTable
- [ ] Refactor TreeView
- [ ] Refactor MapWidget, Canvas, Timeline
- [ ] Refactor all other widgets
- [ ] Update documentation
- [ ] Add tests for internal functions
- [ ] Update examples to show pattern

## Notes

- Internal files are **optional** - simple widgets can stay monolithic
- Internal files **export** functions so they're accessible to main file
- Widget type name convention: `{WidgetName}Widget` (e.g., `CheckboxWidget`)
- Internal functions use `*` export marker for visibility
