# RUI Module - Unified API

The `rui.nim` module provides a single import for the entire RUI2 framework!

## Why?

Instead of importing multiple modules:
```nim
# Old way - multiple imports
import core/[types, app, link]
import managers/event_manager
import drawing_primitives/[theme_sys_core, builtin_themes]
import widgets/basic/[label, button]
import widgets/containers/[hstack, vstack]
import raylib
```

You can now use a single import:
```nim
# New way - one import!
import rui

# Everything is available!
let app = newApp(...)
let theme = createDarkTheme()
let button = newButton()
```

## What's Included

The `rui` module exports:

### Core Framework
- `core/types` - Base types (Widget, Point, Size, Color, etc.)
- `core/app` - Application management (newApp, run, setWindowSize)
- `core/link` - Reactive state system (Link[T])

### Event System
- `managers/event_manager` - Event handling and coalescing

### Drawing & Layout
- `drawing_primitives/drawing_primitives` - Basic drawing functions
- `drawing_primitives/layout_primitives` - Layout primitives

### Theme System
- `drawing_primitives/theme_sys_core` - Theme types and API
- `drawing_primitives/builtin_themes` - Built-in themes (Light, Dark, BeOS, Joy, Wide)

### Widgets - Basic
- `widgets/basic/label` - Text labels
- `widgets/basic/button` - Buttons
- `widgets/basic/button_yaml` - YAML-configured buttons

### Widgets - Input
- `widgets/input/textinput` - Text input fields

### Widgets - Containers
- `widgets/containers/hstack` - Horizontal stack layout
- `widgets/containers/vstack` - Vertical stack layout
- `widgets/containers/column` - Column layout (deprecated, use VStack)

### Graphics Backend
- `raylib` - Raylib graphics library (when compiled with `-d:useGraphics`)

## Version Info

```nim
import rui

echo ruiVersionString()  # "RUI2 v0.1.0"
echo RuiVersion          # "0.1.0"
echo RuiVersionMajor     # 0
echo RuiVersionMinor     # 1
echo RuiVersionPatch     # 0
```

## Quick Start Template

The `rui` module includes a `quickApp` template for rapid prototyping:

```nim
import rui

quickApp("My App", 800, 600):
  # Your app setup code here
  # 'app' variable is injected automatically

  let button = newButton()
  app.setRootWidget(button)
```

This expands to:
```nim
let app = newApp("My App", 800, 600)
# Your code here
app.run()
```

## Examples

### Minimal Example

```nim
import rui

proc main() =
  let app = newApp("Hello RUI", 800, 600)
  app.run()

when isMainModule:
  main()
```

See `examples/rui_simple_example.nim`

### Complete Example with Themes

```nim
import rui

proc main() =
  echo ruiVersionString()

  let app = newApp(
    title = "Themed App",
    width = 800,
    height = 600,
    resizable = true,
    minWidth = 600,
    minHeight = 400
  )

  let theme = createDarkTheme()

  # TODO: Create widgets and set theme

  app.run()

when isMainModule:
  main()
```

See `examples/rui_full_example.nim`

### Window with Resize Control

```nim
import rui

proc main() =
  let app = newApp(
    title = "Resizable Window",
    width = 800,
    height = 600,
    resizable = true,
    minWidth = 400,
    minHeight = 300
  )

  # Programmatically resize
  app.setWindowSize(1024, 768)

  # Toggle resizability
  app.setWindowResizable(false)

  app.run()

when isMainModule:
  main()
```

## Benefits

1. **Single Import** - No need to remember which module has what
2. **Consistent API** - Everything available from one place
3. **Faster Development** - Less boilerplate, more coding
4. **Better IDE Support** - Autocomplete sees everything
5. **Easier Learning** - New users don't need to know module structure
6. **Version Tracking** - Built-in version constants

## Migration Guide

### From Old Imports

**Before:**
```nim
import core/[types, app]
import drawing_primitives/builtin_themes
import widgets/basic/button

let app = newApp("App", 800, 600)
let theme = createDarkTheme()
let btn = newButton()
```

**After:**
```nim
import rui

let app = newApp("App", 800, 600)
let theme = createDarkTheme()
let btn = newButton()
```

Everything works exactly the same, just cleaner imports!

## Not Included (Intentionally)

Some modules with issues are excluded:
- `drawing_primitives/layout_core` - Circular dependencies with Widget
- `drawing_primitives/layout_calcs` - Syntax errors, not used

These may be fixed and added in future versions.

## Compilation

The `rui` module compiles cleanly:

```bash
# Test compilation
nim c -d:useGraphics rui.nim  ✓

# Use in your app
nim c -d:useGraphics my_app.nim  ✓
```

## Future Additions

As RUI2 grows, the `rui` module will automatically include:
- New widgets as they're created
- Additional layout systems
- Plugin/extension support
- More built-in themes

Just import `rui` and you'll always have access to the latest API!
