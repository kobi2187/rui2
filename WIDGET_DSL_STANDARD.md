# RUI2 Widget DSL Standard

**Version**: 2.0
**Status**: Design Decision
**Date**: 2025-11-10

This document defines the standard for creating widgets in RUI2 using two complementary DSL macros.

## Design Decision: Two DSL Macros

RUI2 will have **two distinct macros** for different widget types:

1. **`definePrimitive`** - For leaf widgets that draw themselves
2. **`defineWidget`** - For composite widgets that arrange other widgets

This separation clarifies intent and enables appropriate code generation for each pattern.

## Macro 1: definePrimitive

### Purpose
Define **leaf widgets** that draw themselves using drawing primitives.

### Characteristics
- No children (or children are decorative only)
- Draws using `drawing_primitives` module
- Handles its own input events
- Can have state (reactive properties)
- Examples: Button, Label, TextInput, Checkbox, Slider

### Syntax

```nim
definePrimitive(Button):
  props:
    text: string
    icon: Option[Image]
    disabled: bool = false

  state:
    pressed: bool
    hovered: bool

  actions:
    onClick()           # Arity 0
    onHover(entered: bool)  # Arity 1

  events:
    on_mouse_enter:
      widget.hovered = true
      if widget.onHover != nil:
        widget.onHover(true)

    on_mouse_leave:
      widget.hovered = false
      if widget.onHover != nil:
        widget.onHover(false)

    on_mouse_down:
      if not widget.disabled:
        widget.pressed = true

    on_mouse_up:
      if widget.pressed and not widget.disabled:
        widget.pressed = false
        if widget.onClick != nil:
          widget.onClick()

  render:
    # Get theme styling
    let theme = getTheme(widget)
    let state = if widget.disabled: wsDisabled
                elif widget.pressed: wsPressed
                elif widget.hovered: wsHovered
                else: wsNormal
    let props = theme.getProps(widget.intent, state)

    # Draw background
    drawRoundedRect(widget.bounds, props.cornerRadius, props.backgroundColor)

    # Draw icon if present
    if widget.icon.isSome:
      drawImage(widget.icon.get(), iconRect)

    # Draw text
    drawText(widget.text, textRect, props.foregroundColor, props.fontSize)

    # Draw border
    drawBorder(widget.bounds, props.borderWidth, props.borderColor)
```

### Blocks

#### `props:`
Public properties that can be set when creating the widget.
- Must specify type
- Can have default values
- Immutable from outside (set at creation)

#### `state:`
Internal reactive state using Link[T].
- Automatically wrapped in Link[T]
- Changes trigger re-render
- Not exposed in constructor
- Used for hover, pressed, focus, etc.

#### `actions:`
Callback signatures that the widget supports.
- Lists proc name and arity
- Format: `actionName(param1: Type, param2: Type)`
- Or just: `actionName(arity)` for generic params
- Generated as `Option[proc(params)]` fields
- Used in events block

#### `events:`
Event handlers that connect user interactions to state/actions.
- Standard events: `on_mouse_down`, `on_mouse_up`, `on_mouse_enter`, `on_mouse_leave`, `on_key_down`, etc.
- Access to `widget` and `event` objects
- Can modify state
- Can call actions
- Return `true` if handled, `false` to propagate

#### `render:`
Drawing code using primitives.
- Access to `widget` (contains props, state, bounds)
- Use `drawing_primitives` functions
- Apply theming via `getTheme()` and `getProps()`
- Draw children if any (rare for primitives)

### Auto-Generated

The macro generates:
- Widget type definition
- Constructor (`newButton()`) with props
- State Link[T] initialization
- Action proc fields (as Option[proc])
- Event routing to events block
- render() method
- **Automatic layout** - bounds set by parent

### No Measure/Layout
Primitives don't define their own measure/layout - this is handled automatically:
- **Measure**: Calculated from content (text size, icon size, padding)
- **Layout**: Positioned by parent container
- Widget just draws within its bounds

## Macro 2: defineWidget

### Purpose
Define **composite widgets** that arrange and compose other widgets.

### Characteristics
- Contains children (other primitives or widgets)
- Manages layout and spacing
- Delegates rendering to children
- Can have state
- Examples: VStack, HStack, Panel, TabControl, Dialog

### Syntax

```nim
defineWidget(SettingsPanel):
  props:
    settings: Settings
    onSave: proc()

  state:
    activeSection: int

  actions:
    onSave()
    onCancel()

  events:
    on_escape_key:
      if widget.onCancel != nil:
        widget.onCancel()

  layout:
    # Describe how to arrange children
    vstack:
      spacing = 16
      padding = EdgeInsets(all: 20)

      # Header section
      hstack:
        Label(text: "Settings", fontSize: 24)
        Spacer()
        Button(text: "Save", onClick: widget.onSave)

      Separator()

      # Form section
      FormRow:
        Label(text: "Username:")
        TextInput(value: widget.settings.username)

      FormRow:
        Label(text: "Theme:")
        ComboBox(items: @["Light", "Dark"], selected: widget.settings.theme)

      # Footer
      hstack:
        Button(text: "Cancel", onClick: widget.onCancel)
        Button(text: "Apply", onClick: widget.onSave)
```

