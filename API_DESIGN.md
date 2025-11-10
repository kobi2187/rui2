# RUI2 API Design - Simple, Explicit, Non-Magic

## Philosophy

RUI2's API is designed to be:

1. **Simple** - Just `import rui` and start building
2. **Explicit** - All parts are visible and debuggable
3. **Non-magic** - No hidden global state or implicit behaviors
4. **Composable** - Regular Nim code, procs, and functions
5. **Transparent** - Widget trees are just data structures you can inspect

## Complete App Structure

```nim
import rui

# 1. Define store (reactive state)
type AppStore = object
  field1: Link[Type1]
  field2: Link[Type2]

var store = AppStore(...)

# 2. Build widget tree (returns Widget)
proc buildUI(): Widget =
  Container:
    Child1(...)
    Child2(...)

# 3. Create app and run
let app = newApp("Title", width, height)
app.setRootWidget(buildUI())
app.start()
```

## Core Concepts

### 1. Link[T] - Reactive State

```nim
# Create reactive state
let counter = newLink(0)

# Read value
let value = counter.get()

# Write value
counter.set(42)

# In store
type Store = object
  name: Link[string]
  age: Link[int]

var store = Store(
  name: newLink("Alice"),
  age: newLink(25)
)
```

### 2. Widget Tree - Explicit Data Structure

```nim
# Widget tree is just a proc returning Widget
proc buildUI(): Widget =
  VStack(spacing = 10):
    Label(text = "Hello")
    Button(text = "Click")

# You can store it, inspect it, modify it
let ui = buildUI()
echo "UI type: ", ui.typeName
echo "Children: ", ui.children.len

# Set it explicitly
app.setRootWidget(ui)
```

### 3. App Object - Not a Global Singleton

```nim
# App is just a regular object
let app = newApp("My App", 800, 600)

# Access its properties
echo app.currentTheme.name
app.printTextCacheStats()

# There is a global var for convenience
# but it's optional - you can pass app explicitly
```

### 4. Widget DSL - All Sections Explicit

```nim
definePrimitive(MyWidget):
  props:
    text: string
    # Properties go here

  state:
    discard  # Always present, even if empty

  actions:
    discard  # Always present, even if empty

  events:
    discard  # Always present, even if empty

  render:
    # Rendering code
    echo widget.text
```

This makes the structure clear and helps users learn the syntax.

## API Surface

### Core Module - `import rui`

**Types:**
- `Link[T]` - Reactive state primitive
- `Widget` - Base widget type
- `App` - Application object
- `Theme` - Theme definition
- `TextCache` - Text rendering cache

**Functions:**
- `newLink[T](value: T): Link[T]` - Create reactive state
- `newApp(title, width, height, ...): App` - Create app
- `app.setRootWidget(widget: Widget)` - Set root widget
- `app.start()` or `app.run()` - Start main loop

**Macros:**
- `definePrimitive(name, body)` - Define leaf widget
- `defineWidget(name, body)` - Define container widget

**Built-in Widgets:**
- Primitives: `Label`, `Button`, `Checkbox`, `Slider`, `ProgressBar`, ...
- Containers: `VStack`, `HStack`, `Panel`, `ScrollView`, ...

### Theme System

```nim
# Access current theme
let theme = app.currentTheme

# Change theme
app.setTheme(newTheme("Dark"))

# Theme properties
let color = theme.getThemeProps(Primary, Normal).backgroundColor
```

### Text Cache

```nim
# Automatically used by widgets
# Cache keys include ALL parameters

# Check stats
app.printTextCacheStats()

# Clear cache (e.g., when theme changes)
app.clearTextCache()
```

## Widget Lifecycle

```nim
# 1. Define widget
definePrimitive(MyWidget):
  # ... sections ...

# 2. Create instance
let w = newMyWidget(prop1 = value1, prop2 = value2)

# 3. Widget is added to tree
app.setRootWidget(w)

# 4. Main loop:
#    - Collect events
#    - Process events (calls widget.handleInput)
#    - Update layout (calls widget.updateLayout)
#    - Render (calls widget.render)
```

