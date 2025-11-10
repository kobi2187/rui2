# DSL Design Clarifications

Critical design decisions for transparent understanding and simple mental model.

## 1. Event Propagation - Simple Bubbling

**Rule**: Events bubble up from child to parent until handled.

```nim
definePrimitive(Button):
  events:
    on_mouse_up:
      if widget.onClick != nil:
        widget.onClick()
        return true  # Event handled, stop propagation
      else:
        return false  # Not handled, bubble to parent

defineWidget(Panel):
  events:
    on_mouse_up:
      # Panel only sees this if Button didn't handle it
      echo "Panel clicked (button missed)"
      return true
```

**Mental model**:
1. Event hits deepest widget first (the one under mouse)
2. Widget's `events:` block runs
3. If returns `true` → stop, event consumed
4. If returns `false` → continue to parent
5. Repeat until handled or reach root

**No capture phase, no stopPropagation magic** - just simple bubbling.

## 2. Data Binding - Unidirectional Only

**Rule**: Data flows ONE WAY - from state/props to widget display.

```nim
# WRONG - No automatic two-way binding
TextInput(value <-> appState.username)  # ✗ Not supported

# RIGHT - Use actions for reverse flow
TextInput(
  value: appState.username.get(),  # State → Widget (read)
  onChange: proc(v: string) = appState.username.set(v)  # Widget → State (write via action)
)
```

**Mental model**:
- **State → Widget**: Automatic (widget reads in render/layout)
- **Widget → State**: Manual via action callbacks

**Why unidirectional?**
- Explicit data flow
- No hidden mutations
- Easy to debug
- Clear ownership

## 3. Layout DSL Syntax - Two Forms

### Form 1: Property Assignment
```nim
layout:
  vstack:
    spacing = 10      # Sets vstack.spacing
    padding = EdgeInsets(all: 20)  # Sets vstack.padding
    alignment = Center  # Sets vstack.alignment
```

**These are property assignments to the container being created.**

### Form 2: Child Widget Creation
```nim
layout:
  vstack:
    Label(text: "Hello")    # Creates: newLabel(text: "Hello")
    Button(text: "Click")   # Creates: newButton(text: "Click")
```

**These are constructor calls, expanded by the macro.**

### Combined Example
```nim
layout:
  vstack:                    # Creates: let container = newVStack()
    spacing = 10             # Sets: container.spacing = 10
    padding = EdgeInsets(all: 20)  # Sets: container.padding = ...

    Label(text: "Title")     # Creates: let child1 = newLabel(text: "Title")
                             # Adds: container.addChild(child1)

    Button(text: "Click")    # Creates: let child2 = newButton(text: "Click")
                             # Adds: container.addChild(child2)
```

**Macro distinguishes**:
- `name = value` → Property assignment to container
- `Name(args)` → Child widget constructor call

### Control Flow in Layout
```nim
layout:
  vstack:
    spacing = 10

    # Control flow works!
    if widget.showTitle:
      Label(text: widget.title)

    for item in widget.items:
      Label(text: item.name)

    if widget.showButton:
      Button(text: "OK", onClick: widget.onOK)
```

**Mental model**: Layout block is normal Nim code that builds a widget tree.

## 4. Widget Code Organization

**Problem**: Where does widget logic live?

**Solution**: Three-layer architecture

### Layer 1: `widgets/{category}/{widget}_internal.nim`
Internal implementation - all the real logic:

```nim
# widgets/basic/label_internal.nim
import ../../core/types
import ../../drawing_primitives

proc renderLabel*(widget: Label, bounds: Rect, text: string, theme: Theme) =
  ## Internal render logic - called by Label widget
  let props = theme.getProps(widget.intent, widget.state)
  let textSize = measureText(text, props.fontSize)
  let textPos = centerText(bounds, textSize)
  drawText(text, textPos, props.foregroundColor, props.fontSize)

proc measureLabel*(text: string, fontSize: float): Size =
  ## Internal measure logic
  measureText(text, fontSize)
```

