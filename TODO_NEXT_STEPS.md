# RUI2 TODO - Next Steps

## Priority 1: Architecture Improvements

### 1. Global App Singleton with Theme System ✅ (IN PROGRESS)
**Status**: Designing implementation

**Goal**: Make theme accessible from anywhere via global app object

**Implementation**:
```nim
# Global singleton (or threadvar for thread safety)
var app*: RuiApp

# Every widget accesses theme directly:
widget.render():
  DrawRectangle(
    widget.bounds,
    app.currentTheme.bgColor  # No hardcoded colors!
  )
```

**Decisions**:
- [ ] Choose between `var` (global singleton) vs `threadvar` (thread-safe)
- [ ] Decide if `app` should be immutable ref or mutable
- [ ] Design theme hot-reload mechanism
- [ ] Create theme presets (light, dark, high contrast, etc.)

**Files to create**:
- [ ] `core/app.nim` - RuiApp type and global instance
- [ ] `core/theme_manager.nim` - Theme switching and management
- [ ] Update all widgets to use `app.currentTheme.*` instead of hardcoded values

**Benefits**:
- No hardcoded colors/fonts anywhere
- Theme changes apply immediately (immediate mode)
- Easy to add dark mode, custom themes
- Centralized styling

---

### 2. Refactor Existing Widgets Using Internal Pattern
**Status**: Pattern documented, ready to implement

**Goal**: Separate all widget behavior from implementation

**Approach**:
```
widgets/basic/checkbox.nim          → Behavior only (~30 lines)
widgets/basic/checkbox_internal.nim → Implementation (~50 lines)
```

**Priority Order** (refactor complex ones first):
1. [ ] **Data widgets** (most complex):
   - [ ] `widgets/data/datagrid.nim` + `datagrid_internal.nim`
   - [ ] `widgets/data/datatable.nim` + `datatable_internal.nim`
   - [ ] `widgets/data/treeview.nim` + `treeview_internal.nim`

2. [ ] **Modern widgets** (interactive, lots of logic):
   - [ ] `widgets/modern/canvas.nim` + `canvas_internal.nim`
   - [ ] `widgets/modern/mapwidget.nim` + `mapwidget_internal.nim`
   - [ ] `widgets/modern/timeline.nim` + `timeline_internal.nim`
   - [ ] `widgets/modern/dragdroparea.nim` + `dragdroparea_internal.nim`

3. [ ] **Desktop widgets** (medium complexity):
   - [ ] All menu widgets
   - [ ] All dialog widgets
   - [ ] Toolbar widgets

4. [ ] **Container widgets**:
   - [ ] Panel, GroupBox, ScrollView, TabControl

5. [ ] **Basic widgets** (simplest, do last):
   - [ ] All input widgets (checkbox, slider, etc.)
   - [ ] All display widgets (link, separator, etc.)

**Files per widget**:
- [ ] Split into `widget.nim` + `widget_internal.nim`
- [ ] Create unit tests in `tests/test_{widget}_internal.nim`
- [ ] Update imports in example files

**Estimated Time**: 3-4 hours for all 38 widgets

---

### 3. Enhance Macros to Auto-Import Internal Files
**Status**: Design complete, needs implementation

**Goal**: `definePrimitive` and `defineWidget` automatically import `*_internal.nim`

**Implementation**:
```nim
macro defineWidget*(name: untyped, body: untyped): untyped =
  # Detect if {name}_internal.nim exists
  let internalFile = name.strVal.toLowerAscii() & "_internal.nim"

  if fileExists(getCurrentDir() / internalFile):
    result.add quote do:
      import `.` / `internalFile`

  # Rest of macro expansion...
```

**Tasks**:
- [ ] Modify `core/widget_dsl_v2.nim` macro to detect internal files
- [ ] Auto-generate `{WidgetName}Widget` type for internal files to use
- [ ] Test with all refactored widgets
- [ ] Document in macro comments

**Estimated Time**: 1-2 hours

---

