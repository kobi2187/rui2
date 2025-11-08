# RUI Quick Reference

**Fast reference for key concepts and patterns**

---

## Core Concepts

### Link[T] Reactive System

**Direct widget references for O(1) updates!**

```nim
# Definition
type Link[T] = ref object
  value: T
  dependentWidgets: HashSet[Widget]  # Direct refs, not IDs!

# Creation
let counter = newLink(0)

# Reading
echo counter.value  # → 0

# Writing (triggers updates)
counter.value = 42
# Automatically:
# 1. Marks all dependent widgets dirty
# 2. Re-renders them immediately (new texture)
# 3. Layout pass positions them next frame

# Binding in DSL
Label:
  text: bind <- store.counter  # Auto-registers in dependentWidgets
```

### Flutter-Style Layout

**Two-pass algorithm: Constraints down, Sizes up**

```nim
# Pass 1: Parent passes constraints to children
proc measure(widget, constraints) → Size

# Pass 2: Parent positions children based on sizes
proc layout(widget, position) → void
```

**Common Containers**:
- `VStack` - Vertical stack
- `HStack` - Horizontal stack
- `Grid` - Grid layout
- `Flex` - Flexible with grow/shrink
- `Dock` - Dock to edges
- `Overlay` - Layer widgets
- `Wrap` - Wrapping flow
- `Scroll` - Scrollable area

### Render-Before-Layout Pattern

**Content updates immediately, positioning on next frame**

```
Data change → Link notifies → Direct widget updates
                                      ↓
                         ┌────────────┴─────────────┐
                         ↓                          ↓
                  Mark isDirty=true      Call widget.render()
                                         (generate texture)
                         ↓                          ↓
                         └────────────┬─────────────┘
                                      ↓
                         Next frame: Layout pass
                         (calculate bounds/positions)
                                      ↓
                         Draw pass (blit textures)
```

### Manager System

**Separation of concerns**

- **RenderManager**: Texture caching, dirty tracking, render queue
- **LayoutManager**: Two-pass algorithm, tree traversal
- **EventManager**: Event coalescing, routing, patterns
- **FocusManager**: Tab order, keyboard navigation
- **TextInputManager**: IME support, editing state

### Event Patterns

**Smart event handling**

- `epNormal` - Process immediately
- `epReplaceable` - Only last matters (mouse move)
- `epDebounced` - Wait for quiet period (window resize)
- `epThrottled` - Rate limited (scroll)
- `epBatched` - Collect related (touch gestures)
- `epOrdered` - Sequence matters (key combos)

### Theme System

**Zero-cost theme switching**

```nim
# Lookup: ThemeState × ThemeIntent → ThemeProps
let props = getTheme(widget, Normal, Default)

# Instant switching (just pointer assignment)
app.currentTheme = darkTheme
```

---

## Code Patterns

### Basic App Structure

```nim
import rui

type MyStore = ref object of Store
  counter: Link[int]

let app = newApp()
app.store = MyStore(counter: newLink(0))

app.tree = buildUI:
  VStack:
    spacing: 16
    children:
      - Label: text: bind <- store.counter
      - Button:
          text: "Increment"
          onClick: proc() = store.counter.value += 1

app.start()
```

### Custom Widget

```nim
defineWidget MyWidget:
  props:
    title: string
    count: int

  render:
    let theme = getTheme(widget, Normal, Default)
    drawCard(widget.bounds, theme.backgroundColor)
    drawText(widget.title, widget.bounds, theme.textColor)
```

### Layout Example

```nim
VStack:
  spacing: 16
  padding: 24
  align: center
  children:
    - Label: "Title"
    - HStack:
        spacing: 8
        children:
          - Button: "Cancel"
          - Button: "OK"
```

---

## File Organization

```
rui/
├── core/               # Core types and infrastructure
├── managers/           # System coordination
├── drawing_primitives/ # Low-level rendering
├── text/               # Pango integration
├── widgets/            # UI components
├── layout/             # Layout containers
├── dsl/                # Macros
├── hit-testing/        # Spatial queries
├── examples/           # Example apps
└── rui.nim            # Main export
```

---

## Performance Targets

- **UI Latency**: < 1ms for simple interactions
- **Frame Rate**: 60 FPS with moderate complexity
- **Memory**: < 50MB for typical apps
- **Startup**: < 100ms to first render
- **Layout**: < 5ms for 1000 widgets
- **Theme Switch**: < 1ms (just pointer)

---

## Current Status (v0.1)

✅ **Complete**:
- Drawing primitives (1,292 lines)
- Widget library (3,242 lines)
- Hit testing system
- Theme system
- Main loop
- **Documentation (100%)**

🚧 **In Progress**:
- Link[T] reactive system
- Pango integration
- Layout manager
- Event routing
- Focus management

---

## Key Files

- **VISION.md** - Philosophy and roadmap
- **ARCHITECTURE.md** - Technical details
- **PROJECT_STATUS.md** - Component status
- **PROGRESS_LOG.md** - Work log
- **README.md** - User introduction
- **SESSION_SUMMARY.md** - Session recap

---

## Implementation Order

1. ✅ Documentation
2. Type consolidation
3. Link[T] system ← **START HERE**
4. Pango integration
5. Layout manager
6. Render manager
7. Event routing
8. Widget updates
9. buildUI expansion
10. Focus management
11. Examples
12. Tests

---

**Quick Tip**: When in doubt, check ARCHITECTURE.md for detailed explanations!
