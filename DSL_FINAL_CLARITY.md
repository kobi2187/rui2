# DSL Final Clarity - The Simple Truth

## The Two Macros - Crystal Clear

### definePrimitive = Pure Drawing

**Purpose**: Widgets that render themselves using **drawing primitives** (drawRect, drawText, drawCircle, etc.)

**These are the ATOMS** - they don't compose other widgets, they just draw pixels.

**Examples**:
- Label - draws text
- Rectangle - draws a rectangle
- Circle - draws a circle
- Icon - draws an image
- Line - draws a line

**Pattern**:
```nim
definePrimitive(WidgetName):
  props:
    # Visual properties

  render:
    # Call drawing primitives
    drawSomething(...)
```

### defineWidget = Composition

**Purpose**: Widgets that **compose other widgets** (primitives or other composites)

**These build UIs** - they arrange children to create complex widgets.

**Examples**:
- Button - Rectangle + Label
- Slider - Rectangle (track) + Rectangle (fill) + Circle (thumb) + Label (value)
- Checkbox - Rectangle + Checkmark + Label
- Panel - Rectangle (background) + VStack (contents) + Rectangle (border)
- VStack - arranges children vertically
- HStack - arranges children horizontally

**Pattern**:
```nim
defineWidget(WidgetName):
  props:
    # Configuration

  layout:
    # Compose primitives + other widgets
    Container:
      Primitive1(...)
      Primitive2(...)
```

## The Complete Architecture

```
┌─────────────────────────────────────────┐
│         Application Layer               │
│  (User builds UI with widgets)          │
└─────────────────────────────────────────┘
                  │
                  │ uses
                  ↓
┌─────────────────────────────────────────┐
│      Composite Widgets Layer            │
│      (defineWidget macro)               │
│                                         │
│  Button, Slider, Checkbox, Panel,       │
│  VStack, HStack, ScrollView, etc.       │
│                                         │
│  These COMPOSE primitives together      │
└─────────────────────────────────────────┘
                  │
                  │ uses
                  ↓
┌─────────────────────────────────────────┐
│      Drawing Primitives Layer           │
│      (definePrimitive macro)            │
│                                         │
│  Label, Rectangle, Circle, Line,        │
│  Icon, etc.                             │
│                                         │
│  These DRAW using drawing_primitives    │
└─────────────────────────────────────────┘
                  │
                  │ uses
                  ↓
┌─────────────────────────────────────────┐
│      Drawing Primitives API             │
│      (drawing_primitives module)        │
│                                         │
│  drawRect, drawText, drawCircle,        │
│  drawLine, drawImage, etc.              │
│                                         │
│  Low-level rendering (Cairo/Pango)      │
└─────────────────────────────────────────┘
```

## Examples - The Elegant Way

### Layer 1: Drawing Primitives (Atoms)

```nim
definePrimitive(Label):
  props:
    text: string
    fontSize: float = 14.0
    color: Color = black

  render:
    drawText(widget.text, widget.bounds, widget.color, widget.fontSize)
```

```nim
definePrimitive(Rectangle):
  props:
    color: Color
    cornerRadius: float = 0.0

  render:
    drawRoundedRect(widget.bounds, widget.cornerRadius, widget.color)
```

```nim
definePrimitive(Circle):
  props:
    color: Color
    filled: bool = true

  render:
    if widget.filled:
      drawCircle(widget.bounds.center, widget.bounds.width/2, widget.color)
    else:
      drawCircleOutline(widget.bounds.center, widget.bounds.width/2, widget.color)
```

### Layer 2: Composite Widgets (Built from Atoms)

```nim
defineWidget(Button):
  props:
    text: string
    bgColor: Color = gray
    disabled: bool = false

  state:
    isPressed: bool
    isHovered: bool

  actions:
    onClick()

  events:
    on_mouse_down:
      widget.isPressed.set(true)

    on_mouse_up:
      widget.isPressed.set(false)
      if widget.onClick.isSome:
        widget.onClick.get()()

    on_mouse_move:
      # Check if mouse is over button
      widget.isHovered.set(isMouseOver(widget.bounds, event.mousePos))

  layout:
    zstack:
      # Background changes color based on state
      Rectangle(
        color: if widget.disabled: lightGray
               elif widget.isPressed.get(): darkGray
               elif widget.isHovered.get(): widget.bgColor.lighten(0.1)
               else: widget.bgColor,
        cornerRadius: 4.0
      )
      # Text on top
      Label(
        text: widget.text,
        color: if widget.disabled: gray else: white
      )
```