### Blocks

#### `props:`
Same as definePrimitive.

#### `state:`
Same as definePrimitive.

#### `actions:`
Same as definePrimitive.

#### `events:`
Same as definePrimitive (but typically fewer, as children handle most events).

#### `layout:`
**Replaces render block**. Declaratively defines widget composition.
- Uses layout DSL (vstack, hstack, grid, etc.)
- Creates and positions children
- Sets spacing, padding, alignment
- Nests containers
- Children handle their own rendering

### Auto-Generated

The macro generates:
- Widget type definition
- Constructor
- State initialization
- Action fields
- Event routing
- **Automatic render()** - walks children and calls their render()
- **Automatic measure()** - aggregates children sizes
- **Automatic layout()** - positions children per layout rules

### Automatic Measure/Layout
Composite widgets get automatic measure/layout based on their layout block:
- **Measure**: Sum/max of children based on container type (vstack sums heights, hstack sums widths)
- **Layout**: Positions children according to spacing, padding, alignment rules

## The Button Example: Hybrid Pattern

A Button can be implemented as either primitive or composite:

### Option 1: Pure Primitive
```nim
definePrimitive(Button):
  props:
    text: string
    icon: Option[Image]

  render:
    # Draw everything directly
    drawRoundedRect(...)
    drawImage(...)
    drawText(...)
```

**Use when**: Simple button, custom rendering, performance critical

### Option 2: Composite Pattern
```nim
defineWidget(Button):
  props:
    text: string
    icon: Option[Image]

  layout:
    # Compose from primitives
    hstack:
      spacing = 8
      padding = EdgeInsets(all: 10)
      alignment = Center

      if widget.icon.isSome:
        Image(src: widget.icon.get())

      Label(text: widget.text)
```

**Use when**: Reusing existing primitives, standard layout, flexibility

### Option 3: Hybrid (Primitive with internal structure)
```nim
definePrimitive(Button):
  props:
    text: string
    icon: Option[Image]

  render:
    # Draw container
    drawRoundedRect(widget.bounds, bgColor)

    # Position and draw icon (if present)
    if widget.icon.isSome:
      let iconRect = Rect(x: bounds.x + 10, y: bounds.y + 5, w: 20, h: 20)
      drawImage(widget.icon.get(), iconRect)

    # Position and draw text
    let textRect = Rect(...)
    drawText(widget.text, textRect, textColor)
```

**Use when**: Custom container appearance, standard content, mixed approach

## The Actions Block Rationale

### Why Separate Actions?

Instead of:
```nim
props:
  onClick: proc()
  onHover: proc(entered: bool)
```

We use:
```nim
actions:
  onClick()
  onHover(entered: bool)

events:
  on_mouse_up:
    if widget.onClick != nil:
      widget.onClick()
```

### Benefits:

1. **Clear Contract** - Actions block documents the widget's API
2. **Type Safety** - Signatures are explicit
3. **Separation** - Props are data, actions are callbacks
4. **YAML-UI Compatible** - Matches `actions:` and `events:` separation
5. **Event Mapping** - Clear connection between low-level events and high-level actions
6. **Optional** - Generated as `Option[proc]` automatically

### Generated Code:

```nim
actions:
  onClick()
  onHover(entered: bool)
```

Becomes:
```nim
type Button = ref object of Widget
  # ... props ...
  onClick*: Option[proc()]
  onHover*: Option[proc(entered: bool)]
```

Constructor:
```nim
proc newButton*(text: string, onClick: proc() = nil, onHover: proc(entered: bool) = nil): Button =
  result.onClick = if onClick != nil: some(onClick) else: none(proc())
  result.onHover = if onHover != nil: some(onHover) else: none(proc(entered: bool))
```

## State Block Details

### Purpose
Internal reactive state that triggers re-renders when changed.

### Syntax
```nim
state:
  pressed: bool
  hovered: bool
  selectedIndex: int
  scrollOffset: float
```

### Generated Code
```nim
type Button = ref object of Widget
  # Props...
  pressed: Link[bool]
  hovered: Link[bool]
```

### Initialization
```nim
proc newButton*(...): Button =
  # ...
  result.pressed = newLink(false)
  result.hovered = newLink(false)
```

