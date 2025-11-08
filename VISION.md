# RUI Vision & Design Philosophy

## What is RUI?

**RUI** (Raylib UI) is a fast, lightweight, immediate-mode GUI framework for Nim, designed for building small-to-medium desktop applications with professional quality and minimal overhead.

Built on top of the Raylib game engine, RUI provides:
- **Sub-millisecond UI latency** - responsive, game-like performance
- **Minimal memory footprint** - suitable for resource-constrained environments
- **Professional text rendering** - full Unicode, BiDi, complex scripts via Pango/Cairo
- **Flutter-inspired layout** - familiar, intuitive layout primitives
- **Declarative DSL** - YAML-UI format for cross-platform UI descriptions
- **Zero-cost theme switching** - just a pointer change

## Core Philosophy

### 1. **Immediate Mode with Intelligence**

RUI follows immediate-mode principles but adds smart optimizations:
- Draw every frame OR use cached textures for unchanged widgets
- Dirty flags at widget, layout, and global levels
- Automatic texture caching with invalidation
- No complex retained-mode state management

```nim
# Immediate mode: redraw each frame
proc draw(widget: Widget) =
  if widget.isDirty or app.invalidateAll:
    # Render to texture cache
    widget.renderToTexture()
  # Draw cached texture
  drawTexture(widget.cachedTexture, widget.bounds)
```

### 2. **Reactive Data Binding**

Store-based reactivity with explicit tracking:
- `Link[T]` type tracks dependent widgets
- Widgets bind to data sources
- Automatic invalidation on data change
- Unidirectional data flow (Store → UI)

```nim
type MyStore = ref object of Store
  counter: Link[int]
  username: Link[string]

# In DSL
buildUI:
  Label:
    text: bind <- store.counter  # Auto-updates when counter changes
```

### 3. **Flutter-Style Layout**

Familiar, powerful layout system without constraint solvers:
- **Containers**: HStack, VStack, Grid, Flex, Dock, Overlay, Wrap, Scroll
- **Properties**: spacing, padding, alignment, justify, grow, shrink
- **Two-pass algorithm**: Constraints down, sizes up
- **Predictable**: Same mental model as Flutter

```nim
buildUI:
  VStack:
    spacing: 16
    padding: 24
    children:
      - Label: "Hello"
      - HStack:
          children:
            - Button: "Cancel"
            - Button: "OK"
```

### 4. **YAML-UI as the Canonical DSL**

RUI's Nim DSL mirrors the YAML-UI specification exactly:
- YAML-UI is the "source of truth" for syntax
- Same widget names, properties, and structure
- `.yui` files can generate RUI Nim code
- Enables cross-toolkit UI definitions

### 5. **Professional Text from Day One**

Integration with Pango/Cairo for production-quality text:
- Full Unicode support (all languages, all scripts)
- Bidirectional text (Hebrew, Arabic)
- Complex text shaping (Japanese, Thai, Devanagari)
- Multi-line text with proper wrapping
- Text selection, cursor positioning, hit testing
- Rendered to Raylib textures for fast display

### 6. **Separation of Concerns via Managers**

Clean architecture with specialized managers:
- **RenderManager**: Dirty tracking, texture caching, render queue
- **LayoutManager**: Size calculations, positioning, tree traversal
- **EventManager**: Event coalescing, routing, pattern handling
- **FocusManager**: Tab order, keyboard navigation
- **TextInputManager**: IME support, text editing state

Each manager has a clear responsibility and minimal coupling.

### 7. **Performance by Design**

Multiple layers of optimization:
- **Spatial indexing**: Interval trees for O(log n) hit testing
- **Event coalescing**: Debounce, throttle, batch related events
- **Texture caching**: Render once, draw many times
- **Dirty tracking**: Only recalculate what changed
- **Smart invalidation**: Propagate dirty flags efficiently

### 8. **Theme System with Zero Cost**

Themes are just data structures - switching is instant:
- `ThemeState` (Normal, Hovered, Pressed, Focused, etc.)
- `ThemeIntent` (Default, Info, Success, Warning, Danger)
- `ThemeProps` lookup: State × Intent → Visual properties
- Theme = pointer, switching = assignment
- Caching for repeated lookups

