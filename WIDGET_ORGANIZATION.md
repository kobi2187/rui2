# Widget Organization

All widgets have been refactored into a clean directory structure with proper imports.

## Directory Structure

```
widgets/
├── basic/           # Basic UI elements
│   ├── label.nim           - Text display with theme support
│   ├── button.nim          - Basic button widget
│   └── button_yaml.nim     - Button with YAML-UI style events
├── input/           # User input widgets
│   └── textinput.nim       - Single-line text input with cursor
└── containers/      # Layout containers
    ├── vstack.nim          - Vertical stack layout
    ├── hstack.nim          - Horizontal stack layout
    └── column.nim          - Legacy column (use vstack instead)
```

## Layout System

```
layout/
└── layout_helpers.nim      - Composable layout helper functions
```

## Import Paths

From the project root:
```nim
# Basic widgets
import widgets/basic/label
import widgets/basic/button
import widgets/basic/button_yaml

# Input widgets
import widgets/input/textinput

# Container widgets
import widgets/containers/vstack
import widgets/containers/hstack

# Layout helpers
import layout/layout_helpers
```

## Widget Categories

### Basic Widgets
- **Label**: Theme-aware text display with state-based styling
- **Button**: Clickable button with hover/press states
- **ButtonYAML**: Button with YAML-UI style event handlers

### Input Widgets
- **TextInput**: Single-line text editing with cursor, selection, keyboard handling

### Container Widgets
- **VStack**: Vertical stack with alignment and spacing (Start, Center, End, SpaceBetween, SpaceAround, SpaceEvenly)
- **HStack**: Horizontal stack with alignment and spacing
- **Column**: Legacy name for VStack (deprecated, use VStack)

## Compilation Status

All widgets compile successfully with proper imports:

```bash
# Basic widgets
nim c -d:useGraphics widgets/basic/label.nim          ✓
nim c -d:useGraphics widgets/basic/button.nim         ✓
nim c -d:useGraphics widgets/basic/button_yaml.nim    ✓

# Input widgets
nim c -d:useGraphics widgets/input/textinput.nim      ✓

# Container widgets
nim c -d:useGraphics widgets/containers/vstack.nim    ✓
nim c -d:useGraphics widgets/containers/hstack.nim    ✓

# Layout
nim c -d:useGraphics layout/layout_helpers.nim        ✓
```

## Migration Guide

If you're updating existing code:

### Old imports:
```nim
import widgets/label
import widgets/button
import widgets/vstack
```

### New imports:
```nim
import widgets/basic/label
import widgets/basic/button
import widgets/containers/vstack
```

### For examples that import widgets:
```nim
# From examples directory:
import ../widgets/basic/[button_yaml, label]
import ../widgets/containers/vstack
```

## Next Steps

Consider creating:
- `widgets/display/` - Read-only display widgets (image, icon, progress bar)
- `widgets/selection/` - Selection widgets (checkbox, radio, dropdown)
- `widgets/advanced/` - Complex widgets (table, tree, tabs)
