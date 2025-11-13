# RUI2 Codebase Audit Report

**Generated:** 2025-11-12
**Analysis Tool:** Import dependency tracer from rui.nim

## Executive Summary

- **Total .nim files:** 172
- **Files imported by rui.nim:** 31 (18%)
- **Unused/Stale files:** 141 (82%)

## Files Actively Used (31 files)

### Core Framework (4 files)
```
✓ core/types.nim          - Base types (Widget, Store, Event, etc.)
✓ core/app.nim            - Application lifecycle & main loop
✓ core/link.nim           - Reactive Link[T] primitive
✓ core/widget_dsl_v2.nim  - Widget DSL macros (definePrimitive, defineWidget)
```

### Managers (2 files)
```
✓ managers/event_manager.nim  - Event queue & processing
✓ managers/focus_manager.nim  - Keyboard focus management
```

### Drawing Primitives (7 files)
```
✓ drawing_primitives/drawing_primitives.nim      - Main drawing API
✓ drawing_primitives/theme_sys_core.nim          - Theme system
✓ drawing_primitives/builtin_themes.nim          - Light/Dark/BeOS themes
✓ drawing_primitives/primitives/shapes.nim       - Rectangles, circles, etc.
✓ drawing_primitives/primitives/text.nim         - Text rendering
✓ drawing_primitives/primitives/text_cache.nim   - Text measurement cache
✓ drawing_primitives/primitives/controls.nim     - Control drawing helpers
✓ drawing_primitives/primitives/indicators.nim   - Progress, slider indicators
✓ drawing_primitives/primitives/panels.nim       - Panel/border drawing
```

### Widgets - Primitives (4 files)
```
✓ widgets/primitives.nim          - Aggregator
✓ widgets/primitives/label.nim    - Text label
✓ widgets/primitives/rectangle.nim - Rectangle shape
✓ widgets/primitives/circle.nim   - Circle shape
```

### Widgets - Basic (7 files)
```
✓ widgets/basic.nim              - Aggregator
✓ widgets/basic/button_v2.nim    - Button widget
✓ widgets/basic/checkbox.nim     - Checkbox widget
✓ widgets/basic/radiobutton.nim  - Radio button
✓ widgets/basic/slider.nim       - Slider control
✓ widgets/basic/progressbar.nim  - Progress bar
✓ widgets/basic/hyperlink.nim    - Clickable link
```

### Widgets - Containers (4 files)
```
✓ widgets/containers.nim           - Aggregator
✓ widgets/containers/vstack_v2.nim - Vertical stack
✓ widgets/containers/hstack_v2.nim - Horizontal stack
✓ widgets/containers/zstack_v2.nim - Z-order stack (overlays)
```

### Main Entry (1 file)
```
✓ rui.nim - Main library entry point
```

---

## Unused/Stale Files (141 files)

### ⚠️ CRITICAL - Potentially Using Wrong Versions

**DSL Versions:**
```
✗ core/widget_dsl.nim        - OLD DSL (should use v2 or v3?)
✗ core/widget_dsl_v3.nim     - V3 exists but NOT imported (cleaner than v2?)
✗ core/widget_dsl_helpers.nim - Helpers for v3
```

**🚨 ACTION NEEDED:** We're using v2 but v3 exists and may be cleaner. Need to decide which to use.

**Main Loop:**
```
✗ core/main_loop.nim - Standalone main loop (integrated into app.nim?)
```

**Event Manager:**
```
✗ managers/event_manager_refactored.nim - Refactored version unused?
✗ managers/event_manager_helpers.nim    - Helper functions
```

**🚨 ACTION NEEDED:** Is `event_manager_refactored.nim` the better version?

### Unused Core Infrastructure

**App Helpers:**
```
✗ core/app_helpers.nim
✗ core/happy_common_types.nim
```