### Usage
```nim
# Get value
if widget.pressed.get():
  # ...

# Set value (triggers re-render)
widget.pressed.set(true)

# In render block, access directly
if widget.pressed:  # Automatic .get() in render context
  drawPressed()
```

## Complete Examples

### Example 1: Checkbox (Primitive)

```nim
definePrimitive(Checkbox):
  props:
    text: string
    checked: bool = false

  state:
    hovered: bool

  actions:
    onToggle(checked: bool)

  events:
    on_mouse_enter:
      widget.hovered = true

    on_mouse_leave:
      widget.hovered = false

    on_mouse_up:
      widget.checked = not widget.checked
      if widget.onToggle != nil:
        widget.onToggle(widget.checked)

  render:
    let theme = getTheme(widget)
    let boxSize = 20.0
    let boxRect = Rect(x: bounds.x, y: bounds.y, w: boxSize, h: boxSize)

    # Draw checkbox box
    let bgColor = if widget.hovered: theme.surfaceHover else: theme.surface
    drawRoundedRect(boxRect, 4.0, bgColor)
    drawBorder(boxRect, 2.0, theme.primary)

    # Draw checkmark if checked
    if widget.checked:
      drawCheckmark(boxRect, theme.primary)

    # Draw label text
    let textRect = Rect(x: bounds.x + boxSize + 8, y: bounds.y, w: bounds.w - boxSize - 8, h: boxSize)
    drawText(widget.text, textRect, theme.onSurface)
```

### Example 2: VStack (Composite)

```nim
defineWidget(VStack):
  props:
    spacing: float = 8.0
    padding: EdgeInsets = EdgeInsets()
    alignment: Alignment = Leading

  layout:
    # VStack-specific layout logic
    var y = widget.bounds.y + widget.padding.top

    for child in widget.children:
      # Position child
      child.bounds.y = y

      # Align child horizontally
      case widget.alignment:
      of Leading:
        child.bounds.x = widget.bounds.x + widget.padding.left
      of Center:
        child.bounds.x = widget.bounds.x + (widget.bounds.width - child.bounds.width) / 2
      of Trailing:
        child.bounds.x = widget.bounds.x + widget.bounds.width - child.bounds.width - widget.padding.right

      y += child.bounds.height + widget.spacing
```

### Example 3: Dialog (Composite using primitives)

```nim
defineWidget(Dialog):
  props:
    title: string
    message: string
    buttons: seq[string]
    onButton: proc(index: int)

  state:
    visible: bool

  actions:
    onButton(index: int)
    onClose()

  events:
    on_escape_key:
      widget.visible = false
      if widget.onClose != nil:
        widget.onClose()

  layout:
    # Modal overlay
    Panel:
      background = Color(r: 0, g: 0, b: 0, a: 128)
      width = fill
      height = fill

      # Dialog box
      Panel:
        width = 400
        height = auto
        center = true
        background = theme.surface
        cornerRadius = 8
        elevation = 4

        vstack:
          spacing = 16
          padding = EdgeInsets(all: 20)

          # Title
          Label(text: widget.title, fontSize: 20, weight: Bold)

          # Message
          Label(text: widget.message, wrap: true)

          # Buttons
          hstack:
            spacing = 8
            alignment = Right

            for i, buttonText in widget.buttons:
              Button(
                text: buttonText,
                onClick: proc() =
                  if widget.onButton != nil:
                    widget.onButton(i)
              )
```

## Implementation Priorities

### Phase 1: Core Macros
1. Implement `definePrimitive` macro
2. Implement `defineWidget` macro
3. Add `state:` block with Link[T]
4. Add `actions:` block generation
5. Add `events:` block routing

### Phase 2: Primitives
Port essential primitives:
- Label, Button, TextInput
- Checkbox, RadioButton
- Slider, ProgressBar

### Phase 3: Containers
Create layout widgets:
- VStack, HStack
- Grid, Panel
- ScrollView

### Phase 4: Composite Widgets
Build complex widgets:
- TabControl, Dialog
- DataGrid, TreeView

## Migration Strategy

### Existing Widgets
Existing widgets will be gradually migrated:
1. Mark old defineWidget as deprecated
2. Rewrite using new macros
3. Test compatibility
4. Update examples

### Compatibility
The new macros should:
- Generate same public API
- Work with existing theme system
- Integrate with event manager
- Support existing Link[T] system

## Advanced Patterns

### Z-Order Composition (Overlay Pattern)

For composite widgets that need decorative drawing (borders, backgrounds, shadows) combined with content:

**Use ZStack** - A special container that layers children on top of each other:

