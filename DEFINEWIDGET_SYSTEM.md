# defineWidget System - From Hummingbird

Hummingbird's `defineWidget` macro is a powerful DSL for creating widgets. It's much more than just a syntax sugar - it enables composable, stateful widgets that can themselves be complete applications.

## Core Concept

A `defineWidget` can:
1. Define properties (props)
2. Manage internal state linked to Store
3. Handle input events
4. Render using other widgets or raw drawing
5. Be composed into larger widgets
6. **Act as a complete application**

## defineWidget Syntax

### Basic Structure

```nim
defineWidget WidgetName:
  props:
    # Public properties
    text: string
    onClick: proc()
    enabled: bool = true

  state:
    fields:
      # State managed by Store[T]
      text: string
      enabled: bool
      pressed: bool

  input:
    # Handle input events
    if event.kind == ieMousePress:
      widget.isPressed = true
      true  # Event handled
    else:
      false  # Event not handled

  render:
    # Draw the widget
    if GuiButton(widget.toRaylibRect(), widget.text):
      if widget.onClick != nil:
        widget.onClick()
```

### The Four Blocks

#### 1. `props:` Block
Defines public properties of the widget.
- Can have default values
- Can be callbacks (`proc()`)
- Can be complex types (`seq[T]`, `Option[T]`, custom objects)

```nim
props:
  text: string
  value: float = 0.0
  items: seq[string]
  onChange: proc(newValue: float)
  icon: Option[Icon]
```

#### 2. `state:` Block
Defines internal state connected to Store/Link system.
- Reactive: Changes propagate automatically
- Persistent: Can be saved/restored
- Linked: Multiple widgets can share state

```nim
state:
  fields:
    selectedIndex: int
    expanded: bool
    hovered: bool
    scrollOffset: float
```

#### 3. `input:` Block
Handles input events before rendering.
- Return `true` if event was handled
- Return `false` to let event propagate
- Access via `event` parameter

```nim
input:
  if event.kind == ieMousePress and widget.enabled:
    widget.isPressed = true
    true
  elif event.kind == ieMouseRelease:
    widget.isPressed = false
    if widget.containsPoint(event.mousePos):
      widget.onClick()
    true
  else:
    false
```

#### 4. `render:` Block
Draws the widget. Can use:
- Raygui functions (`GuiButton`, `GuiSlider`, etc.)
- Custom drawing (Raylib primitives)
- **Other widgets** (composition!)
- Layout containers (`vstack`, `hstack`)

```nim
render:
  # Option 1: Direct raygui
  GuiButton(widget.toRaylibRect(), widget.text)

  # Option 2: Compose other widgets
  vstack:
    Label(text: widget.title)
    Button(text: "Click me", onClick: widget.onClick)

  # Option 3: Mix both
  GuiGroupBox(widget.toRaylibRect(), widget.title)
  for child in widget.children:
    child.draw()
```

## Widget Composition

### Simple Composition

A widget can use other widgets in its render block:

```nim
defineWidget SettingsPanel:
  props:
    onSave: proc()
    onCancel: proc()

  render:
    vstack:
      spacing = 8

      Label(text: "Settings")
      Separator()

      Checkbox(
        text: "Enable feature",
        onToggle: proc(checked: bool) = echo checked
      )

      hstack:
        Button(text: "Save", onClick: widget.onSave)
        Button(text: "Cancel", onClick: widget.onCancel)
```

### Complex Composition with State

Widgets can manage complex hierarchies:

```nim
defineWidget TabControl:
  props:
    tabs: seq[string]
    onTabChanged: proc(newTab: int)

  state:
    fields:
      activeTab: int

  render:
    # Draw tab bar
    GuiTabBar(widget.toRaylibRect(), widget.tabs.join(";"), addr widget.activeTab)

    # Draw active tab content (child widget)
    if widget.activeTab < widget.children.len:
      widget.children[widget.activeTab].draw()
```

## Full Application Pattern

The most powerful feature: **A defineWidget can be an entire application**!

### Example: Multi-Tab Application