**Contains**:
- Pure render functions
- Measurement functions
- Helper utilities
- No widget lifecycle, just operations

### Layer 2: `widgets/{category}/{widget}.nim`
Widget definition - uses DSL, calls internal:

```nim
# widgets/basic/label.nim
import label_internal
import ../../core/[types, widget_dsl_v2]

definePrimitive(Label):
  props:
    text: string
    fontSize: float = 14.0

  state:
    # None needed for Label

  actions:
    # None needed for Label

  events:
    # Labels don't handle events (just display)
    on_mouse_up:
      return false  # Let parent handle

  render:
    # Delegate to internal
    renderLabel(widget, widget.bounds, widget.text, app.currentTheme)
```

**Contains**:
- Widget structure (props, state, actions)
- Event routing (calls actions)
- Thin wrapper around internal

### Layer 3: Application Code
Uses widgets:

```nim
import rui

let ui = vstack:
  spacing = 10
  Label(text: "Hello", fontSize: 16)
  Button(text: "Click", onClick: handleClick)
```

**Architecture benefits**:
- **Internal**: Testable, reusable render logic
- **Widget**: DSL keeps it clean and standard
- **App**: Simple, declarative

### File Structure
```
widgets/
  basic/
    label_internal.nim       # Logic
    label.nim                # DSL wrapper
    button_internal.nim      # Logic
    button.nim               # DSL wrapper
  containers/
    vstack_internal.nim      # Layout logic
    vstack.nim               # DSL wrapper
```

## 5. Theme Access - Global App Context

**Rule**: Theme is globally accessible, not passed around.

### Global App Reference
```nim
# core/app_context.nim
var currentApp*: App = nil  # Set during app.run()

proc getTheme*(): Theme =
  ## Get current theme from global app context
  if currentApp != nil:
    return currentApp.currentTheme
  else:
    return defaultTheme()

proc setTheme*(theme: Theme) =
  ## Change global theme
  if currentApp != nil:
    currentApp.currentTheme = theme
    currentApp.markDirty()  # Re-render everything
```

### Widget Usage
```nim
definePrimitive(Button):
  render:
    # Simple access
    let theme = getTheme()
    let props = theme.getProps(widget.intent, widget.state)

    drawRoundedRect(widget.bounds, props.cornerRadius, props.backgroundColor)
    drawText(widget.text, widget.bounds, props.foregroundColor)
```

**No theme prop drilling** - widgets just call `getTheme()`.

### Theme Changes
```nim
# In app
proc switchTheme() =
  if getTheme().name == "light":
    setTheme(darkTheme)
  else:
    setTheme(lightTheme)

  # setTheme() automatically marks tree dirty
  # Next frame, everything re-renders with new theme
```

**Mental model**: Theme is ambient context, like a global setting. Changes trigger full re-render.

## 6. State Changes and Dirty Tracking

**Rule**: Link[T].set() marks widget dirty, triggers re-render.

### How It Works
```nim
# When state changes
widget.pressed.set(true)

# Internally:
proc set*[T](link: Link[T], value: T) =
  if link.value != value:
    link.value = value

    # Mark all subscribers dirty
    for widget in link.subscribers:
      widget.isDirty = true

    # Request frame
    app.requestRender()
```

### Render Loop
```nim
proc renderFrame(app: App) =
  # Only render if something is dirty
  if not app.tree.anyDirty:
    return

  # Walk tree, render dirty widgets
  app.tree.root.renderIfDirty()

method renderIfDirty(widget: Widget) =
  if widget.isDirty:
    widget.render()  # Render self
    widget.isDirty = false

  # Always check children (they might be dirty even if parent isn't)
  for child in widget.children:
    child.renderIfDirty()
```

**Mental model**:
1. State change → mark dirty
2. Next frame → render dirty widgets
3. Clean widgets are skipped