## Priority 2: Use RUI2 API (Not Manual/Raylib)

### 4. Refactor Example Apps to Use DSL, Not Manual Code
**Status**: Examples currently use low-level Raylib API

**Problem**: Examples like `comprehensive_widget_showcase.nim` use:
- Direct Raylib calls (`DrawText`, `DrawRectangle`)
- Manual widget creation and positioning
- Hardcoded colors and sizes

**Goal**: Use RUI2's high-level API with DSL

**Example - Before (Manual)**:
```nim
# Bad: Manual Raylib calls
DrawText("Title".cstring, 20, 20, 24, BLACK)

# Bad: Manual widget creation
let button = newButton(text = "Click Me")
button.bounds = Rectangle(x: 40.0, y: 100.0, width: 120.0, height: 40.0)
button.render()
```

**Example - After (DSL)**:
```nim
# Good: Use RUI2 DSL
VStack(spacing = 10):
  Label(text = "Title", fontSize = 24)
  Button(text = "Click Me", onClick = handleClick)
  HStack:
    Checkbox(text = "Option 1")
    Checkbox(text = "Option 2")
```

**Files to refactor**:
- [ ] `examples/comprehensive_widget_showcase.nim`
- [ ] All example files in `examples/`
- [ ] Create new examples showing DSL best practices

**Rules**:
- ✅ **Use**: RUI2 widgets (Button, Label, VStack, etc.)
- ✅ **Use**: Raylib types (Color, Rectangle, Vector2)
- ✅ **Use**: Raylib constants (BLUE, KEY_SPACE, etc.)
- ❌ **Don't use**: Manual Raylib calls (DrawText, DrawRectangle, etc.)
- ❌ **Don't use**: Manual bounds setting (widget.bounds = ...)
- ❌ **Don't use**: Direct render calls (widget.render())

**Estimated Time**: 2-3 hours for all examples

---

## Priority 3: Add Remaining Specialty Widgets

### 5. Implement Remaining Widgets
**Status**: 7 widgets remaining (16% of library)

**Phase 7: Specialized Input Widgets**
- [ ] **ColorPicker** (`widgets/specialized/colorpicker.nim`)
  - HSV/RGB color wheel
  - Hex input field
  - Alpha channel slider
  - Color presets/swatches
  - Copy/paste hex codes

- [ ] **Calendar** (`widgets/specialized/calendar.nim`)
  - Month/year navigation
  - Day selection
  - Date range selection
  - Disabled dates
  - Today highlighting

- [ ] **DateTimePicker** (`widgets/specialized/datetimepicker.nim`)
  - Combined date + time picker
  - Dropdown calendar
  - Time spinners (HH:MM:SS)
  - Format customization
  - Validation

**Phase 8: Advanced Visualization Widgets**
- [ ] **Chart** (`widgets/visualization/chart.nim`)
  - Line charts
  - Bar charts
  - Pie charts
  - Scatter plots
  - Axes and legends
  - Tooltips on hover

- [ ] **CodeEditor** (`widgets/specialized/codeeditor.nim`)
  - Syntax highlighting
  - Line numbers
  - Bracket matching
  - Auto-indentation
  - Find/replace

- [ ] **GradientEditor** (`widgets/specialized/gradienteditor.nim`)
  - Color stops
  - Gradient preview
  - Linear/radial modes
  - Add/remove stops
  - Export to CSS

- [ ] **RichText** (`widgets/specialized/richtext.nim`)
  - Bold, italic, underline
  - Font sizes and colors
  - Paragraphs and lists
  - Links
  - Images (optional)

**Estimated Time**: 4-5 hours for all 7 widgets

---

## Priority 4: Testing and Quality

### 6. Create Unit Tests for All Widgets
- [ ] Test internal functions (virtual scrolling, calculations, etc.)
- [ ] Test state management (Link[T] reactivity)
- [ ] Test event handling (clicks, hovers, etc.)
- [ ] Test edge cases (empty data, large datasets, etc.)

