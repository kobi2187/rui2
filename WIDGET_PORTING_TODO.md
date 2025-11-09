# Widget Porting TODO - Hummingbird to RUI2

Complete roadmap for porting 35+ Hummingbird widgets to RUI2.

## DSL Comparison

### Hummingbird defineWidget
```nim
defineWidget Button:
  props:
    text: string
    onClick: proc()

  state:
    fields:
      pressed: bool

  input:
    if event.kind == ieMousePress:
      widget.isPressed = true

  render:
    GuiButton(...)
```

### RUI2 defineWidget (Current)
```nim
defineWidget(Button):
  props:
    text: string
    onClick: proc()

  init:
    widget.text = ""

  input:
    if event.kind == evMouseUp:
      widget.onClick()

  render:
    drawButton(...)

  # YAML-UI event handlers
  on_click:
    widget.onClick()
```

### Key Differences

| Feature | Hummingbird | RUI2 | Status |
|---------|-------------|------|--------|
| Syntax | `defineWidget Name:` | `defineWidget(Name):` | ✓ Different but OK |
| Props | ✓ | ✓ | ✓ Compatible |
| State | Has `state:` block | Missing | ❌ Need to add |
| Init | No | Has `init:` | ✓ RUI2 better |
| Input | ✓ | ✓ | ✓ Compatible |
| Render | ✓ | ✓ | ✓ Compatible |
| YAML-UI events | No | Has `on_click:` etc | ✓ RUI2 better |
| Measure | No | Has `measure:` | ✓ RUI2 better |
| Layout | No | Has `layout:` | ✓ RUI2 better |

### Verdict
RUI2's DSL is **MORE capable** than Hummingbird's! Missing only:
- `state:` block integration (need to add Link[T] support)

## Widget Porting Plan

### Phase 1: Essential Input Widgets (Week 1)
**Goal**: Basic interactivity

- [ ] **Checkbox** (checkbox.nim)
  - Props: text, checked, onToggle
  - Render: GuiCheckBox or custom draw
  - Priority: HIGH

- [ ] **RadioButton** (radio_button.nim)
  - Props: text, selected, groupId, onSelect
  - Render: GuiRadioButton or custom draw
  - Priority: HIGH

- [ ] **RadioGroup** (radio_group.nim)
  - Props: options, selected, onSelect
  - Compose: Multiple RadioButton widgets
  - Priority: HIGH

- [ ] **Slider** (slider.nim / slider2.nim)
  - Props: value, minValue, maxValue, onChange
  - Render: GuiSlider
  - Priority: HIGH
  - Note: Check slider2 for improvements

- [ ] **ProgressBar** (progress_bar.nim / progress2.nim)
  - Props: value, maxValue, showText
  - Render: GuiProgressBar
  - Priority: HIGH

- [ ] **Spinner** (spinner.nim / spinner2.nim)
  - Props: value, minValue, maxValue, step, onChange
  - Render: GuiSpinner
  - Priority: MEDIUM

- [ ] **NumberInput** (number_input.nim)
  - Props: value, min, max, step, onChange
  - Render: GuiTextBox + validation
  - Priority: MEDIUM

### Phase 2: Selection & Display (Week 2)
**Goal**: Lists and data display

- [ ] **ComboBox** (combo_box.nim / combo_box2.nim)
  - Props: items, selected, onSelect
  - Render: GuiComboBox
  - Priority: HIGH
  - Note: Check combo_box2 for improvements

- [ ] **ListBox** (list_box.nim)
  - Props: items, selected, multiSelect, onSelect
  - Render: GuiListView
  - Priority: HIGH

- [ ] **ListView** (list_view.nim / list_view2.nim)
  - Props: items, selected, onSelect, itemHeight
  - Render: Custom scrollable list
  - Priority: MEDIUM
  - Note: Compare versions

- [ ] **Separator** (separator.nim)
  - Props: orientation (horizontal/vertical)
  - Render: drawLine
  - Priority: LOW

- [ ] **Tooltip** (tooltip.nim)
  - Props: text, target
  - Render: Floating text on hover
  - Priority: MEDIUM

- [ ] **IconButton** (icon_button.nim)
  - Props: icon, tooltip, onClick
  - Render: Button with icon
  - Priority: MEDIUM

- [ ] **Link** (link.nim)
  - Props: text, url, onClick
  - Render: Clickable underlined text
  - Priority: LOW

### Phase 3: Containers & Layout (Week 3)
**Goal**: Organize content