```nim
# Define custom widgets for each feature
defineWidget TimeSetter:
  props:
    state: TimeSyncState

  render:
    vstack:
      Label(text: "NTP Time Sync")
      TextInput(placeholder: "ntp.server.com")
      Button(text: "Sync", onClick: proc() = syncTime())

defineWidget AudioConverter:
  props:
    state: ConverterState

  render:
    vstack:
      FilePicker(onSelect: proc(file: string) = selectFile(file))
      ComboBox(items: @["MP3", "WAV", "FLAC"])
      ProgressBar(value: widget.state.progress.get())
      Button(text: "Convert", onClick: proc() = startConvert())

defineWidget TodoList:
  props:
    state: TodoState

  render:
    vstack:
      hstack:
        TextInput(placeholder: "New todo...")
        Button(text: "Add", onClick: proc() = addTodo())

      ListView(
        items: widget.state.todos.get(),
        onSelect: proc(idx: int) = selectTodo(idx)
      )

# Main application widget composes everything
defineWidget MainApp:
  props:
    state: AppState

  render:
    vstack:
      spacing = 0

      # Top bar with tabs
      Panel:
        height = 48
        TabBar:
          tabs = @["Time Sync", "Converter", "Todo"]
          onSelect = proc(idx: int) = widget.state.currentTab.set(idx)

      # Show active tab content
      case widget.state.currentTab.get()
      of 0: TimeSetter(state: widget.state.timeState)
      of 1: AudioConverter(state: widget.state.converterState)
      of 2: TodoList(state: widget.state.todoState)

# Run the app
proc main() =
  var state = AppState(
    currentTab: Store[int](value: 0),
    timeState: initTimeSyncState(),
    converterState: initConverterState(),
    todoState: initTodoState()
  )

  app.run:
    title = "Multi-Tool App"
    MainApp(state: state)
```

## Key Insights

### 1. Widgets are Components
Each widget is a self-contained component with:
- Props (public API)
- State (internal data)
- Input handling (event logic)
- Rendering (visual output)

### 2. Composition Over Inheritance
Build complex UIs by composing simple widgets:
```nim
Form = VStack[Label, TextInput, Button]
Dialog = Panel[Form, ButtonRow]
App = TabControl[Dialog, SettingsPanel, AboutScreen]
```

### 3. State Management Integration
The `state:` block connects to reactive stores:
- Changes propagate automatically
- Can be shared across widgets
- Enables undo/redo
- Supports persistence

### 4. Progressive Enhancement
Start simple, add complexity as needed:
1. Simple widget: Just props + render
2. Add interactivity: Add input block
3. Add state: Add state block
4. Compose into app: Use in other widgets

## Benefits for RUI2

Porting this system to RUI2 gives us:

1. **Rapid Widget Development** - Define widgets in ~20 lines
2. **Composability** - Build complex UIs from simple parts
3. **Reactivity** - State changes auto-update UI
4. **Reusability** - Widgets are self-contained modules
5. **Testability** - Each widget can be tested independently
6. **App-as-Widget** - Entire apps are just widgets

## Implementation Strategy for RUI2

### Phase 1: Basic defineWidget Macro
Create macro that generates:
- Widget type (ref object of Widget)
- Props as fields
- draw() method from render block

### Phase 2: Add State Support
- Integrate with RUI2's Link[T] system
- Generate reactive properties
- Auto-update on state changes

### Phase 3: Add Input Handling
- Integrate with event_manager
- Route events to input block
- Handle event propagation

### Phase 4: Enable Composition
- Support widget children
- Enable layout DSL (vstack, hstack)
- Make MainApp pattern work

## Next Steps

1. Implement basic defineWidget macro in RUI2
2. Port simple widgets (Button, Checkbox, Slider)
3. Add state/Link integration
4. Test composition with container widgets
5. Create example multi-widget application
6. Port remaining 35+ Hummingbird widgets

This system is the secret sauce that made Hummingbird powerful - it turns widget creation from tedious boilerplate into expressive, declarative code!
