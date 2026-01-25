# AGENTS.md - RUI2 Development Guide

## Build Commands

### Running Examples/Tests
```bash
nim c -r examples/button_test.nim          # Single test file
nim c -r examples/integration_test.nim     # Integration tests
nim c -r examples/dsl_test_button.nim      # DSL features
nim c -r examples/pango_stress_test.nim    # Pango text
```

### Debug & Headless
```bash
nim c -d:debug examples/button_test.nim    # Debug symbols
nim c -d:useGraphics=false examples/test.nim  # Headless mode
nim c -f -w:on examples/test.nim           # Force recompile
```

## Project Structure

```
/home/kl/prog/rui2/
  core/           # types, widget_dsl, link, app
  widgets/        # basic, containers, input, primitives
  managers/       # event, focus, layout managers
  drawing_primitives/  # rendering, themes
  examples/       # test files and demos
  scripting/      # scripting system
```

## Code Style

### Imports
```nim
import std/[tables, sets, hashes, options, json]
import ../core/[types, widget_dsl, link]
import raylib
export sets, tables, options
```

### Naming
- **Types**: PascalCase (`Widget`, `Button`)
- **Procedures/Functions**: snake_case (`newWidget`, `handleInput`)
- **Constants**: camelCase with `*` (`RuiVersion*`)
- **Macros**: lowercase with `*` (`defineWidget*`)
- **Local vars**: snake_case (`mousePos`, `buttonColor`)

### Widget Definition
```nim
defineWidget(Button):
  props:
    text: string
    bgColor: raylib.Color = GRAY
    disabled: bool = false

  state:
    isPressed: bool
    isHovered: bool

  actions:
    onClick()

  events:
    on_mouse_down:
      if not widget.disabled:
        widget.isPressed = true
        return true
      return false

  layout:
    widget.children.setLen(0)
    # ... layout logic

  render:
    # ... render logic
```

### Type Definitions
```nim
type
  WidgetId* = distinct int
  Rect* = object
    x*, y*: float32
    width*, height*: float32
  Widget* = ref object of RootObj
    id*: WidgetId
    bounds*: Rect
    visible*: bool
    children*: seq[Widget]
```

### Error Handling
```nim
method handleScriptAction*(widget: Widget, action: string, 
                           params: JsonNode): JsonNode =
  result = %*{
    "success": false,
    "error": "Action not supported: " & action
  }
```

Use `Option[T]` for optional values. Use `try/except` sparingly.

### Documentation
```nim
proc newWidget*(): Widget =
  ## Create a new widget with default values
  ## Call setBounds() before adding to tree
  result = Widget()
```
Use `##` for docs, `#` for comments.

### Testing
- Tests are standalone files in `examples/`
- Use `when isMainModule:` guard
- Verify visual output or console output
- Log debug info for headless testing

### Reactive State (Link[T])
```nim
type Store* = ref object of RootObj
  counter*: Link[int]
  message*: Link[string]

var store = Store(counter: newLink(0), message: newLink("Hello"))
store.counter.set(store.counter.get() + 1)
echo store.counter.get()
```

### Common Patterns
```nim
# Option handling
if widget.onClick.isSome:
  widget.onClick.get()()

# JsonNode construction
result = %*{
  "success": true,
  "data": %*{"x": widget.bounds.x, "y": widget.bounds.y}
}
```

## Key Files

- `core/types.nim` - Core types (Widget, Rect, Link)
- `core/widget_dsl_v3.nim` - Widget macros
- `core/link.nim` - Reactive state
- `core/app.nim` - App loop
- `rui.nim` - Main module, exports all APIs

## Dependencies

- **Nim**: Latest stable
- **Raylib**: Graphics
- **Pango/Cairo**: Text rendering
- **Stdlib**: tables, sets, hashes, options, json

## Testing New Features

1. Create minimal example in `examples/baby/` or `examples/`
2. Run with `nim c -r examples/your_test.nim`
3. Verify output
4. Integrate into widget library
5. Update documentation