```nim
defineWidget(Panel):
  props:
    title: string
    cornerRadius: float = 8.0

  layout:
    zstack:  # Children drawn in order, later = on top
      # Layer 1: Background decoration (bottom)
      PanelBackground:
        cornerRadius = widget.cornerRadius
        shadow = true

      # Layer 2: Content (top, with margins so background shows)
      Margin:
        insets = EdgeInsets(all: 10)

        vstack:
          Label(text: widget.title)
          # ... other content

      # Layer 3: Border decoration (topmost)
      PanelBorder:
        cornerRadius = widget.cornerRadius
        borderWidth = 2
```

**How it works**:
- ZStack draws children in order (painter's algorithm)
- Each child occupies the same bounds
- Later children are transparent and have margins
- Background "shows through" the margins
- Creates layered visual effects

**Use cases**:
- Panels with borders and shadows
- Cards with backgrounds
- Windows with titlebars
- Overlays and modals

**Alternative approach** - Hybrid primitive:
```nim
definePrimitive(Panel):
  props:
    cornerRadius: float = 8.0

  layout:
    # Yes! Primitives can also use layout for children
    vstack:
      # Children positioned inside the panel
      # ...

  render:
    # Draw decorations FIRST (under children)
    drawShadow(widget.bounds)
    drawRoundedRect(widget.bounds, widget.cornerRadius, bgColor)

    # Children render themselves on top
    # (automatic after render block)

    # Draw border LAST (over children)
    drawBorder(widget.bounds, 2, borderColor)
```

**Rule**: Primitive's render block runs first, then children render, allowing decorations under and over content.

### State and Store Integration

#### State Declaration

State fields are widget-internal reactive properties:

```nim
definePrimitive(Button):
  state:
    pressed: bool    # Generates: pressed: Link[bool]
    hovered: bool    # Generates: hovered: Link[bool]
```

**Initialization**:
- Automatic: `widget.pressed = newLink(false)`
- No constructor parameters
- Internal to widget

#### Store Variables (External State)

For **shared state across widgets**, pass Store/Link from outside:

```nim
# App-level state
type AppState = object
  counter: Link[int]
  theme: Link[string]

var appState = AppState(
  counter: newLink(0),
  theme: newLink("dark")
)

# Pass to widgets as props
defineWidget(CounterDisplay):
  props:
    counter: Link[int]  # External state passed in

  layout:
    vstack:
      Label(text: "Count: " & $widget.counter.get())
      Button(
        text: "+1",
        onClick: proc() = widget.counter.set(widget.counter.get() + 1)
      )

# Usage
let display = newCounterDisplay(counter: appState.counter)
```

**Pattern**:
1. `state:` block = widget-internal (created automatically)
2. `props:` with `Link[T]` = external state (passed in constructor)

**When to use each**:
- **state:** for UI state (hover, pressed, expanded)
- **props: Link[T]** for shared app state (data, settings)

#### Constructor Generation

Props become constructor parameters automatically:

```nim
definePrimitive(Button):
  props:
    text: string
    icon: Option[Image] = none(Image)
    counter: Link[int]  # External state

  actions:
    onClick()

# Generated constructor:
proc newButton*(
  text: string,
  icon: Option[Image] = none(Image),
  counter: Link[int],
  onClick: proc() = nil
): Button
```

**Rules**:
- Props with defaults → optional params
- Props without defaults → required params
- Actions → optional callback params
- State → NOT in constructor (internal only)

#### Binding Pattern

For two-way binding with external state:

```nim
defineWidget(SettingsForm):
  props:
    settings: Settings  # Object with Link fields

  layout:
    vstack:
      # Bind to external state
      TextInput(
        value: widget.settings.username,  # Link[string]
        onChanged: proc(v: string) = widget.settings.username.set(v)
      )

      Checkbox(
        checked: widget.settings.darkMode,  # Link[bool]
        onToggle: proc(v: bool) = widget.settings.darkMode.set(v)
      )

# Settings type
type Settings = object
  username: Link[string]
  darkMode: Link[bool]

# Usage
var settings = Settings(
  username: newLink("user"),
  darkMode: newLink(false)
)

let form = newSettingsForm(settings: settings)

# Changes in form update settings
# Changes in settings update form (reactive)
```

#### State vs Props Summary

| Feature | `state:` block | `props: Link[T]` |
|---------|----------------|------------------|
| Ownership | Widget-internal | External (passed in) |
| Constructor | Not in params | In params |
| Initialization | Automatic | Caller provides |
| Scope | Single widget | Shared across widgets |
| Use case | UI state | App state |
| Example | `pressed`, `hovered` | `currentUser`, `settings` |

## Summary

**Two macros, one system**:
- `definePrimitive` for leaf widgets (draw themselves)
- `defineWidget` for composite widgets (arrange children)
- Both support state, actions, events
- Automatic measure/layout
- Clear separation of concerns
- Flexible composition
- **ZStack** for layered decorations
- **state:** for internal reactive state
- **props: Link[T]** for external shared state

This standard will be used for all RUI2 widgets going forward.