- [ ] **GroupBox** (group_box.nim / group_box2.nim)
  - Props: title, padding
  - Render: GuiGroupBox + children
  - Priority: HIGH
  - Note: Compare versions

- [ ] **TabControl** (tab_control.nim / tab_container.nim)
  - Props: tabs, activeTab, onTabChanged
  - Render: GuiTabBar + active tab content
  - Priority: HIGH
  - Note: Compare versions

- [ ] **ScrollView** (scroll_view.nim)
  - Props: content, scrollX, scrollY
  - Render: GuiScrollPanel
  - Priority: HIGH

- [ ] **ScrollBar** (scroll_bar.nim)
  - Props: value, min, max, orientation, onChange
  - Render: GuiScrollBar
  - Priority: MEDIUM

- [ ] **StatusBar** (status_bar.nim)
  - Props: sections, text
  - Render: Bottom bar with segments
  - Priority: LOW

### Phase 4: Data Widgets (Week 4)
**Goal**: Complex data display

- [ ] **DataGrid** (data_grid.nim)
  - Props: columns, data, selected, onSort, onSelect
  - Render: Header + rows with sorting
  - Priority: HIGH

- [ ] **DataTable** (data_table.nim)
  - Props: columns, rows, onCellEdit
  - Render: Editable table
  - Priority: MEDIUM

- [ ] **TreeView** (tree_view.nim)
  - Props: root, selected, onExpand, onSelect
  - Render: Hierarchical tree
  - Priority: MEDIUM

- [ ] **PropertyGrid** (property_grid.nim / property_grid2.nim)
  - Props: properties, onEdit
  - Render: Name-value pairs with editors
  - Priority: MEDIUM
  - Note: Compare versions

- [ ] **FilterList** (filter_list.nim)
  - Props: items, filterText, onFilter
  - Render: SearchBox + filtered ListView
  - Priority: LOW

### Phase 5: Specialized Input (Week 5)
**Goal**: Rich input controls

- [ ] **ColorPicker** (color_picker.nim / color_picker2.nim)
  - Props: color, onChange
  - Render: Color wheel/palette
  - Priority: MEDIUM
  - Note: Compare versions

- [ ] **Calendar** (calendar.nim)
  - Props: selectedDate, onDateChange
  - Render: Month view with date selection
  - Priority: MEDIUM

- [ ] **DateTimePicker** (datetime_picker.nim)
  - Props: datetime, format, onChange
  - Render: Calendar + time selector
  - Priority: MEDIUM

- [ ] **FilePicker** (file_picker.nim)
  - Props: selectedPath, filters, onSelect
  - Render: Dialog or inline browser
  - Priority: MEDIUM

- [ ] **FileBrowser** (file_browser.nim)
  - Props: currentPath, onNavigate, onSelect
  - Render: Tree + file list
  - Priority: LOW

### Phase 6: Advanced Widgets (Week 6+)
**Goal**: Rich content and visualization

- [ ] **Canvas** (canvas.nim)
  - Props: width, height, onDraw
  - Render: Drawable surface
  - Priority: LOW

- [ ] **Chart** (chart.nim / chart2.nim)
  - Props: data, chartType, options
  - Render: Bar/line/pie charts
  - Priority: LOW
  - Note: Compare versions

- [ ] **Timeline** (timeline.nim)
  - Props: events, timeRange, onSelect
  - Render: Horizontal timeline
  - Priority: LOW

- [ ] **CodeEditor** (code_editor.nim)
  - Props: code, language, onChange
  - Render: Syntax highlighted editor
  - Priority: LOW (Complex!)

- [ ] **GradientEditor** (gradient_editor.nim)
  - Props: gradient, onEdit
  - Render: Visual gradient editor
  - Priority: LOW

- [ ] **MapWidget** (map_widget.nim)
  - Props: center, zoom, markers
  - Render: Interactive map
  - Priority: LOW (Very complex!)

- [ ] **RichText** (rich_text.nim)
  - Props: content, format, editable
  - Render: Formatted text display
  - Priority: MEDIUM

### Phase 7: Widget Duplicates (Review)
**Goal**: Consolidate versions

- [ ] Review all *2.nim versions:
  - button2.nim vs button.nim
  - slider2.nim vs slider.nim
  - progress_bar2.nim vs progress.nim
  - combo_box2.nim vs combo_box.nim
  - list_view2.nim vs list_view.nim
  - group_box2.nim vs group_box.nim
  - chart2.nim vs chart.nim
  - color_picker2.nim vs color_picker.nim
  - property_grid2.nim vs property_grid.nim
  - spinner2.nim vs spinner.nim

