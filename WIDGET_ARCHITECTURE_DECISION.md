# Widget Architecture: OOP vs Variants vs Composition

## The Core Question

**How should widgets be represented to enable user-defined custom widgets?**

You're absolutely right - hardcoding widget types doesn't work if users need to create their own widgets using drawing primitives.

## Three Approaches

### Approach 1: Object-Oriented (Methods)

```nim
type
  Widget* = ref object of RootObj
    id: WidgetId
    bounds: Rect
    children: seq[Widget]
    # ... common fields

  Button* = ref object of Widget
    text: string
    onClick: proc()

  CustomGauge* = ref object of Widget  # User-defined!
    value: float
    maxValue: float

# Methods for polymorphism
method render*(w: Widget, ctx: RenderContext) {.base.} =
  discard

method render*(b: Button, ctx: RenderContext) =
  drawRoundedRect(b.bounds, 4.0, BLUE)
  drawText(b.text, ...)

method render*(g: CustomGauge, ctx: RenderContext) =
  # User draws their custom gauge
  drawCircle(...)
  drawArc(...)
```

**Pros**:
- ✅ Natural OOP polymorphism
- ✅ Users can subclass `Widget`
- ✅ Type-safe - compiler knows widget types
- ✅ Can mix built-in and custom widgets freely

**Cons**:
- ❌ Method dispatch overhead (vtable lookup)
- ❌ Harder to serialize widget trees
- ❌ Can't easily pattern match on widget type
- ❌ Runtime type checks need `of` operator

### Approach 2: Enum Variants (What I did)

```nim
type
  WidgetKind = enum
    wkButton, wkLabel, wkCustom

  Widget* = ref object
    kind: WidgetKind
    bounds: Rect
    case kind:
    of wkButton:
      buttonText: string
      onClick: proc()
    of wkLabel:
      labelText: string
    of wkCustom:
      customData: pointer  # ???

# Rendering is a big case statement
proc render(w: Widget) =
  case w.kind:
  of wkButton: drawButton(w)
  of wkLabel: drawLabel(w)
  of wkCustom: ??? # How do users extend this?
```

**Pros**:
- ✅ Fast dispatch (no vtable)
- ✅ Easy to serialize
- ✅ Pattern matching

**Cons**:
- ❌ **Can't extend with user types!** (Fatal flaw)
- ❌ Hardcoded widget types
- ❌ Variant fields get messy with many types

**Verdict**: ❌ **Doesn't meet requirements** - users can't add new widget types

### Approach 3: Composition with Render Callback

```nim
type
  Widget* = ref object
    id: WidgetId
    bounds: Rect
    children: seq[Widget]

    # Behavior as data
    onRender*: proc(w: Widget)
    onMeasure*: proc(w: Widget, constraints: Constraints): Size
    onLayout*: proc(w: Widget)
    onInput*: proc(w: Widget, event: Event): bool

    # User data
    userData*: pointer  # Or use a table
    properties*: Table[string, Value]  # Dynamic properties

# Built-in button
proc newButton*(text: string): Widget =
  result = Widget(...)
  result.userData = cast[pointer](ButtonData(text: text))
  result.onRender = proc(w: Widget) =
    let data = cast[ButtonData](w.userData)
    drawRoundedRect(w.bounds, 4.0, BLUE)
    drawText(data.text, ...)

# User-defined gauge
proc newGauge*(value, maxValue: float): Widget =
  result = Widget(...)
  result.userData = cast[pointer](GaugeData(value: value, max: maxValue))
  result.onRender = proc(w: Widget) =
    let data = cast[GaugeData](w.userData)
    drawCircle(...)
    drawArc(angle = data.value / data.max * 360, ...)
```

**Pros**:
- ✅ **Fully extensible** - users create any widget
- ✅ No inheritance needed
- ✅ Can still type-check callbacks
- ✅ Fast (direct proc call, no vtable)

**Cons**:
- ❌ Lose type safety on userData (needs casting)
- ❌ More verbose to create widgets
- ❌ Harder to debug (callbacks are opaque)

### Approach 4: Macro-Based defineWidget (Best of Both Worlds!)

This is what you already have in `enhanced_widget.nim`:

```nim
defineWidget(CustomGauge):
  props:
    value: float
    maxValue: float
    color: Color

  init:
    widget.color = GREEN

  render:
    # User can use drawing_primitives directly!
    let angle = (widget.value / widget.maxValue) * 360
    drawCircle(widget.bounds.centerX, widget.bounds.centerY, 50, GRAY)
    drawArc(widget.bounds.centerX, widget.bounds.centerY, 50, 0, angle, widget.color)
    drawText($widget.value, ...)

  layout:
    # Optional custom layout
    for child in widget.children:
      child.measure()

  input:
    if isMouseButtonPressed(MouseButton.Left):
      if containsPoint(widget.bounds, getMousePosition()):
        widget.value = min(widget.value + 10, widget.maxValue)
```

This expands to:

```nim
type CustomGauge* = ref object of Widget
  value: float
  maxValue: float
  color: Color

proc newCustomGauge*(): CustomGauge = ...
method render*(widget: CustomGauge) = ...  # User's code
method layout*(widget: CustomGauge) = ...  # User's code
method handleInput*(widget: CustomGauge) = ...  # User's code
```

**Pros**:
- ✅ **Type-safe** - real types, not variants
- ✅ **Fully extensible** - users define new widgets easily
- ✅ **Clean syntax** - declarative sections
- ✅ **Uses methods** - standard OOP dispatch
- ✅ **Direct access to drawing_primitives**
- ✅ Can compose with other widgets
- ✅ Nim compiler optimizations apply

