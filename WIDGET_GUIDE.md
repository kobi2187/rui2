# Widget Development Guide

**Last Updated**: 2025-11-10

## Current Widget Library Status

**Completion**: 44 unique widgets (52 files including variants)
**DSL**: v2 system with `definePrimitive` and `defineWidget` macros (widget_dsl_v2.nim, 866 lines)
**Organization**: Categorized by functionality in subdirectories
**Total Code**: 6,280 lines of widget code across all files

---

## Directory Structure

```
widgets/
├── basic/                    # 19 files (16 unique + variants)
│   ├── button.nim                 - Basic button widget
│   ├── button_v2.nim              - Button variant
│   ├── button_yaml.nim            - Button with YAML-UI style events
│   ├── checkbox.nim               - Toggle checkbox
│   ├── combobox.nim               - Dropdown selection
│   ├── iconbutton.nim             - Icon-based button
│   ├── label.nim                  - Text display with theme support
│   ├── link.nim                   - Clickable hyperlink
│   ├── listbox.nim                - List selection
│   ├── listview.nim               - Enhanced list view
│   ├── numberinput.nim            - Numeric text input
│   ├── progressbar.nim            - Progress indicator
│   ├── radiobutton.nim            - Radio button control
│   ├── scrollbar.nim              - Scrollbar control
│   ├── separator.nim              - Visual separator line
│   ├── slider.nim                 - Value slider
│   ├── spinner.nim                - Numeric spinner
│   ├── toolbutton.nim             - Toolbar button
│   └── tooltip.nim                - Hover tooltip
├── containers/               # 14 files (10 unique + variants)
│   ├── column.nim                 - Legacy column (use vstack)
│   ├── groupbox.nim               - Titled group box
│   ├── hstack.nim                 - Horizontal stack layout
│   ├── hstack_v2.nim              - HStack variant
│   ├── panel.nim                  - Bordered container
│   ├── radiogroup.nim             - Radio button group
│   ├── scrollview.nim             - Scrollable container
│   ├── spacer.nim                 - Flexible spacing
│   ├── statusbar.nim              - Status bar
│   ├── tabcontrol.nim             - Tabbed interface
│   ├── toolbar.nim                - Toolbar container
│   ├── vstack.nim                 - Vertical stack layout
│   ├── vstack_v2.nim              - VStack variant
│   └── zstack_v2.nim              - Z-axis stacking container
├── menus/                    # 4 menu widgets
│   ├── contextmenu.nim            - Context menu
│   ├── menu.nim                   - Dropdown menu
│   ├── menubar.nim                - Menu bar
│   └── menuitem.nim               - Menu item
├── dialogs/                  # 3 dialog widgets
│   ├── filedialog.nim             - File selection dialog
│   ├── filepicker.nim             - File picker widget
│   └── messagebox.nim             - Message dialog
├── data/                     # 4 files (3 widgets + helpers)
│   ├── datagrid.nim               - Data grid with virtual scrolling
│   ├── datatable.nim              - Filterable data table
│   ├── datatable_helpers.nim      - Helper functions for datatable
│   └── treeview.nim               - Hierarchical tree
├── modern/                   # 4 modern widgets
│   ├── canvas.nim                 - Interactive drawing canvas
│   ├── dragdroparea.nim           - File drag-drop area
│   ├── mapwidget.nim              - Map visualization
│   └── timeline.nim               - Timeline visualization
├── input/                    # 1 input widget
│   └── textinput.nim              - Single-line text input
└── primitives/               # 3 primitive widgets
    ├── circle.nim                 - Circle primitive
    ├── label.nim                  - Label primitive
    └── rectangle.nim              - Rectangle primitive

Total: 52 files, 44 unique widgets
```

---

## Import Paths

### From Project Root
```nim
# Basic widgets
import widgets/basic/label
import widgets/basic/button
import widgets/basic/checkbox

# Input widgets
import widgets/input/textinput

# Container widgets
import widgets/containers/vstack
import widgets/containers/hstack

# Menu widgets
import widgets/menus/menubar

# Dialog widgets
import widgets/dialogs/messagebox

# Data widgets
import widgets/data/datagrid

# Modern widgets
import widgets/modern/canvas
```

### From Examples Directory
```nim
# Import multiple widgets
import ../widgets/basic/[button_yaml, label, checkbox]
import ../widgets/containers/vstack
import ../widgets/data/datagrid
```

---

## Widget Development Patterns

### Pattern 1: Simple Widgets (Monolithic)

For simple widgets with minimal logic, keep everything in one file:

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

**Use when**: Widget is under ~150 lines, simple logic, minimal rendering

---

### Pattern 2: Complex Widgets (Separated with Internal File)

For complex widgets, separate behavior from implementation:

#### Main File (Behavior)
```nim
# widgets/data/datagrid.nim
import ../../core/widget_dsl_v2
import std/[options, sets, json]
import ./datagrid_internal

defineWidget(DataGrid):
  props:
    columns: seq[Column]
    data: seq[Row]
    rowHeight: float = 24.0
    headerHeight: float = 28.0

  state:
    selected: HashSet[int]
    sortColumn: int
    sortOrder: SortOrder
    scrollY: float
    visibleStart: int
    visibleEnd: int

  actions:
    onSort(column: int, order: SortOrder)
    onSelect(selected: HashSet[int])

  events:
    on_mouse_down:
      handleDataGridClick(widget, GetMousePosition())

  render:
    renderDataGrid(widget)
```

#### Internal File (Implementation)
```nim
# widgets/data/datagrid_internal.nim
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

# Event handling
proc handleDataGridClick*(widget: DataGridWidget, mousePos: Vector2) =
  if CheckCollisionPointRec(mousePos, widget.bounds):
    if mousePos.y < widget.bounds.y + widget.headerHeight:
      handleHeaderClick(widget, mousePos)
    else:
      handleRowClick(widget, mousePos)

# Rendering implementation
proc renderDataGrid*(widget: DataGridWidget) =
  when defined(useGraphics):
    drawDataGridBackground(widget)
    drawDataGridHeader(widget)
    drawDataGridRows(widget)
    drawDataGridScrollbar(widget)
  else:
    printDataGridDebug(widget)

# ... more internal functions
```

**Use when**:
- Widget exceeds ~150 lines
- Complex rendering logic
- Multiple helper functions
- Virtual scrolling or optimization needed
- Multiple developers working on same widget

**Benefits**:
- Main file shows "what", internal shows "how"
- Internal functions can be unit tested
- Easier to maintain and understand
- Better separation of concerns

---

## Widget DSL Reference

### definePrimitive vs defineWidget

**definePrimitive**: For leaf widgets (no children)
```nim
definePrimitive(Button):
  props: ...
  state: ...
  render: ...
```

**defineWidget**: For container widgets (has children)
```nim
defineWidget(VStack):
  props: ...
  state: ...
  layout: ...  # Position children
  render: ...  # Render self + children
```

### Available Sections

| Section | Purpose | Required |
|---------|---------|----------|
| `props:` | Immutable configuration | Optional |
| `state:` | Mutable state (Link[T]) | Optional |
| `actions:` | Callbacks (Option[proc]) | Optional |
| `events:` | Event handlers (on_click, etc.) | Optional |
| `init:` | Initialization code | Optional |
| `render:` | Drawing code | Required |
| `layout:` | Position children | Optional (containers) |
| `measure:` | Size calculation | Optional |

### State Management

All mutable state uses `Link[T]`:

```nim
state:
  checked: bool      # Becomes Link[bool]
  value: float       # Becomes Link[float]
  items: seq[string] # Becomes Link[seq[string]]

# Access in code:
widget.checked.get()     # Read
widget.checked.set(true) # Write
```

### Event Handlers

YAML-UI style events are automatically mapped:

```nim
events:
  on_click:         # Mouse click
    # code
  on_mouse_down:    # Mouse button down
    # code
  on_mouse_up:      # Mouse button up
    # code
  on_mouse_enter:   # Mouse enters bounds
    # code
  on_mouse_leave:   # Mouse leaves bounds
    # code
  on_focus_gained:  # Widget gains focus
    # code
  on_focus_lost:    # Widget loses focus
    # code
```

---

## Widget Development Checklist

### 1. Research
- [ ] Identify widget purpose and use cases
- [ ] List required props (configuration)
- [ ] List required state (mutable data)
- [ ] Plan event handlers needed
- [ ] Choose rendering approach (raygui vs custom)

### 2. Create Widget File
- [ ] Choose category directory (basic/containers/etc.)
- [ ] Create `{widget_name}.nim`
- [ ] Add file header documentation
- [ ] Import required modules

### 3. Implement Widget
- [ ] Define props section
- [ ] Define state section (use Link[T])
- [ ] Define actions section (use Option[proc])
- [ ] Implement init section
- [ ] Implement event handlers
- [ ] Implement render section
- [ ] Add non-graphics fallback (echo debug info)

### 4. Test Widget
- [ ] Create example in `examples/widgets/`
- [ ] Test with `-d:useGraphics`
- [ ] Test without graphics (text mode)
- [ ] Test with different themes
- [ ] Test in nested layouts
- [ ] Test all event handlers
- [ ] Test state changes

### 5. Document Widget
- [ ] Add docstring to file header
- [ ] Document all props
- [ ] Document all state variables
- [ ] Document all actions
- [ ] Create usage example
- [ ] Add to widget catalog