**Test Structure**:
```nim
tests/
├── test_checkbox_internal.nim
├── test_datagrid_internal.nim
├── test_treeview_internal.nim
└── ...
```

### 7. Create Integration Tests
- [ ] Test widget compositions (VStack with multiple children)
- [ ] Test theme switching
- [ ] Test layout system
- [ ] Performance tests (large data, many widgets)

### 8. Documentation
- [ ] API documentation for each widget
- [ ] Tutorial: Building first app
- [ ] Tutorial: Custom themes
- [ ] Tutorial: Data-driven widgets
- [ ] Best practices guide

---

## Priority 5: Performance and Polish

### 9. Optimize Virtual Scrolling
- [ ] Profile with large datasets (1M+ rows)
- [ ] Implement row recycling/pooling
- [ ] Lazy evaluation for filters
- [ ] Background data processing

### 10. Add Animation System
- [ ] Smooth transitions (colors, positions, sizes)
- [ ] Easing functions
- [ ] Timeline-based animations
- [ ] Widget appear/disappear effects

### 11. Accessibility
- [ ] Keyboard navigation
- [ ] Screen reader support
- [ ] High contrast themes
- [ ] Focus indicators
- [ ] ARIA-like attributes

---

## Implementation Timeline

**Week 1** (High Priority):
- [x] Global app singleton with theme system (Day 1-2)
- [ ] Refactor showcase to use DSL instead of Raylib (Day 3)
- [ ] Refactor 5 complex widgets with internal pattern (Day 4-5)

**Week 2** (Medium Priority):
- [ ] Enhance macros to auto-import internal files (Day 1)
- [ ] Refactor remaining 33 widgets with internal pattern (Day 2-4)
- [ ] Add 3 specialty widgets (ColorPicker, Calendar, DateTimePicker) (Day 5)

**Week 3** (Medium Priority):
- [ ] Add 4 visualization widgets (Chart, CodeEditor, GradientEditor, RichText) (Day 1-3)
- [ ] Create unit tests for complex widgets (Day 4-5)

**Week 4** (Lower Priority):
- [ ] Write documentation and tutorials (Day 1-3)
- [ ] Performance optimization (Day 4-5)

---

## Technical Decisions to Make

### 1. Global App: `var` vs `threadvar`
**Option A: Global var** (Simpler)
```nim
var app*: RuiApp
```
- ✅ Simple, fast access
- ✅ Works for single-threaded apps (most GUIs)
- ❌ Not thread-safe
- ❌ Can't run multiple app instances

**Option B: threadvar** (Thread-safe)
```nim
threadvar app*: RuiApp
```
- ✅ Thread-safe
- ✅ Each thread has its own app
- ❌ Slightly slower access
- ❌ More complex initialization

**Recommendation**: Start with `var`, add `threadvar` later if needed

### 2. Theme Access Pattern
**Option A: Direct access** (Recommended)
```nim
app.currentTheme.bgColor
```

**Option B: Getter function**
```nim
getThemeColor(ColorKind.Background)
```

**Recommendation**: Option A - simpler, more immediate-mode style

### 3. Hot Theme Reload
**Option A: Immediate** (true immediate mode)
- Every render reads fresh theme values
- Theme changes apply instantly
- No caching

**Option B: Cached**
- Widget caches theme values on creation
- Must invalidate cache on theme change
- Faster but more complex

**Recommendation**: Option A - simpler, more flexible

---

## Success Metrics

- [ ] All 38 widgets refactored with internal pattern
- [ ] All examples use DSL instead of manual/Raylib code
- [ ] All widgets use `app.currentTheme.*` instead of hardcoded values
- [ ] 45+ total widgets (38 existing + 7 new)
- [ ] 90%+ test coverage for internal functions
- [ ] Complete documentation
- [ ] 5+ example applications
- [ ] Dark mode working perfectly
- [ ] Performance: 60 FPS with 1M rows in DataGrid

---

## Notes

- Keep backward compatibility where possible
- Document breaking changes
- Update examples as API evolves
- Get feedback early and often
