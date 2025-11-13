# Overlay Widget Rendering with Z-Index Sorting

## Overview

RUI2 now supports efficient z-index based rendering for widgets that contain overlays (like dropdowns, menus, tooltips). This is implemented using the `hasOverlay` flag on the Widget type.

## How It Works

### Default Behavior (hasOverlay = false)
Children render in **tree order** (as they appear in the children list):
```nim
VStack:
  Button1         # Renders first
  Button2         # Renders second
  Button3         # Renders third (on top)
```

### Overlay Mode (hasOverlay = true)
Children render in **z-index order** (sorted from low to high):
```nim
MenuBar:                  # Set hasOverlay = true
  Menu1  (zIndex = 1)     # Renders first
  Menu2  (zIndex = 1)     # Renders second
  Dropdown (zIndex = 1000) # Renders last (on top), regardless of position in tree
```

## Usage Example

### 1. Enable Overlay Mode

For any widget that needs to render children in z-index order:

```nim
defineWidget(MenuBar):
  props:
    # ... your props

  init:
    # Enable z-index sorting for children
    widget.hasOverlay = true

  layout:
    # ... your layout code

  render:
    # Children will automatically render in z-index order
```

### 2. Set Z-Index on Children

```nim
# Regular menu items get normal z-index
let fileMenu = newMenu(title = "File")
fileMenu.zIndex = 1

let editMenu = newMenu(title = "Edit")
editMenu.zIndex = 1

# Dropdown gets high z-index when opened
proc openDropdown(dropdown: Widget) =
  dropdown.zIndex = 1000  # Move to overlay layer
  dropdown.visible = true

proc closeDropdown(dropdown: Widget) =
  dropdown.visible = false
  dropdown.zIndex = 1     # Reset to normal
```

### 3. Complete Example

```nim
import rui

# Create a menu bar with overlays
let menuBar = newMenuBar(height = 30)
menuBar.hasOverlay = true  # Enable z-index sorting

# Add menu items
let fileMenu = newMenu(title = "File")
fileMenu.zIndex = 1
menuBar.addChild(fileMenu)

let editMenu = newMenu(title = "Edit")
editMenu.zIndex = 1
menuBar.addChild(editMenu)

# Create dropdown (initially hidden)
let dropdown = newDropdownPanel()
dropdown.zIndex = 1      # Normal z-index when closed
dropdown.visible = false
menuBar.addChild(dropdown)

# When user clicks menu
proc onMenuClick() =
  dropdown.visible = true
  dropdown.zIndex = 1000  # High z-index ensures it renders on top
  menuBar.isDirty = true  # Trigger re-render
```

## Performance

### Optimization Strategy

The `hasOverlay` flag is an **optimization** - sorting only happens when needed:

- **hasOverlay = false**: No sorting, renders in tree order (fast path)
- **hasOverlay = true**: Sorts children by z-index before rendering (only when needed)
- **Single child**: No sorting even if hasOverlay = true (optimization)

### Cost Analysis

```nim
# No overlay: O(n) where n = number of children
for child in widget.children:
  child.renderPass()

# With overlay: O(n log n) for sort + O(n) for render
var sorted = widget.children.sorted(by zIndex)
for child in sorted:
  child.renderPass()
```

**Typical case**: Menus/toolbars have 3-10 children, so sorting cost is negligible (< 50 comparisons).

## Z-Index Conventions

### Recommended Ranges

```nim
const
  LAYER_NORMAL   = 0..999      # Regular UI elements
  LAYER_OVERLAY  = 1000..1999  # Dropdowns, popovers
  LAYER_POPUP    = 2000..2999  # Modal popups
  LAYER_MODAL    = 3000..3999  # Full-screen modals
  LAYER_TOOLTIP  = 4000..9999  # Tooltips (always on top)
```

### Example Usage

```nim
button.zIndex = 1           # Normal button
dropdown.zIndex = 1000      # Dropdown overlay
modal.zIndex = 3000         # Modal dialog
tooltip.zIndex = 5000       # Tooltip
```

## Implementation Details

### Widget Type Addition

```nim
type
  Widget* = ref object
    # ... other fields
    zIndex*: int
    hasOverlay*: bool  # If true, children sorted by z-index during rendering
```

### Render Pass Logic

```nim
proc renderPass*(widget: Widget) =
  if not widget.visible:
    return

  # Render this widget
  widget.render()

  # Recurse to children
  if widget.hasOverlay and widget.children.len > 1:
    # Sort by z-index (ascending: low renders first, high on top)
    var sortedChildren = widget.children
    sortedChildren.sort(proc(a, b: Widget): int = cmp(a.zIndex, b.zIndex))
    for child in sortedChildren:
      child.renderPass()
  else:
    # Fast path: tree order
    for child in widget.children:
      child.renderPass()
```

## When to Use hasOverlay

✅ **Use hasOverlay = true when:**
- Widget contains dropdowns/menus that overlay siblings
- Widget has tooltips or popovers
- Children can dynamically change z-index
- Need to guarantee z-order regardless of tree structure

❌ **Don't use hasOverlay when:**
- All children render in natural order (like VStack, HStack)
- No overlapping children
- Performance is critical and no overlays exist

## Advanced: Dynamic Overlay Management

```nim
# Enable overlay mode only when dropdown is open
proc openMenu(menuBar: Widget, dropdown: Widget) =
  menuBar.hasOverlay = true   # Enable sorting
  dropdown.zIndex = 1000
  dropdown.visible = true

proc closeMenu(menuBar: Widget, dropdown: Widget) =
  menuBar.hasOverlay = false  # Disable sorting (optimization)
  dropdown.visible = false
  dropdown.zIndex = 1
```

## See Also

- `hit-testing/hittest_system.nim` - Hit testing also uses z-index sorting
- `core/types.nim:113-114` - Widget type definition
- `core/main_loop.nim:104-114` - Render pass implementation
