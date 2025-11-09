# Hummingbird Widgets Inventory

Complete inventory of widgets from the Hummingbird framework to be ported to RUI2.

## Widget Categories

### Basic Input Widgets (11)

1. **button.nim** / **button2.nim** - Push buttons with click handlers
2. **checkbox.nim** / **check_box.nim** - Toggle checkboxes
3. **radio_button.nim** - Radio button (mutually exclusive selection)
4. **radio_group.nim** - Group of radio buttons
5. **slider.nim** / **slider2.nim** - Value slider (horizontal/vertical)
6. **spinner.nim** / **spinner2.nim** - Numeric spinner (up/down buttons)
7. **text_input.nim** - Single-line text input
8. **input.nim** - Generic input widget
9. **number_input.nim** - Numeric input with validation
10. **icon_button.nim** - Button with icon
11. **link.nim** - Clickable hyperlink

### Display Widgets (5)

12. **label.nim** - Text label
13. **progress_bar.nim** / **progress_bar2.nim** / **progress.nim** - Progress indicator
14. **separator.nim** - Visual separator line
15. **tooltip.nim** - Hover tooltip
16. **rich_text.nim** - Formatted/rich text display

### Selection Widgets (6)

17. **combo_box.nim** / **combo_box2.nim** - Dropdown selection
18. **list_box.nim** - List selection
19. **list_view.nim** / **list_view2.nim** - Scrollable list with items
20. **filter_list.nim** - List with filtering capability
21. **menu_item.nim** - Menu item widget
22. **tree_view.nim** - Hierarchical tree structure

### Container/Layout Widgets (5)

23. **group_box.nim** / **group_box2.nim** - Bordered container with title
24. **tab_control.nim** / **tab_container.nim** - Tabbed interface
25. **scroll_view.nim** - Scrollable content area
26. **scroll_bar.nim** - Scroll bar control
27. **status_bar.nim** - Bottom status bar

### Complex Data Widgets (3)

28. **data_grid.nim** - Sortable/filterable data grid
29. **data_table.nim** - Table with columns/rows
30. **property_grid.nim** / **property_grid2.nim** - Property editor grid

### Specialized Input Widgets (5)

31. **color_picker.nim** / **color_picker2.nim** - Color selection
32. **datetime_picker.nim** - Date/time picker
33. **calendar.nim** - Calendar widget
34. **file_picker.nim** - File selection dialog
35. **file_browser.nim** - File browser interface

### Advanced/Specialized Widgets (9)

36. **canvas.nim** - Drawing canvas
37. **chart.nim** / **chart2.nim** - Data visualization charts
38. **timeline.nim** - Timeline/gantt chart
39. **code_editor.nim** - Code editor with syntax highlighting
40. **gradient_editor.nim** - Gradient creation/editing
41. **map_widget.nim** - Geographic map
42. **core.nim** - Core widget base types
43. **widget_dsl.nim** - Widget DSL macros
44. **examples.nim** - Widget examples

## Total: 44 Widget Files (some are duplicates/versions)

## Unique Widgets to Port: ~35

After removing duplicates (button2, checkbox variants, etc.), we have approximately 35 unique widget types.

## Widget Implementation Patterns

### Pattern 1: Simple draw() method
```nim
type
  Slider* = ref object of Widget
    value*: float32
    minValue*: float32
    maxValue*: float32
    onChange*: proc(newValue: float32)

method draw*(slider: Slider) =
  # Direct Raylib GUI call
  GuiSlider(...)
```

### Pattern 2: defineWidget DSL
```nim
defineWidget ProgressBar:
  props:
    value*: float
    maxValue*: float = 100.0
    showText*: bool = true

  render:
    GuiProgressBar(...)
```

### Pattern 3: Complex widgets with sub-components
```nim
defineWidget DataGrid:
  props:
    columns: seq[Column]
    data: seq[Row]
    selected: HashSet[int]
    onSort: proc(column: int, ascending: bool)

  type
    Column* = object
      title*: string
      width*: float32

  render:
    # Draw header
    # Draw rows
    # Handle interactions
```

## Priority for Porting

### Phase 1: Essential Widgets (High Priority)
- ✓ Button (already in RUI2)
- ✓ Label (already in RUI2)
- ✓ TextInput (already in RUI2)
- Checkbox
- Radio Button / Radio Group
- Slider
- Progress Bar
- ComboBox (Dropdown)

### Phase 2: Common Widgets (Medium Priority)
- ListBox / ListView
- ScrollView / ScrollBar
- TabControl
- Separator
- Tooltip
- Number Input
- Spinner
- Icon Button

### Phase 3: Data Widgets (Medium Priority)
- DataGrid
- DataTable
- TreeView
- PropertyGrid

### Phase 4: Advanced Widgets (Lower Priority)
- Calendar / DateTime Picker
- Color Picker
- File Picker / File Browser
- Chart
- Canvas
- Code Editor
- Timeline
- Map Widget
- Gradient Editor
- Rich Text

## Adaptation Strategy

### What Needs to Change

1. **Base Widget Type**:
   - Hummingbird: `Widget` (unknown structure)
   - RUI2: Use our `Widget` from `core/types.nim`

2. **Drawing API**:
   - Hummingbird: Uses `GuiXXX` functions (raygui)
   - RUI2: Can use raygui or custom drawing

3. **Layout System**:
   - Hummingbird: Uses `rect: Rectangle`
   - RUI2: Use our layout system with `bounds: Rect`

4. **Event Handling**:
   - Hummingbird: Direct callbacks (`onChange`, `onToggle`)
   - RUI2: Use event manager or keep simple callbacks

5. **Theming**:
   - Hummingbird: Had theme system
   - RUI2: Integrate with our theme system

### What Can Stay the Same

1. **Widget properties** - Most prop names/types are good
2. **Callback signatures** - Event callback patterns work
3. **Logic** - Widget behavior and state management
4. **Raygui calls** - Can reuse if available

## Next Steps

1. Create widget template for RUI2
2. Port Phase 1 widgets first (Checkbox, RadioButton, Slider, etc.)
3. Test each widget with themes
4. Add to rui.nim exports
5. Create examples for each widget
6. Continue with Phase 2, 3, 4

## Notes

- Some widgets have multiple versions (button2, slider2, etc.) - likely iterations
- Need to check which version is more complete/better
- `widget_dsl.nim` might contain useful macros for RUI2
- `core.nim` might have base widget utilities to adapt