**Cons**:
- ⚠️ Requires understanding macros (but users don't write them)
- ⚠️ Method dispatch overhead (minimal in practice)

## Recommendation: Approach 4 (Macro + OOP Methods)

**Use the `defineWidget` macro approach you already have!**

### Architecture:

```nim
# core/types.nim - Base widget
type
  Widget* = ref object of RootObj
    id*: WidgetId
    stringId*: string
    bounds*: Rect
    previousBounds*: Rect
    visible*, enabled*: bool
    hovered*, pressed*, focused*: bool
    parent*: Widget
    children*: seq[Widget]
    # ... common fields

# Methods that can be overridden
method render*(w: Widget) {.base.} =
  discard  # Base does nothing

method measure*(w: Widget, constraints: Constraints): Size {.base.} =
  # Default implementation
  result = Size(width: w.bounds.width, height: w.bounds.height)

method layout*(w: Widget) {.base.} =
  # Default: layout children
  for child in w.children:
    child.layout()

method handleInput*(w: Widget, event: Event): bool {.base.} =
  # Default: propagate to children
  for child in w.children:
    if child.handleInput(event):
      return true
  return false
```

### Built-in widgets (`widgets/button.nim`):

```nim
import ../core/[types, widget_dsl]
import ../drawing_primitives/drawing_primitives

defineWidget(Button):
  props:
    text: string
    backgroundColor: Color
    textColor: Color
    onClick: proc()

  init:
    widget.backgroundColor = Color(r: 70, g: 130, b: 180, a: 255)
    widget.textColor = WHITE
    widget.bounds.width = 100
    widget.bounds.height = 40

  render:
    # Use drawing primitives
    var bgColor = widget.backgroundColor
    if widget.pressed:
      bgColor = darken(bgColor, 0.2)
    elif widget.hovered:
      bgColor = lighten(bgColor, 0.1)

    drawRoundedRect(widget.bounds, 4.0, bgColor, filled = true)

    let textWidth = measureText(widget.text, 18)
    let textX = widget.bounds.x + (widget.bounds.width - textWidth) / 2
    let textY = widget.bounds.y + (widget.bounds.height - 18) / 2
    drawText(widget.text, textX, textY, 18, widget.textColor)

  input:
    if isMouseButtonPressed(MouseButton.Left):
      if widget.bounds.contains(getMousePosition()):
        if widget.onClick != nil:
          widget.onClick()
        return true
    return false
```

### User-defined widgets:

```nim
# user_widgets/progress_ring.nim
import rui/[core, drawing_primitives]

defineWidget(ProgressRing):
  props:
    progress: float  # 0.0 to 1.0
    radius: float
    thickness: float
    color: Color

  init:
    widget.radius = 50
    widget.thickness = 10
    widget.color = GREEN
    widget.bounds = newRect(0, 0, widget.radius * 2, widget.radius * 2)

  render:
    let centerX = widget.bounds.x + widget.radius
    let centerY = widget.bounds.y + widget.radius
    let angle = widget.progress * 360

    # Background circle
    drawCircle(centerX, centerY, widget.radius, Color(r: 200, g: 200, b: 200, a: 100))

    # Progress arc
    drawArc(centerX, centerY, widget.radius, 0, angle, widget.thickness, widget.color)

    # Center text
    let text = $(int(widget.progress * 100)) & "%"
    let textWidth = measureText(text, 24)
    drawText(text, centerX - textWidth/2, centerY - 12, 24, BLACK)

  measure:
    result = Size(width: widget.radius * 2, height: widget.radius * 2)
```

### Using widgets:

```nim
# User code
let myButton = newButton()
myButton.text = "Click Me"
myButton.onClick = proc() =
  echo "Clicked!"

let myRing = newProgressRing()
myRing.progress = 0.75
myRing.color = BLUE

let panel = newVStack()
panel.addChild(myButton)
panel.addChild(myRing)
```

## Integration with Existing Code

You already have:
- ✅ `drawing_primitives/` - All drawing functions
- ✅ `layout_containers.nim` - Layout helpers
- ✅ `layout_calcs.nim` - Measurement helpers
- ✅ `dsl/enhanced_widget.nim` - The `defineWidget` macro

**Action items**:
1. Move `enhanced_widget.nim` to `core/widget_dsl.nim`
2. Update the macro to work with new `Widget` base type
3. Create `widgets/` directory for built-in widgets
4. Each built-in widget gets its own file using `defineWidget`
5. Users can create custom widgets the same way

## Performance

**Method dispatch overhead**: ~2-5ns per call on modern CPUs
- With 60 FPS, rendering 1000 widgets = ~2-5μs overhead
- Totally negligible compared to actual drawing

**Memory**: Each widget is a ref object
- ~100-200 bytes per widget depending on fields
- 1000 widgets = ~100-200KB (tiny)

## Summary

✅ **Use OOP + Methods + defineWidget macro**

**Why**:
1. ✅ Users can create custom widgets easily
2. ✅ Type-safe - real Nim types
3. ✅ Direct access to drawing_primitives
4. ✅ Clean, declarative syntax
5. ✅ Can compose built-in widgets
6. ✅ Standard OOP patterns (familiar)
7. ✅ You already have the macro!

**Not**:
- ❌ Variants (can't extend)
- ❌ Composition with callbacks (loses type safety)
- ❌ Pure OOP without macro (too verbose)

The macro is just **syntax sugar** over standard OOP - best of both worlds!