**Hit-Testing System (ENTIRE MODULE UNUSED!):**
```
✗ hit-testing/hittest_system.nim
✗ hit-testing/hittest.nim
✗ hit-testing/interval_tree.nim
✗ hit-testing/interval_tree2.nim
✗ hit-testing/interval3.nim
✗ hit-testing/test_hittest_system.nim
✗ hit-testing/test_interval_tree.nim
✗ hit-testing/visual_test.nim
```

**🚨 ACTION NEEDED:** Hit-testing is needed for mouse events! Why isn't it imported?

**Layout System:**
```
✗ layout/layout_helpers.nim
✗ drawing_primitives/layout_core.nim
✗ drawing_primitives/layout_primitives.nim
✗ drawing_primitives/layout_containers.nim
✗ drawing_primitives/layout_calcs.nim
```

**🚨 ACTION NEEDED:** Layout calculations seem to be missing from the active system.

### Unused Drawing/Theme Features

**Theme Loaders:**
```
✗ drawing_primitives/theme_sys.nim      - Alternative theme system?
✗ drawing_primitives/theme_loader.nim   - JSON/YAML theme loading
✗ drawing_primitives/theme_load.nim     - Alternative loader?
✗ drawing_primitives/builtin_base_themes.nim
✗ drawing_primitives/base_themes_idea.nim
```

**Widget Primitives:**
```
✗ drawing_primitives/widget_primitives.nim - Theme-aware widget drawing (recently added!)
```

**🚨 ACTION NEEDED:** `widget_primitives.nim` was just created but not imported!

**Pango Integration:**
```
✗ drawing_primitives/pango_render.nim
✗ drawing_primitives/primitives/pango_helpers.nim
✗ pango_integration/pangowrapper.nim
✗ pango_integration/text_render.nim
```

**Other:**
```
✗ drawing_primitives/textarea.nim
✗ drawing_primitives/unicode_symbols.nim
✗ drawing_primitives/treelist_concept.nim
✗ drawing_primitives/fsdfsd.nim (random file?)
```

### Unused Widgets (82% of widget files!)

**Basic Widgets:**
```
✗ widgets/basic/button.nim         - OLD button (using button_v2.nim)
✗ widgets/basic/button_yaml.nim
✗ widgets/basic/label.nim          - OLD label (using primitives/label.nim)
✗ widgets/basic/combobox.nim
✗ widgets/basic/iconbutton.nim
✗ widgets/basic/listbox.nim
✗ widgets/basic/listview.nim
✗ widgets/basic/numberinput.nim
✗ widgets/basic/scrollbar.nim
✗ widgets/basic/separator.nim
✗ widgets/basic/spinner.nim
✗ widgets/basic/toolbutton.nim
✗ widgets/basic/tooltip.nim
```

**Container Widgets:**
```
✗ widgets/containers/vstack.nim      - OLD (using vstack_v2.nim)
✗ widgets/containers/hstack.nim      - OLD (using hstack_v2.nim)
✗ widgets/containers/column.nim
✗ widgets/containers/groupbox.nim
✗ widgets/containers/panel.nim
✗ widgets/containers/radiogroup.nim
✗ widgets/containers/scrollview.nim
✗ widgets/containers/spacer.nim
✗ widgets/containers/statusbar.nim
✗ widgets/containers/tabcontrol.nim
✗ widgets/containers/toolbar.nim
```

**Data Widgets:**
```
✗ widgets/data/datagrid.nim
✗ widgets/data/datatable.nim
✗ widgets/data/datatable_helpers.nim
✗ widgets/data/treeview.nim
```

**Dialog Widgets:**
```
✗ widgets/dialogs/filedialog.nim
✗ widgets/dialogs/filepicker.nim
✗ widgets/dialogs/messagebox.nim
```

**Input Widgets:**
```
✗ widgets/input/textinput.nim
```

**Menu Widgets:**
```
✗ widgets/menus/menu.nim
✗ widgets/menus/menubar.nim
✗ widgets/menus/menuitem.nim
✗ widgets/menus/contextmenu.nim
```

**Modern Widgets:**
```
✗ widgets/modern/canvas.nim
✗ widgets/modern/dragdroparea.nim
✗ widgets/modern/mapwidget.nim
✗ widgets/modern/timeline.nim
```

