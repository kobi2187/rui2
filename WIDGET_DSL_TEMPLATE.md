# Widget DSL v2 - Standard Template

This document shows the standard template for creating widgets with RUI2's DSL v2.

## Design Principles

1. **Explicit over implicit** - All sections are always present, even if empty
2. **Transparent** - Widget tree is a regular Nim proc that returns a Widget
3. **Non-magic** - You can see and debug all parts
4. **Separation of concerns** - Behavior in widget file, implementation in `_internal.nim`

## Standard Widget Structure

### Primitive Widget Template

```nim
## MyWidget - Brief description
##
## Usage:
##   MyWidget(text = "Hello", onClick = proc() = echo "Clicked")

import ../../core/widget_dsl_v2
import std/options

when defined(useGraphics):
  import raylib

# Optional: Widget-specific types and helpers will be in mywidget_internal.nim
# The macro automatically imports it if it exists

definePrimitive(MyWidget):
  props:
    text: string = ""
    disabled: bool = false
    # Add properties here

  state:
    discard  # Use 'discard' if no state needed
    # Or add state:
    # isPressed: bool

  actions:
    discard  # Use 'discard' if no actions needed
    # Or add actions:
    # onClick()
    # onHover(x: float, y: float)

  events:
    discard  # Use 'discard' if no event handling needed
    # Or add event handlers:
    # on_mouse_down:
    #   if not widget.disabled:
    #     # Handle event
    #     return true  # Event consumed
    #   return false   # Event not handled

  render:
    when defined(useGraphics):
      # Raylib rendering code
      DrawText(widget.text.cstring,
               widget.bounds.x.int32,
               widget.bounds.y.int32,
               20,
               BLACK)
    else:
      # Non-graphics mode fallback
      echo "MyWidget: ", widget.text
```

### Composite Widget Template

```nim
## MyContainer - Brief description
##
## Usage:
##   MyContainer(spacing = 10):
##     Label(text = "Child 1")
##     Label(text = "Child 2")

import ../../core/widget_dsl_v2
import std/options

when defined(useGraphics):
  import raylib

defineWidget(MyContainer):
  props:
    spacing: float = 8.0
    padding: float = 0.0
    # Add properties here

  state:
    discard  # Use 'discard' if no state needed

  actions:
    discard  # Use 'discard' if no actions needed

  events:
    discard  # Use 'discard' if no event handling needed

  layout:
    # REQUIRED for composite widgets - arrange children
    var y = widget.bounds.y + widget.padding
    for child in widget.children:
      child.bounds.x = widget.bounds.x + widget.padding
      child.bounds.y = y
      child.bounds.width = widget.bounds.width - (widget.padding * 2)
      # child.updateLayout() - if child is composite
      y += child.bounds.height + widget.spacing

  render:
    discard  # Optional - composite widgets usually don't draw themselves
    # Or add decoration:
    # when defined(useGraphics):
    #   DrawRectangleLines(...)
```

## Widget with Internal Implementation

For complex widgets, separate behavior from implementation:

**mywidget.nim** (Behavior - what the widget does):
```nim
import ../../core/widget_dsl_v2
import std/options

# Macro automatically imports mywidget_internal.nim if it exists

definePrimitive(MyWidget):
  props:
    text: string
    maxLength: int = 100

  state:
    currentValue: string

  actions:
    onChange(value: string)

  events:
    on_mouse_down:
      # Call implementation from _internal.nim
      handleMouseDown(widget, event)
      return true

  render:
    # Call implementation from _internal.nim
    renderWidget(widget)
```

**mywidget_internal.nim** (Implementation - how it's done):
```nim
import ../../core/types
when defined(useGraphics):
  import raylib

# Types
type
  WidgetState* = object
    cursorPos*: int
    selection*: tuple[start, stop: int]

# Implementation functions
proc handleMouseDown*(widget: MyWidget, event: GuiEvent) =
  ## Handle mouse down - calculate cursor position, etc.
  # Complex implementation here...
  discard

proc renderWidget*(widget: MyWidget) =
  ## Render the widget with all visual details
  when defined(useGraphics):
    # Complex rendering here...
    discard
```

## Complete Application Example

```nim
import rui

# 1. Define store (reactive state)
type AppStore = object
  counter: Link[int]
  message: Link[string]

var store = AppStore(
  counter: newLink(0),
  message: newLink("Hello, RUI!")
)

# 2. Define helper procs (regular Nim code)
proc incrementCounter() =
  store.counter.set(store.counter.get() + 1)
  store.message.set(&"Clicked {store.counter.get()} times")

# 3. Build widget tree (returns Widget)
proc buildUI(): Widget =
  VStack(spacing = 10):
    Label(text = store.message.get())

    HStack(spacing = 5):
      Button(
        text = "Increment",
        onClick = incrementCounter
      )
      Button(
        text = "Reset",
        onClick = proc() =
          store.counter.set(0)
          store.message.set("Reset!")
      )

    Label(text = &"Count: {store.counter.get()}")

# 4. Create app, set root, start
let app = newApp("Counter Demo", 400, 300)
app.setRootWidget(buildUI())
app.start()
```

## Key Points

### Always Use All Sections

Even if empty, include all sections with `discard`:

```nim
definePrimitive(SimpleLabel):
  props:
    text: string

  state:
    discard  # No state needed

  actions:
    discard  # No callbacks needed

  events:
    discard  # No event handling needed

  render:
    echo widget.text
```

This makes the structure explicit and helps users learn the syntax.

### Automatic _internal.nim Import

If you create `mywidget_internal.nim` next to `mywidget.nim`, the macro will automatically import it. This keeps the widget definition clean while allowing complex implementations.

### Widget Tree as Variable

The widget tree is just a proc that returns a Widget:

```nim
let ui = buildUI()  # Returns Widget
app.setRootWidget(ui)  # Set it explicitly
```

You can inspect, modify, or replace it at any time.

### Regular Nim Code

Use regular procs, functions, and Nim features:

```nim
proc calculateLayout(width: float): float =
  width * 0.8

proc buildButton(label: string): Widget =
  Button(
    text = label,
    onClick = proc() = echo "Clicked: ", label
  )

proc buildUI(): Widget =
  let buttonWidth = calculateLayout(400.0)
  VStack:
    buildButton("First")
    buildButton("Second")
```

No magic - just Nim!

## Best Practices

1. **Keep widget definitions small** - Move complex logic to `_internal.nim`
2. **Use descriptive names** - `onValueChanged` not `onChange`
3. **Document props** - Add comments explaining what each prop does
4. **Provide defaults** - Make widgets easy to use with sensible defaults
5. **Return values** - Widget tree builders should return `Widget`
6. **Use Link[T] for reactivity** - All mutable state should be Link[T]
7. **Keep it explicit** - Don't hide complexity, make it visible

## Migration from Old DSL

Old style (implicit):
```nim
defineWidget(Button):
  # Only specify what's needed
  props:
    text: string
  render:
    drawButton(widget)
```

New style (explicit):
```nim
definePrimitive(Button):
  props:
    text: string

  state:
    discard

  actions:
    discard

  events:
    discard

  render:
    drawButton(widget)
```

The explicit style makes learning easier and debugging clearer.
