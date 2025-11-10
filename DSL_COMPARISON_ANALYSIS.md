# DSL Comparison: Hummingbird vs RUI2

A deeper analysis of the trade-offs between the two widget DSL approaches.

## Side-by-Side Comparison

### Hummingbird's defineWidget

```nim
defineWidget Button:
  props:
    text: string
    onClick: proc()
    icon: Option[Icon]

  state:
    fields:
      text: string
      enabled: bool
      pressed: bool
      icon: Option[Icon]

  input:
    if event.kind == ieMousePress and widget.enabled:
      widget.isPressed = true
      true
    elif event.kind == ieMouseRelease and widget.isPressed:
      widget.isPressed = false
      if widget.containsPoint(event.mousePos):
        widget.onClick()
      true
    else:
      false

  render:
    if GuiButton(widget.toRaylibRect(), widget.text):
      if widget.enabled and widget.onClick != nil:
        widget.onClick()
```

### RUI2's defineWidget

```nim
defineWidget(Button):
  props:
    text: string
    onClick: proc()

  init:
    widget.text = ""

  input:
    if event.kind == evMouseUp:
      if widget.onClick != nil:
        widget.onClick()

  render:
    drawButton(widget.bounds, widget.text)

  measure:
    result = Size(width: 100, height: 30)

  layout:
    # Position children if any
    for child in widget.children:
      child.layout()

  on_click:
    if widget.onClick != nil:
      widget.onClick()
```

## Critical Differences

### 1. State Management

**Hummingbird**: Explicit `state:` block
```nim
state:
  fields:
    text: string
    enabled: bool
    pressed: bool
```

**What this enables**:
- Clear separation of props (input) vs state (internal)
- Automatic Link[T]/Store integration
- Props are immutable, state is reactive
- State can be shared across widgets
- State can be persisted/restored

**RUI2**: No `state:` block
- Everything goes in `props:`
- No distinction between input props and internal state
- No automatic reactivity
- Manual state management required

**Winner**: **Hummingbird** - State management is critical for reactive UIs

### 2. Input Handling

**Hummingbird**: Granular control with return values
```nim
input:
  if event.kind == ieMousePress:
    widget.isPressed = true
    true  # Event consumed
  else:
    false  # Event propagates
```

**RUI2**: Similar, but with YAML-UI helpers
```nim
input:
  if event.kind == evMouseUp:
    widget.onClick()

on_click:  # Convenience helper
  widget.onClick()
```

**Trade-off**:
- Hummingbird: More control, explicit event consumption
- RUI2: Convenience helpers for common patterns
- Both work, different styles

**Winner**: **Tie** - Both approaches valid

### 3. Layout System

**Hummingbird**: Implicit (uses rect)
```nim
render:
  GuiButton(widget.toRaylibRect(), widget.text)
  for child in widget.children:
    child.draw()
```

**RUI2**: Explicit `measure:` and `layout:` blocks
```nim
measure:
  result = Size(width: 100, height: 30)

layout:
  for child in widget.children:
    child.layout()
```

**Trade-off**:
- Hummingbird: Simpler, less boilerplate
- RUI2: More control over sizing and positioning
- Hummingbird relies on external layout system
- RUI2 widgets can define their own layout logic

**Winner**: **RUI2** - Better for complex layouts

### 4. Composition & Nesting

**Hummingbird**: Direct widget composition in render
```nim
render:
  vstack:
    Label(text: widget.title)
    Button(text: "Click", onClick: widget.onAction)
    Slider(value: widget.progress, onChange: widget.onProgress)
```

**RUI2**: Must manually manage children
```nim
render:
  drawBox(widget.bounds)
  for child in widget.children:
    child.render()
```

**What this enables in Hummingbird**:
- Declarative UI composition
- Widgets built from widgets
- App-as-widget pattern (entire app is one widget!)
- Layout DSL (vstack/hstack) integrated

**RUI2**:
- More imperative
- Manual child management
- No built-in composition DSL

**Winner**: **Hummingbird** - Composition is transformative

### 5. Initialization

**Hummingbird**: No separate init block
```nim
# Initialization happens in constructor or first render
```

**RUI2**: Explicit `init:` block
```nim
init:
  widget.text = ""
  widget.enabled = true
```

**Winner**: **RUI2** - Explicit is better than implicit

## Feature Matrix

