# Overlay-Enabled Widgets in RUI2

## Summary

This document lists which widgets have `hasOverlay = true` enabled and explains the reasoning.

## Widgets with hasOverlay = true

### 1. MenuBar (widgets/menus/menubar.nim)

**Enabled:** ✅ YES

**Reason:** MenuBar contains Menu widgets as children. When a menu is opened, it needs to render as a dropdown that overlays other menu items and UI elements. The z-index sorting ensures that an open dropdown menu (with high z-index like 1000) renders on top of closed menus (with normal z-index like 1).

**Usage Example:**
```nim
let menuBar = newMenuBar(height = 30)
# hasOverlay is automatically set to true in init block

let fileMenu = newMenu(title = "File")
fileMenu.zIndex = 1  # Normal z-index when closed

let editMenu = newMenu(title = "Edit")
editMenu.zIndex = 1

menuBar.addChild(fileMenu)
menuBar.addChild(editMenu)

# When opening a menu:
fileMenu.zIndex = 1000  # High z-index for dropdown overlay
fileMenu.isOpen.set(true)

# MenuBar will render children sorted by z-index:
# 1. editMenu (z=1)
# 2. fileMenu (z=1000) <- renders on top
```

## Widgets WITHOUT hasOverlay

These widgets do NOT need `hasOverlay = true` because they don't have overlapping children that need z-index sorting:

### 2. Menu (widgets/menus/menu.nim)

**Enabled:** ❌ NO

**Reason:** Menu is a simple vertical list of MenuItem children. All items are stacked in order with no overlapping. The menu itself IS the dropdown/overlay, but its children (MenuItems) don't overlay each other.

### 3. ContextMenu (widgets/menus/contextmenu.nim)

**Enabled:** ❌ NO

**Reason:** ContextMenu is a popup that contains MenuItems in a vertical list. Like Menu, the items don't overlay each other. The ContextMenu itself is positioned as a popup, but its internal children are just a simple list.

### 4. MessageBox (widgets/dialogs/messagebox.nim)

**Enabled:** ❌ NO

**Reason:** MessageBox is a modal dialog with internal buttons and text. It doesn't have children that need z-ordering. The entire MessageBox widget has a high z-index to appear on top, but its internal UI elements don't compete for layering.

### 5. FileDialog (widgets/dialogs/filedialog.nim)

**Enabled:** ❌ NO

**Reason:** FileDialog is a modal dialog with internal components (file list, buttons, path bar). These are laid out in a fixed arrangement with no overlapping that would require z-index sorting.

### 6. FilePicker (widgets/dialogs/filepicker.nim)

**Enabled:** ❌ NO

**Reason:** Similar to FileDialog - internal components don't overlay each other.

## When to Enable hasOverlay

Use `hasOverlay = true` when:

✅ **Widget contains children that can dynamically overlay each other**
- Example: MenuBar with dropdown menus
- Example: TabBar with popup overflow menu
- Example: Toolbar with expandable button groups

✅ **Children have varying z-index values that determine render order**
- Some children render normally (z-index 0-100)
- Some children become overlays when activated (z-index 1000+)

✅ **Tree position doesn't match desired render order**
- A dropdown added as first child needs to render on top of later siblings

## When NOT to Enable hasOverlay

Don't use `hasOverlay = true` when:

❌ **Children are in a simple list/stack** (VStack, HStack, Menu, ContextMenu)

❌ **All children render in natural tree order** (no z-index variations)

❌ **Widget has no children** (primitives like Button, Label)

❌ **Widget IS the overlay itself** (modals, popups - they have high z-index but their children don't need sorting)

## Performance Considerations

### Cost of hasOverlay

```nim
# hasOverlay = false (fast path)
for child in widget.children:  # O(n)
  child.renderPass()

# hasOverlay = true (with sorting)
var sorted = widget.children.sorted()  # O(n log n)
for child in sorted:  # O(n)
  child.renderPass()
```

**Impact:** For typical menus (3-10 children), sorting adds ~20-50 comparisons. Negligible overhead.

**Optimization:** Sorting is skipped if `children.len <= 1`, so single-child widgets pay no penalty.

## Implementation Details

### How It's Set

The `hasOverlay` flag is set in the widget's `init` block:

```nim
defineWidget(MenuBar):
  # ... props, state, actions ...

  init:
    widget.hasOverlay = true  # Enable z-index sorting

  # ... layout, render ...
```

### How It Works

In `core/main_loop.nim`, the `renderPass` checks the flag:

```nim
proc renderPass*(widget: Widget) =
  # ... render this widget ...

  # Render children
  if widget.hasOverlay and widget.children.len > 1:
    # Sort children by z-index before rendering
    var sortedChildren = widget.children
    sortedChildren.sort(proc(a, b: Widget): int = cmp(a.zIndex, b.zIndex))
    for child in sortedChildren:
      child.renderPass()
  else:
    # Fast path: render in tree order
    for child in widget.children:
      child.renderPass()
```

## Future Widgets

When creating new widgets, ask:

**Q:** Does this widget have children that can overlay each other?
**A:** If YES → set `hasOverlay = true` in the init block

**Examples of future widgets that would need hasOverlay:**
- ComboBox (contains dropdown list that overlays button)
- Toolbar (might have expandable button groups)
- Ribbon (has popup menus for collapsed groups)
- TabContainer (if it has overflow menu for tabs)
- SplitView (if it has draggable splitter that overlays content)

**Examples that wouldn't need hasOverlay:**
- VStack, HStack, Grid (children in fixed layout)
- ScrollView (children scroll together, no overlaying)
- Panel, Card, Window (decorative container, children don't overlay)