### Granular Updates
```nim
definePrimitive(Counter):
  state:
    count: int  # Link[int]

  render:
    # Only this widget re-renders when count changes
    drawText($widget.count.get(), ...)

# Parent not affected
defineWidget(App):
  layout:
    vstack:
      Label(text: "Static Header")  # Not re-rendered
      Counter()                      # Re-renders when count changes
      Label(text: "Static Footer")  # Not re-rendered
```

**Only dirty widgets re-render, not whole tree.**

## 7. Primitives with Layout Block (Hybrid)

**Rule**: Primitives can have BOTH `render:` and `layout:` blocks.

```nim
definePrimitive(Panel):
  props:
    cornerRadius: float = 8.0
    padding: EdgeInsets = EdgeInsets(all: 10)

  layout:
    # Panel has children - use layout block
    vstack:
      spacing = 8
      # Children added by caller:
      # panel.addChild(Label(...))
      # panel.addChild(Button(...))

  render:
    # Draw panel decorations
    let theme = getTheme()

    # Background (drawn first, under children)
    drawRoundedRect(widget.bounds, widget.cornerRadius, theme.surface)

    # Children render themselves here (automatic)

    # Border (drawn last, over children)
    drawBorder(widget.bounds, 2, theme.primary)
```

**Render order**:
1. `render:` block executes (draws background)
2. Children auto-render (macro inserts this)
3. `render:` block continues (draws border)

**Wait, this doesn't work!** The render block runs once, can't split before/after children.

### Solution 1: Separate render phases
```nim
definePrimitive(Panel):
  render_before:
    # Drawn before children
    drawBackground(...)

  render_after:
    # Drawn after children
    drawBorder(...)
```

### Solution 2: Manual child rendering
```nim
definePrimitive(Panel):
  render:
    # Background
    drawBackground(...)

    # Manually render children
    for child in widget.children:
      child.render()

    # Border
    drawBorder(...)
```

### Solution 3: Use ZStack (recommended)
```nim
defineWidget(Panel):
  layout:
    zstack:
      # Background layer
      PanelBackground(cornerRadius: widget.cornerRadius)

      # Content layer with padding
      Margin(insets: widget.padding):
        vstack:
          # Children

      # Border layer
      PanelBorder(cornerRadius: widget.cornerRadius)
```

**Decision needed**: Which approach for primitives with decorations?

## 8. Actions with Return Values

**Rule**: Actions are callbacks, can have return values.

```nim
actions:
  onClick()                    # void
  onValidate() -> bool         # returns bool
  onFilter(item: Item) -> bool # predicate
  onCompare(a, b: Item) -> int # comparator
```

**Generated**:
```nim
type Widget = ref object
  onClick: Option[proc()]
  onValidate: Option[proc(): bool]
  onFilter: Option[proc(item: Item): bool]
  onCompare: Option[proc(a, b: Item): int]
```

**Usage**:
```nim
if widget.onValidate.isSome:
  let valid = widget.onValidate.get()()
  if not valid:
    return
```

**Simple**: Actions are just typed callbacks, support any signature.

## Mental Model Summary

1. **Events**: Bubble up until handled (true) or reach root
2. **Binding**: One-way (state → widget), use actions for reverse
3. **Layout DSL**: Properties are assignments, Names() are constructors
4. **Code Organization**: internal.nim (logic) + DSL (structure)
5. **Theme**: Global `getTheme()`, no prop drilling
6. **Dirty Tracking**: Link.set() marks dirty, render only dirty widgets
7. **Hybrid Widgets**: Need decision on render before/after children
8. **Actions**: Typed callbacks, support return values

**Principle**: Keep it simple, explicit, and transparent.

## Open Question

**How do primitives draw decorations before AND after children?**

Options:
A) `render_before:` and `render_after:` blocks
B) Manual child rendering in `render:` block
C) Use ZStack composition instead
D) Don't support - use composition for decorations

**Recommendation**: Start with option C (ZStack), add A or B if truly needed.