| Feature | Hummingbird | RUI2 | Critical? |
|---------|-------------|------|-----------|
| Props definition | ✓ | ✓ | ✓✓✓ |
| State block | ✓ | ✗ | ✓✓✓ |
| Input handling | ✓ | ✓ | ✓✓✓ |
| Render block | ✓ | ✓ | ✓✓✓ |
| Init block | ✗ | ✓ | ✓ |
| Measure block | ✗ | ✓ | ✓✓ |
| Layout block | ✗ | ✓ | ✓✓ |
| YAML-UI events | ✗ | ✓ | ✓ |
| Widget composition | ✓ | ✗ | ✓✓✓ |
| Layout DSL (vstack/hstack) | ✓ | ✗ | ✓✓✓ |
| Declarative children | ✓ | ✗ | ✓✓✓ |
| App-as-widget | ✓ | ✗ | ✓✓ |

## The Real Difference: Paradigm

### Hummingbird's Vision
**Declarative, Reactive, Composable**

```nim
defineWidget TodoApp:
  props:
    state: AppState

  render:
    vstack:
      spacing = 8

      # Header
      hstack:
        TextInput(bind <-> state.newTodo)
        Button(text: "Add", onClick: addTodo)

      # List
      for todo in state.todos.get():
        TodoItem(todo: todo, onToggle: toggleTodo, onDelete: deleteTodo)

      # Footer
      Label(text: "Total: {state.todos.get().len}")
```

**Benefits**:
- Entire UI in one view
- Clear data flow
- Easy to reason about
- Changes propagate automatically

### RUI2's Current Approach
**Imperative, Manual, Granular**

```nim
defineWidget(TodoApp):
  props:
    todos: seq[Todo]

  init:
    widget.todos = @[]

  render:
    drawBox(widget.bounds)

    # Must manually position each element
    let headerY = widget.bounds.y + 10
    # Draw input at headerY
    # Draw button at headerY + 40

    var y = headerY + 80
    for todo in widget.todos:
      # Draw todo item at y
      y += 30

  input:
    # Must manually handle all interactions
    if clickedAddButton:
      addTodo()
```

**Benefits**:
- Full control
- No magic
- Performance tuning
- Can optimize anything

## Critical Missing Features in RUI2

### 1. State Block with Link[T] Integration
Without this:
- No automatic reactivity
- Manual prop passing
- State management is ad-hoc
- Can't share state across widgets

### 2. Widget Composition in Render
Without this:
- Can't build widgets from widgets
- No declarative child definition
- Manual child management
- More boilerplate

### 3. Layout DSL (vstack/hstack in render)
Without this:
- Manual layout calculations
- Verbose positioning code
- Error-prone
- Hard to maintain

## Recommendation

### Option A: Enhance RUI2's DSL (Add Missing Features)

Add to RUI2's defineWidget:
1. **state:** block with Link[T] integration
2. **Composition syntax** for render block
3. **Layout DSL** (vstack/hstack/grid)

Result: Best of both worlds

### Option B: Adopt Hummingbird's DSL

Use Hummingbird's approach:
1. Port defineWidget macro from Hummingbird
2. Keep RUI2's additions (measure, layout, init)
3. Merge the two approaches

Result: More work, but proven design

### Option C: Keep RUI2's DSL (Status Quo)

Accept limitations:
1. More verbose widgets
2. Manual state management
3. Imperative composition
4. Trade simplicity for control

Result: More work for widget authors

## My Analysis

**Hummingbird's DSL is superior for rapid development** because:
1. State management is built-in (huge!)
2. Widget composition is declarative (transformative!)
3. Less boilerplate (faster!)
4. App-as-widget pattern works (elegant!)

**RUI2's DSL is superior for control** because:
1. Explicit layout control (measure/layout blocks)
2. Clear initialization (init block)
3. YAML-UI integration (convenience)

**Best Path Forward**: **Option A - Enhance RUI2's DSL**

Keep RUI2's strengths, add Hummingbird's power:
- Add `state:` block → Link[T] fields
- Add composition syntax → widgets in render
- Add layout DSL → vstack/hstack helpers
- Keep `measure:`, `layout:`, `init:` blocks
- Keep YAML-UI event helpers

This gives us the complete feature set.

## Conclusion

**Your instinct is correct** - Hummingbird's DSL has features that are genuinely superior:
- State management (critical)
- Widget composition (transformative)
- Declarative children (productive)

RUI2's current DSL is more granular and explicit, which is good for control but requires more boilerplate.

**Recommended**: Enhance RUI2's defineWidget to include Hummingbird's composition and state features while keeping RUI2's layout system.
