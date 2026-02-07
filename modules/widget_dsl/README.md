# Widget DSL Module

Macro-based domain-specific language for defining widgets with props, state, actions, events, render, and layout blocks.

## Public API

```nim
import modules/widget_dsl/api
```

### Macros

**`definePrimitive(Name)`** — Define a leaf widget (draws, no children):
```nim
definePrimitive(Label):
  props:
    text: string = ""
    fontSize: float32 = 14.0
  render:
    drawText(widget.text, widget.bounds)
```

**`defineWidget(Name)`** — Define a composite widget (has children):
```nim
defineWidget(Panel):
  props:
    title: string
  state:
    expanded: bool
  actions:
    onClick()
  events:
    on_mouse_down:
      if widget.onClick.isSome: widget.onClick.get()()
      return true
  layout:
    # position children
  render:
    drawBackground(widget.bounds)
```

### Generated Code

Each macro generates:
- Type definition (inherits from `Widget`)
- Constructor (`newLabel(text = "")`)
- `render` method override
- `layout` method override (defineWidget only)
- `handleInput` method override (if events defined)
- `getTypeName` method override

### DSL Sections

| Section | Purpose | Available In |
|---|---|---|
| `props` | Public properties with optional defaults | Both |
| `state` | Internal mutable state | Both |
| `actions` | Optional callback procs (`Option[proc()]`) | Both |
| `events` | Event handlers (on_mouse_down, on_key_down, etc.) | Both |
| `render` | Drawing code | Both |
| `layout` | Child positioning code | defineWidget only |
| `init` | Initialization code | Both |

### Dependencies
- `core/types` (Widget, GuiEvent, etc.)
- `core/link` (Link[T] for reactive binding)