- [ ] Choose best version for each
- [ ] Merge features if needed
- [ ] Document decision

## Implementation Checklist (Per Widget)

For each widget, complete:

1. **Research**
   - [ ] Read Hummingbird version
   - [ ] Identify props, state, events
   - [ ] Check for *2 version

2. **Design**
   - [ ] Decide on props structure
   - [ ] Plan state management (Link[T] if needed)
   - [ ] Choose rendering approach (raygui vs custom)

3. **Implementation**
   - [ ] Create file in `rui2/widgets/{category}/`
   - [ ] Use `defineWidget` macro
   - [ ] Implement render method
   - [ ] Add event handlers
   - [ ] Add to `rui.nim` exports

4. **Testing**
   - [ ] Create example in `examples/widgets/`
   - [ ] Test with themes
   - [ ] Test interactivity
   - [ ] Test composition with other widgets

5. **Documentation**
   - [ ] Add docstrings
   - [ ] Create widget example
   - [ ] Update widget catalog

## State Management TODO

RUI2 needs `state:` block support:

- [ ] **Add state: block to defineWidget macro**
  - Parse `state:` section
  - Generate Link[T] fields
  - Auto-link to Store if present

- [ ] **Example**:
  ```nim
  defineWidget(Counter):
    props:
      initialValue: int = 0

    state:
      count: Link[int]

    init:
      widget.count = newLink(widget.initialValue)

    render:
      vstack:
        Label(text: "Count: " & $widget.count.get())
        Button(text: "+", onClick: proc() = widget.count.set(widget.count.get() + 1))
  ```

## Widget Categories for rui.nim

Update `rui.nim` with new exports:

```nim
# Widgets - Basic Input (Extended)
import widgets/basic/[label, button, checkbox, radiobutton, slider, spinner]
export label, button, checkbox, radiobutton, slider, spinner

# Widgets - Selection
import widgets/selection/[combobox, listbox, listview, treeview]
export combobox, listbox, listview, treeview

# Widgets - Display
import widgets/display/[progressbar, separator, tooltip, richtext]
export progressbar, separator, tooltip, richtext

# Widgets - Containers
import widgets/containers/[hstack, vstack, column, groupbox, tabcontrol, scrollview]
export hstack, vstack, column, groupbox, tabcontrol, scrollview

# Widgets - Data
import widgets/data/[datagrid, datatable, propertygrid]
export datagrid, datatable, propertygrid

# Widgets - Specialized
import widgets/specialized/[colorpicker, calendar, filepicker]
export colorpicker, calendar, filepicker

# Widgets - Advanced
import widgets/advanced/[canvas, chart, timeline, codeeditor]
export canvas, chart, timeline, codeeditor
```

## Success Criteria

### Phase 1 Complete When:
- ✓ 7 widgets ported (Checkbox, RadioButton, RadioGroup, Slider, ProgressBar, Spinner, NumberInput)
- ✓ All compile with `-d:useGraphics`
- ✓ Examples created for each
- ✓ Tested with themes
- ✓ Added to rui.nim

### Project Complete When:
- ✓ All 35 unique widgets ported
- ✓ Full widget catalog documented
- ✓ Comprehensive examples
- ✓ State management working
- ✓ All widgets themed
- ✓ Performance tested

## Notes

- **Start with Phase 1** - Essential widgets used in 80% of apps
- **Incremental approach** - Port, test, document, repeat
- **Quality over speed** - Each widget should be polished
- **Leverage raygui** - Use built-in functions where possible
- **Custom when needed** - Draw custom for better control
- **Composability** - Build complex widgets from simple ones

## Timeline Estimate

- **Phase 1**: 1 week (7 widgets)
- **Phase 2**: 1 week (7 widgets)
- **Phase 3**: 1 week (5 widgets)
- **Phase 4**: 1 week (5 widgets)
- **Phase 5**: 1 week (5 widgets)
- **Phase 6**: 2 weeks (6 complex widgets)
- **Phase 7**: 3 days (review/consolidate)

**Total**: ~7 weeks for complete widget library

## Resume Strategy

To resume later:
1. Open this file
2. Find next unchecked widget
3. Follow implementation checklist
4. Mark as complete
5. Repeat!

Start with: **Checkbox** in Phase 1!