```nim
# Instant theme switching
app.currentTheme = darkTheme  # Just a pointer change!
```

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│                   Application                        │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────┐ │
│  │    Store     │  │  Widget Tree │  │   Theme   │ │
│  │  (User Data) │  │   (UI Def)   │  │  (Visual) │ │
│  └──────┬───────┘  └──────┬───────┘  └─────┬─────┘ │
│         │                 │                 │        │
│         │    ┌────────────┴─────────────────┘       │
│         │    │                                       │
│  ┌──────▼────▼──────────────────────────────────┐   │
│  │              Main Loop                       │   │
│  │  • Collect Events                            │   │
│  │  • Handle Events (→ EventManager)            │   │
│  │  • Update Layout (→ LayoutManager)           │   │
│  │  • Render UI (→ RenderManager)               │   │
│  └──────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘

Managers (Clean Separation):
┌──────────────────┐  ┌──────────────────┐  ┌─────────────────┐
│  EventManager    │  │  LayoutManager   │  │  RenderManager  │
│  • Hit Testing   │  │  • Measure Pass  │  │  • Dirty Track  │
│  • Routing       │  │  • Layout Pass   │  │  • Render Queue │
│  • Coalescing    │  │  • Position      │  │  • Tex Cache    │
└──────────────────┘  └──────────────────┘  └─────────────────┘

┌──────────────────┐  ┌──────────────────┐
│  FocusManager    │  │  TextInputMgr    │
│  • Tab Order     │  │  • IME Support   │
│  • Focus Chain   │  │  • Edit State    │
└──────────────────┘  └──────────────────┘

Drawing Layer:
┌──────────────────────────────────────────────────────┐
│  Drawing Primitives (1292 lines - COMPLETE)         │
│  • Shapes, Text, Controls, Decorative, Panels       │
└──────────────────────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────┐
│  Pango/Cairo → Raylib Texture (Professional Text)   │
└──────────────────────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────┐
│  Raylib (Game Engine - Fast OpenGL Rendering)       │
└──────────────────────────────────────────────────────┘
```

## Widget Lifecycle

1. **Construction** (via DSL or direct code)
   - Create widget objects
   - Set properties
   - Build parent-child relationships

2. **Validation** (optional)
   - Check widget tree integrity
   - Verify required properties
   - Detect cycles

3. **Initialization**
   - Assign WidgetIds
   - Register event handlers
   - Connect to Store via Links

4. **Layout** (two-pass, Flutter-style)
   - **Pass 1 (Constraints Down)**: Parent tells child available space
   - **Pass 2 (Sizes Up)**: Child reports actual size needed
   - **Position**: Parent positions children based on sizes

5. **Rendering** (each frame)
   - Check dirty flags
   - Render to texture cache if dirty
   - Draw cached texture to screen
   - Apply theme properties

6. **Event Handling**
   - Hit testing via interval trees
   - Route events to target widgets
   - Execute event handlers
   - Invalidate affected widgets

7. **Update** (reactive)
   - Store changes trigger Link notifications
   - Dependent widgets marked dirty
   - Layout recalculated if needed
   - Re-render on next frame

## API Examples

### Basic Application

```nim
import rui

type MyStore = ref object of Store
  counter: Link[int]

let store = MyStore(counter: newLink(0))

let ui = buildUI:
  VStack:
    spacing: 16
    padding: 24
    children:
      - Label:
          text: bind <- store.counter
          fontSize: 24
      - Button:
          text: "Increment"
          onClick: proc() = store.counter.value += 1

let app = newApp()
app.tree = ui
app.store = store
app.start()
```

### Custom Widget

```nim
defineWidget MyCard:
  props:
    title: string
    content: string
    icon: string

  render:
    let theme = getTheme(widget, Normal, Default)

    # Use drawing primitives
    drawCard(widget.bounds, theme.backgroundColor, theme.elevation)

    # Layout children manually or use containers
    let titleY = widget.bounds.y + 16
    drawText(widget.title, widget.bounds.x + 16, titleY, theme)
```

### Layout Example

```nim
buildUI:
  HStack:
    align: center
    justify: spaceBetween
    padding: 16
    children:
      - Label: "Settings"
      - HStack:
          spacing: 8
          children:
            - Button: "Cancel"
            - Button:
                text: "Save"
                theme: "button.primary"