```nim
defineWidget(Slider):
  props:
    value: float
    minValue: float = 0.0
    maxValue: float = 100.0
    showLabel: bool = true

  state:
    isDragging: bool

  actions:
    onChange(newValue: float)

  events:
    on_mouse_down:
      widget.isDragging.set(true)

    on_mouse_up:
      widget.isDragging.set(false)

    on_mouse_move:
      if widget.isDragging.get():
        # Calculate new value from mouse position
        let newValue = calculateValueFromMouse(event.mousePos, widget.bounds)
        if widget.onChange.isSome:
          widget.onChange.get()(newValue)

  layout:
    zstack:
      # Track (background bar)
      Rectangle(
        color: lightGray,
        height: 4
      )

      # Fill (colored portion)
      Rectangle(
        color: blue,
        width: (widget.value / widget.maxValue) * widget.bounds.width,
        height: 4
      )

      # Thumb (draggable circle)
      Circle(
        color: white,
        x: (widget.value / widget.maxValue) * widget.bounds.width,
        radius: 10
      )

      # Value label (optional)
      if widget.showLabel:
        Label(
          text: $widget.value,
          y: -25
        )
```

```nim
defineWidget(Checkbox):
  props:
    label: string
    checked: bool = false

  state:
    isHovered: bool

  actions:
    onToggle(newState: bool)

  events:
    on_mouse_up:
      let newState = not widget.checked
      if widget.onToggle.isSome:
        widget.onToggle.get()(newState)

  layout:
    hstack:
      spacing = 8

      # Checkbox box
      zstack:
        Rectangle(
          color: if widget.checked: blue else: white,
          cornerRadius: 2.0,
          width: 20,
          height: 20
        )

        Rectangle(
          color: transparent,
          borderColor: gray,
          borderWidth: 1,
          cornerRadius: 2.0,
          width: 20,
          height: 20
        )

        if widget.checked:
          # Checkmark (could be Icon or custom primitive)
          Label(text: "✓", color: white)

      # Label text
      Label(text: widget.label)
```

## Container Widgets

Containers are also `defineWidget` - they arrange user-provided children:

```nim
defineWidget(VStack):
  props:
    spacing: float = 8.0
    alignment: Alignment = Leading

  layout:
    var y = widget.bounds.y
    for child in widget.children:
      child.bounds.x = widget.bounds.x
      child.bounds.y = y
      child.bounds.width = widget.bounds.width
      y += child.bounds.height + widget.spacing
```

```nim
defineWidget(HStack):
  props:
    spacing: float = 8.0

  layout:
    var x = widget.bounds.x
    for child in widget.children:
      child.bounds.x = x
      child.bounds.y = widget.bounds.y
      child.bounds.height = widget.bounds.height
      x += child.bounds.width + widget.spacing
```

## The Key Insight

**definePrimitive** = "I draw myself" (using drawing API)
**defineWidget** = "I arrange others" (composing widgets)

This matches **immediate mode GUI** philosophy:
- Low-level drawing calls for primitives
- High-level composition for complex widgets
- Clean separation of concerns

## Raylib Immediate Mode Style

Exactly! This matches Raylib's pattern:

**Raylib drawing primitives**:
```c
DrawText("Hello", 10, 10, 20, BLACK);
DrawRectangle(0, 0, 100, 50, RED);
DrawCircle(50, 50, 20, BLUE);
```

**Our drawing primitives**:
```nim
definePrimitive(Label):
  render:
    drawText(widget.text, widget.bounds, ...)

definePrimitive(Rectangle):
  render:
    drawRect(widget.bounds, widget.color)
```

**Raylib doesn't have built-in Button** - you compose it:
```c
DrawRectangle(x, y, w, h, GRAY);
DrawText("Click", x+10, y+10, 20, WHITE);
if (IsMouseButtonPressed(MOUSE_LEFT_BUTTON)) { ... }
```

**Our Button** - same composition, but declarative:
```nim
defineWidget(Button):
  layout:
    zstack:
      Rectangle(color: gray)
      Label(text: "Click")
  events:
    on_mouse_up: ...
```

## Summary

- **Primitives are dumb** - they just draw what you tell them
- **Widgets are smart** - they compose primitives into useful UI elements
- **No confusion** - if it calls `drawSomething()`, it's a primitive. If it uses other widgets, it's a composite.
- **Immediate mode spirit** - direct rendering, simple composition
- **Declarative convenience** - DSL handles the boilerplate

This is the elegant architecture you were looking for! 🎯