### 6. Performance (for data widgets)
- [ ] Implement virtual scrolling if needed
- [ ] Add viewport culling
- [ ] Cache expensive calculations
- [ ] Profile with large datasets

---

## Best Practices

### Props vs State

**Props** (immutable):
- Initial values
- Configuration options
- Callbacks
- Static content

**State** (mutable with Link[T]):
- Current value
- Hover/focus status
- Selection state
- Scroll position

### Naming Conventions

- Props: `initialValue`, `maxWidth`, `disabled`
- State: `value`, `hovered`, `selected`
- Actions: `onChange`, `onSelect`, `onClick`
- Internal functions: `calculate*`, `handle*`, `render*`, `draw*`

### Code Organization

1. Imports at top
2. Type definitions (if needed)
3. Widget definition with sections in order:
   - props
   - state
   - actions
   - events
   - init
   - layout (containers only)
   - render
   - measure (optional)

### Graphics Conditionals

Always provide non-graphics fallback:

```nim
render:
  when defined(useGraphics):
    # raylib/raygui rendering
    DrawRectangleRec(...)
  else:
    # Text mode debugging
    echo "Button: ", widget.text
```

### Performance Tips

For data widgets with many items:
1. **Virtual scrolling**: Only render visible items
2. **Buffer rows**: Render a few extra for smooth scrolling
3. **Viewport culling**: Skip items completely outside bounds
4. **Cached calculations**: Store expensive computations
5. **Dirty tracking**: Only recalculate when data changes

Example from DataGrid:
```nim
let bufferRows = 10
let visStart = max(0, int(scroll / rowH) - bufferRows)
let visEnd = min(data.len - 1, int((scroll + viewHeight) / rowH) + bufferRows)

for rowIdx in visStart..visEnd:
  # Only render visible rows
```

---

## Remaining Widgets to Implement

### Phase 7: Specialized Input (Optional)
- [ ] ColorPicker - Color selection widget
- [ ] Calendar - Date selection widget
- [ ] DateTimePicker - Date and time picker

### Phase 8: Advanced Widgets (Optional)
- [ ] Chart - Data visualization charts
- [ ] CodeEditor - Syntax highlighted editor (complex, could be simplified)
- [ ] GradientEditor - Visual gradient editor
- [ ] RichText - Formatted text display (could be simplified)

**Note**: These are optional specialty widgets for specific use cases.

---

## Examples

### Simple Widget Example
```nim
# Create and use checkbox
let cb = newCheckbox()
cb.text = "Accept Terms"
cb.bounds = Rectangle(x: 100, y: 100, width: 200, height: 24)
cb.onToggle = some(proc(checked: bool) =
  echo "Checkbox toggled: ", checked
)
```

### Container Widget Example
```nim
# Create vertical stack with buttons
let stack = newVStack()
stack.spacing = 16.0
stack.justify = Center
stack.align = Stretch

let btn1 = newButton()
btn1.text = "Click Me"

let btn2 = newButton()
btn2.text = "Or Me"

stack.addChild(btn1)
stack.addChild(btn2)
stack.bounds = Rectangle(x: 50, y: 50, width: 300, height: 200)
stack.layout()  # Position children
```

### Data Widget Example
```nim
# Create data grid
let grid = newDataGrid()
grid.columns = @[
  Column(name: "Name", width: 150),
  Column(name: "Age", width: 80),
  Column(name: "City", width: 120)
]
grid.data = @[
  @["Alice", "25", "NYC"],
  @["Bob", "30", "LA"],
  # ... thousands more rows (virtual scrolling handles it!)
]
grid.onSelect = some(proc(selected: HashSet[int]) =
  echo "Selected rows: ", selected
)
```

---

## Migration Guide

### Old Structure → New Structure

**Before**:
```nim
import widgets/label
import widgets/button
import widgets/vstack
```

**After**:
```nim
import widgets/basic/label
import widgets/basic/button
import widgets/containers/vstack
```

### Deprecated Widgets

- `column.nim` → Use `vstack.nim` instead (same functionality, better name)

---

## Testing Strategy

### Unit Tests
Test internal functions independently:
```nim
# tests/test_datagrid_internal.nim
import ../widgets/data/datagrid_internal
import unittest

test "calculateVisibleRange with scroll offset":
  var widget = newDataGrid(...)
  widget.scrollY.set(240.0)
  let (start, end) = calculateVisibleRange(widget)
  check start == 0
  check end == 20
```

### Visual Tests
Create standalone examples:
```nim
# examples/widgets/button_test.nim
import raylib
import ../../widgets/basic/button

proc main() =
  initWindow(800, 600, "Button Test")
  let btn = newButton()
  btn.text = "Click Me"
  # ... test rendering and interaction
```

---

**Status**: 🎯 44 unique widgets complete (52 files)! Comprehensive widget library, well-organized and functional.