### Examples & Tests (All unused - expected)
```
All 69 example files in examples/
All 14 test files in pangolib_binding/
All 3 files in REFACTORING_EXAMPLES/
```

### Scripting
```
✗ scripting/messages.nim
```

---

## Critical Issues Found

### 1. 🔴 DSL Version Confusion
- Currently using: `widget_dsl_v2.nim`
- Exists but unused: `widget_dsl_v3.nim` + helpers
- Need to decide: v2 or v3? What's the difference?

### 2. 🔴 Hit-Testing System Not Integrated
- Entire `hit-testing/` module unused
- Required for: Mouse click detection, hover states
- FocusManager expects hit-testing for mouse-to-focus

### 3. 🔴 Layout System Missing?
- No layout calculation imports
- How are widgets being positioned?
- Multiple layout files exist but none imported

### 4. 🔴 Recently Created Files Not Imported
- `drawing_primitives/widget_primitives.nim` - Created yesterday but not in rui.nim
- `managers/focus_manager.nim` - IS imported ✓
- Need to add widget_primitives to rui.nim

### 5. 🔴 Version Conflicts
- Many widgets have v2 versions alongside old versions
- Old versions unused but still in codebase
- Cleanup needed

---

## Recommendations

### Immediate Actions

1. **Decide on DSL version:**
   - Review widget_dsl_v3.nim
   - If v3 is better, migrate to it
   - If v2 is correct, document why v3 exists

2. **Integrate hit-testing:**
   - Add to rui.nim imports
   - Connect to FocusManager for mouse clicks
   - Connect to event system

3. **Add widget_primitives.nim:**
   ```nim
   import drawing_primitives/widget_primitives
   export widget_primitives
   ```

4. **Clarify layout system:**
   - Document where layout calculations happen
   - If in widget code, that's fine
   - If missing, integrate layout module

5. **Clean up old versions:**
   - Move old widget files to deprecated/
   - Or delete if no longer needed
   - Clear naming: keep v2, remove unversioned

### Long-term Actions

6. **Import unused widgets gradually:**
   - Add to aggregator modules as needed
   - Test each before adding to rui.nim

7. **Document import architecture:**
   - Create import dependency diagram
   - Explain layered system in README

8. **Audit Pango integration:**
   - Determine if needed
   - If yes, integrate properly
   - If no, remove files

---

## Files Actively in Use - Full List

```
core/app.nim
core/link.nim
core/types.nim
core/widget_dsl_v2.nim
managers/event_manager.nim
managers/focus_manager.nim
drawing_primitives/drawing_primitives.nim
drawing_primitives/theme_sys_core.nim
drawing_primitives/builtin_themes.nim
drawing_primitives/primitives/shapes.nim
drawing_primitives/primitives/text.nim
drawing_primitives/primitives/text_cache.nim
drawing_primitives/primitives/controls.nim
drawing_primitives/primitives/indicators.nim
drawing_primitives/primitives/panels.nim
widgets/primitives.nim
widgets/primitives/label.nim
widgets/primitives/rectangle.nim
widgets/primitives/circle.nim
widgets/basic.nim
widgets/basic/button_v2.nim
widgets/basic/checkbox.nim
widgets/basic/radiobutton.nim
widgets/basic/slider.nim
widgets/basic/progressbar.nim
widgets/basic/hyperlink.nim
widgets/containers.nim
widgets/containers/vstack_v2.nim
widgets/containers/hstack_v2.nim
widgets/containers/zstack_v2.nim
rui.nim
```

**Total: 31 files forming the active core of RUI2**

---

## Conclusion

The codebase has significant bloat (82% unused files) but a **clear, clean core of 31 files** that represent the actual working system. Main concerns are:

1. Missing critical infrastructure (hit-testing, possibly layout)
2. DSL version confusion (v2 vs v3)
3. Recently created improvements not yet integrated (widget_primitives)

These should be addressed before adding more features.