```

### Theme Usage

```nim
# Define custom theme
let myTheme = Theme(
  states: {
    Normal: {
      Default: ThemeProps(
        backgroundColor: rgb(255, 255, 255),
        textColor: rgb(0, 0, 0),
        borderColor: rgb(200, 200, 200)
      )
    }
  }
)

# Switch theme instantly
app.currentTheme = myTheme
```

## Design Decisions & Rationale

### Why Immediate Mode?

**Pros**:
- Simpler mental model (no complex state management)
- Predictable behavior (redraw = current state)
- Easier debugging (state is obvious)
- Performance benefits with caching

**Cons**:
- CPU usage if naive (mitigated by dirty flags and caching)
- Not suitable for extremely complex UIs (but RUI targets small-to-medium apps)

**Decision**: Immediate mode with smart caching gives us simplicity AND performance.

### Why Flutter-Style Layout (not Constraints)?

**Rationale**:
- Constraint solvers add complexity and dependencies
- Flutter's layout is proven, well-understood
- Two-pass algorithm is simple and fast
- 99% of UIs don't need constraint solving
- Can add constraints later if truly needed

### Why Pango from Day One?

**Rationale**:
- Professional apps need professional text
- Hebrew, Arabic, Asian languages are not optional
- Raylib's basic text rendering is insufficient
- Better to build on solid foundation than retrofit
- Pango is mature, battle-tested

### Why Store/Link Reactivity?

**Rationale**:
- Manual invalidation is error-prone
- Reactivity enables clean separation (UI ↔ Data)
- Unidirectional flow is predictable
- Link tracking is explicit, debuggable
- Essential for modern UI development

### Why YAML-UI as DSL?

**Rationale**:
- Cross-toolkit compatibility
- Human-readable, designer-friendly
- Separate UI from logic
- Generate code or interpret at runtime
- Future: visual editors, hot reload

## Target Use Cases

RUI is designed for:
- **Desktop utilities** - settings panels, file managers, system tools
- **Developer tools** - editors, debuggers, profilers
- **Small business apps** - POS systems, inventory, forms
- **Educational software** - interactive tutorials, simulations
- **Indie games UI** - menus, HUDs, dialogs
- **Prototypes** - quick mockups with real functionality

RUI is NOT designed for:
- Web applications (use HTML/CSS/JS)
- Mobile apps (use native toolkits)
- Extremely complex UIs (use Qt, GTK)
- Massive data tables (thousands of rows)

## Performance Targets

- **UI Latency**: < 1ms for simple interactions
- **Frame Rate**: 60 FPS with moderate complexity
- **Memory**: < 50MB for typical application
- **Startup Time**: < 100ms to first render
- **Layout Calculation**: < 5ms for 1000 widgets
- **Theme Switch**: < 1ms (just pointer assignment)

## Roadmap

### v0.1 (First Release) - TARGET
- Core widgets: Button, Label, TextInput, Checkbox
- Layout: HStack, VStack, Grid
- Pango text rendering integration
- Theme system with light/dark themes
- Store/Link reactive binding (unidirectional)
- Event system with coalescing
- 5+ example applications
- Complete documentation

### v0.2 (Enhancement)
- More widgets: RadioButton, Slider, ProgressBar, ScrollView
- More layouts: Flex, Dock, Overlay, Wrap
- Focus management and keyboard navigation
- Bidirectional binding
- Animation system
- More themes

### v0.3 (Advanced)
- Complex widgets: List, Tree, Table
- Custom widget development guide
- Performance profiler
- YAML-UI code generator
- Plugin system

### v1.0 (Stable)
- Production-ready for all target use cases
- Comprehensive widget library
- Extensive documentation
- Large example applications
- Performance benchmarks
- Stable API

## Philosophy in Practice

**Keep It Simple**:
- Prefer clear code over clever code
- Optimize only when measured
- Document design decisions
- Avoid premature abstraction

**Make It Fast**:
- Profile first, optimize second
- Cache aggressively but invalidate correctly
- Use spatial structures for O(log n) operations
- Leverage Raylib's GPU acceleration

**Make It Right**:
- Professional text rendering (Pango)
- Proper event handling (coalescing, routing)
- Clean architecture (managers, separation)
- Comprehensive tests

**Make It Useful**:
- Focus on real use cases
- Complete examples for every feature
- Clear, extensive documentation
- Responsive to user needs

---

*RUI: Fast, lightweight, professional GUI for Nim*