## Event Handling

```nim
definePrimitive(Button):
  # ...
  events:
    on_mouse_down:
      # Handle event
      if not widget.disabled:
        echo "Button pressed"
        return true  # Event consumed
      return false   # Event propagates

    on_mouse_up:
      if widget.onClick.isSome:
        widget.onClick.get()()
```

Events propagate from child to parent until consumed.

## Best Practices

### 1. Store Definition

```nim
# Good: Clear types, initialized
type AppStore = object
  username: Link[string]
  isLoggedIn: Link[bool]
  messages: Link[seq[string]]

var store = AppStore(
  username: newLink(""),
  isLoggedIn: newLink(false),
  messages: newLink(@[])
)

# Bad: Unclear, hard to track
var counter = newLink(0)
var name = newLink("")
# ... scattered variables
```

### 2. Widget Tree Builders

```nim
# Good: Returns Widget, composable
proc buildHeader(): Widget =
  HStack:
    Label(text = "My App")
    Button(text = "Menu")

proc buildUI(): Widget =
  VStack:
    buildHeader()
    buildContent()
    buildFooter()

# Bad: Side effects, no return value
proc buildUI() =
  let w = VStack()
  w.add(Label())  # Mutating
  # No return, can't inspect
```

### 3. Event Handlers

```nim
# Good: Named functions
proc handleLogin() =
  store.isLoggedIn.set(true)
  store.username.set("Alice")

Button(text = "Login", onClick = handleLogin)

# Also good: Inline lambda for simple cases
Button(
  text = "Close",
  onClick = proc() = app.shouldClose = true
)

# Bad: Complex logic in inline lambda
Button(
  text = "Submit",
  onClick = proc() =
    # 50 lines of complex logic...
    # Hard to test, hard to read
)
```

### 4. Separation of Concerns

**Widget file** (`mywidget.nim`):
```nim
# WHAT the widget does
definePrimitive(MyWidget):
  props:
    data: seq[string]

  events:
    on_mouse_down:
      processClick(widget, event)  # Call internal

  render:
    renderWidget(widget)  # Call internal
```

**Internal file** (`mywidget_internal.nim`):
```nim
# HOW it's implemented
proc processClick*(widget: MyWidget, event: GuiEvent) =
  # Complex click handling...

proc renderWidget*(widget: MyWidget) =
  # Complex rendering...
```

## Complete Example

```nim
import rui
import std/strformat

# 1. Store
type TodoStore = object
  items: Link[seq[string]]
  input: Link[string]

var store = TodoStore(
  items: newLink(@["Buy milk", "Write code"]),
  input: newLink("")
)

# 2. Helpers
proc addTodo() =
  let text = store.input.get()
  if text.len > 0:
    var items = store.items.get()
    items.add(text)
    store.items.set(items)
    store.input.set("")

proc buildTodoItem(text: string): Widget =
  HStack(spacing = 5):
    Checkbox()
    Label(text = text)

# 3. UI
proc buildUI(): Widget =
  VStack(spacing = 10):
    Label(text = "Todo List")

    # Input
    HStack(spacing = 5):
      TextInput(
        text = store.input.get(),
        onChange = proc(val: string) = store.input.set(val)
      )
      Button(text = "Add", onClick = addTodo)

    # List
    for item in store.items.get():
      buildTodoItem(item)

# 4. Main
let app = newApp("Todo App", 400, 600)
app.setRootWidget(buildUI())
app.start()
```

## Summary

RUI2's API is designed to be obvious and explicit:

- ✅ `import rui` - One import
- ✅ Define `store` - Visible state
- ✅ Build widget tree - Returns Widget
- ✅ Create `app` - Regular object
- ✅ `app.start()` - Explicit start

No magic, no hidden globals, no implicit behaviors. Just clean, composable Nim code.
