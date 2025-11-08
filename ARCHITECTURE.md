# RUI Architecture

This document describes the technical architecture of the RUI framework, including module organization, data flow, algorithms, and implementation patterns.

## Table of Contents

1. [Module Structure](#module-structure)
2. [Core Types](#core-types)
3. [Manager System](#manager-system)
4. [Layout Algorithm](#layout-algorithm)
5. [Rendering Pipeline](#rendering-pipeline)
6. [Event System](#event-system)
7. [Reactive Data Binding](#reactive-data-binding)
8. [Theme System](#theme-system)
9. [Text Rendering](#text-rendering)
10. [Performance Optimizations](#performance-optimizations)
11. [Design Decisions](#design-decisions)

---

## Module Structure

```
rui/
├── core/                          # Core types and infrastructure
│   ├── types.nim                  # Basic types (WidgetId, Rect, etc.)
│   ├── widget.nim                 # Widget base class
│   ├── app.nim                    # App and Store base types
│   └── link.nim                   # Link[T] reactive system
│
├── managers/                      # System coordination
│   ├── managers.nim               # Central export point
│   ├── render_manager.nim         # Rendering and caching
│   ├── layout_manager.nim         # Layout calculations
│   ├── event_manager.nim          # Event handling and routing
│   ├── focus_manager.nim          # Focus and keyboard navigation
│   └── text_input_manager.nim     # Text editing state
│
├── drawing_primitives/            # Low-level rendering
│   ├── drawing_primitives.nim     # Shapes, controls, decorative
│   ├── layout_containers.nim      # Container implementations
│   ├── layout_calcs.nim           # Layout helper functions
│   └── theme_sys_core.nim         # Theme lookup and caching
│
├── text/                          # Text rendering subsystem
│   ├── pango_wrapper.nim          # Pango/Cairo integration
│   ├── text_layout.nim            # Text measurement and layout
│   └── text_cache.nim             # Text texture caching
│
├── widgets/                       # UI components
│   ├── button.nim                 # Button widget
│   ├── label.nim                  # Label widget
│   ├── input.nim                  # TextInput widget
│   ├── checkbox.nim               # Checkbox widget
│   ├── classical_widgets.nim      # Legacy widget implementations
│   └── [more widgets...]
│
├── layout/                        # Layout containers
│   ├── hstack.nim                 # Horizontal stack
│   ├── vstack.nim                 # Vertical stack
│   ├── grid.nim                   # Grid layout
│   ├── flex.nim                   # Flexible layout
│   └── [more layouts...]
│
├── dsl/                           # Declarative UI macros
│   ├── dsl.nim                    # buildUI macro
│   ├── enhanced_widget.nim        # defineWidget macro
│   └── yaml_ui_gen.nim            # YAML-UI code generator
│
├── hit-testing/                   # Spatial queries
│   ├── hittest_system.nim         # Main hit-testing API
│   └── interval_tree.nim          # Interval tree implementation
│
├── types/                         # Shared type definitions
│   ├── core.nim                   # Core types (working)
│   ├── happy_types.nim            # Happy path types
│   └── happy_common_types.nim     # Common helper types
│
├── examples/                      # Example applications
│   ├── counter.nim
│   ├── todo_list.nim
│   ├── form_example.nim
│   └── [more examples...]
│
├── rui.nim                        # Main export module
└── happy_rui.nim                  # Working baseline implementation
```

### Dependency Graph

```
           rui.nim (main export)
                 │
    ┌────────────┼────────────┐
    │            │            │
managers/    widgets/     layout/      dsl/
    │            │            │          │
    │            │            │          │
    └────────────┴────────────┴──────────┘
                 │
        drawing_primitives/
                 │
            ┌────┴────┐
            │         │
         text/     core/
            │         │
      pangolib   raylib
```

---

## Core Types

### Widget Base

```nim
type
  WidgetId* = distinct int

  Widget* = ref object of RootObj
    id*: WidgetId
    bounds*: Rect              # x, y, width, height
    visible*: bool
    enabled*: bool
    isDirty*: bool             # Needs redraw
    zIndex*: int               # Stacking order
    cachedTexture*: Texture2D  # Rendered texture
    parent*: Widget
    children*: seq[Widget]
```

### Container

```nim
type
  Container* = ref object of Widget
    # Layout properties
    spacing*: float32
    padding*: EdgeInsets
    alignment*: Alignment
    justify*: Justify
```

### App State

```nim
type
  App* = ref object
    window*: WindowConfig
    tree*: WidgetTree
    store*: Store
    currentTheme*: Theme

    # Global flags
    invalidateAll*: bool
    anyWidgetDirty*: bool
    layoutDirty*: bool

    # Managers
    renderManager*: RenderManager
    layoutManager*: LayoutManager
    eventManager*: EventManager
    focusManager*: FocusManager
    textInputManager*: TextInputManager

    # Caches
    dirtyWidgets*: HashSet[WidgetId]
    renderQueue*: seq[Widget]
```

### Store and Links

```nim
type
  Link*[T] = ref object
    value*: T
    dependentWidgets*: HashSet[Widget]  # Direct widget references for O(1) updates!
    onChange*: proc(oldVal, newVal: T)

  Store* = ref object of RootObj
    # User-defined fields with Link types
    # Example:
    # counter*: Link[int]
    # username*: Link[string]

# When value changes, Link can immediately:
# 1. Mark all dependent widgets dirty
# 2. Re-render them (generate new textures)
# 3. No tree traversal needed!
# 4. Layout pass positions them on next frame
```

---

## Manager System

Managers are specialized subsystems with clear responsibilities and minimal coupling.

### RenderManager

**Responsibility**: Coordinate rendering operations, manage texture caches, track dirty widgets.

```nim
type
  RenderOp* = object
    case kind*: RenderOpKind
    of ropRect: rectData*: RectRenderData
    of ropTexture: texData*: TextureRenderData
    of ropText: textData*: TextRenderData

  RenderManager* = ref object
    renderQueue*: seq[RenderOp]
    textureCache*: Table[WidgetId, Texture2D]
    dirtyWidgets*: HashSet[WidgetId]
    scissorStack*: seq[Rect]
```

**Key Operations**:
- `markDirty(widgetId)` - Mark widget for redraw
- `buildRenderQueue()` - Sort widgets by z-index
- `renderFrame()` - Execute render operations
- `cacheTexture(widgetId, texture)` - Store rendered texture
- `invalidateCache(widgetId)` - Force re-render

### LayoutManager

**Responsibility**: Calculate widget sizes and positions using Flutter-style two-pass algorithm.

```nim
type
  Constraints* = object
    minWidth*, maxWidth*: float32
    minHeight*, maxHeight*: float32

  LayoutManager* = ref object
    needsLayout*: bool
    layoutQueue*: seq[Widget]
```

**Key Operations**:
- `measureWidget(widget, constraints)` → Size
- `layoutWidget(widget, position)` - Assign final position
- `propagateDirtyLayout(widget)` - Mark subtree for relayout
- `performLayout()` - Execute two-pass algorithm

**Two-Pass Algorithm**:
1. **Pass 1 (Constraints Down)**:
   - Parent calculates available space
   - Passes constraints to children
   - Children measure themselves

2. **Pass 2 (Sizes Up)**:
   - Children report actual size needed
   - Parent positions children based on sizes
   - Positions propagate down

### EventManager

**Responsibility**: Handle events, route to widgets, apply event patterns (debounce, throttle, etc.).

```nim
type
  EventPattern* = enum
    epNormal       # Process immediately
    epReplaceable  # Only last matters (mouse move)
    epDebounced    # Wait for quiet period (resize)
    epThrottled    # Rate limited (scroll)
    epBatched      # Collect related (touch gestures)
    epOrdered      # Sequence matters (key combos)

  EventManager* = ref object
    eventQueue*: seq[Event]
    eventConfig*: Table[EventKind, EventPattern]
    lastEventTime*: Table[EventKind, float]
```

**Key Operations**:
- `collectEvents()` - Gather events from Raylib
- `coalesceEvents()` - Apply event patterns
- `routeEvent(event, widget)` - Route to target
- `handleEvent(event)` - Execute handlers

### FocusManager

**Responsibility**: Manage keyboard focus, tab order, focus chains.

```nim
type
  FocusManager* = ref object
    focusedWidget*: WidgetId
    focusChain*: seq[WidgetId]
    modalWidget*: Option[WidgetId]
```

**Key Operations**:
- `setFocus(widgetId)` - Focus widget
- `nextFocus()` - Tab to next
- `prevFocus()` - Shift+Tab to previous
- `buildFocusChain()` - Calculate tab order

### TextInputManager

**Responsibility**: Handle IME, text editing state, composition.

```nim
type
  TextInputManager* = ref object
    activeInput*: Option[WidgetId]
    compositionText*: string
    compositionRange*: Range
```

---

## Layout Algorithm

RUI uses Flutter's proven two-pass layout algorithm.

### Constraints

Every widget receives constraints from its parent:

```nim
type Constraints = object
  minWidth, maxWidth: float32
  minHeight, maxHeight: float32
```

Examples:
- **Tight**: `minWidth == maxWidth` (widget must be exact size)
- **Loose**: `minWidth < maxWidth` (widget can choose)
- **Unbounded**: `maxWidth == Inf` (widget determines size)

### Measurement (Pass 1)

Parent passes constraints down, children measure themselves:

```nim
proc measure(widget: Widget, constraints: Constraints): Size =
  # Widget calculates its size given constraints
  case widget.kind:
  of wkLabel:
    # Measure text, respect constraints
    let textSize = measureText(widget.text)
    return Size(
      width: clamp(textSize.width, constraints.minWidth, constraints.maxWidth),
      height: clamp(textSize.height, constraints.minHeight, constraints.maxHeight)
    )

  of wkContainer:
    # Measure children first
    var totalHeight = 0.0
    for child in widget.children:
      let childSize = child.measure(childConstraints)
      totalHeight += childSize.height

    return Size(width: constraints.maxWidth, height: totalHeight)
```

### Layout (Pass 2)

Parent positions children based on their measured sizes:

```nim
proc layout(widget: Widget, position: Point) =
  widget.bounds.x = position.x
  widget.bounds.y = position.y

  case widget.kind:
  of wkVStack:
    var currentY = position.y + widget.padding.top
    for child in widget.children:
      child.layout(Point(x: position.x, y: currentY))
      currentY += child.bounds.height + widget.spacing

  of wkHStack:
    var currentX = position.x + widget.padding.left
    for child in widget.children:
      child.layout(Point(x: currentX, y: position.y))
      currentX += child.bounds.width + widget.spacing
```

### Container Implementations

**VStack** (Vertical):
- Measures each child with full width, unbounded height
- Sums heights + spacing
- Positions children vertically with spacing

**HStack** (Horizontal):
- Measures each child with unbounded width, full height
- Sums widths + spacing
- Positions children horizontally with spacing

**Grid**:
- Divides available space into rows/columns
- Each cell gets constraints from grid dimensions
- Positions cells in grid positions

**Flex**:
- Like HStack/VStack but respects `grow` and `shrink` factors
- Distributes extra space proportionally
- Shrinks widgets if necessary

---

## Rendering Pipeline

### Frame Cycle

```
1. collectEvents()        # Gather input from Raylib
2. handleEvents()         # Route events, execute handlers
3. updateLayout()         # Recalculate if layoutDirty
4. renderFrame()          # Draw to screen
```

### Rendering Flow

```
renderFrame():
  1. Check global invalidateAll flag
  2. Build render queue (sort by z-index)
  3. For each widget in queue:
     - If isDirty or invalidateAll:
       a. Render to texture
       b. Cache texture
       c. Clear isDirty flag
     - Draw cached texture to screen
  4. Reset invalidateAll flag
```

### Texture Caching

Each widget can cache its rendered content:

```nim
proc renderWidget(widget: Widget) =
  if widget.isDirty or app.invalidateAll:
    # Render to texture
    let renderTarget = createRenderTexture(widget.bounds.width, widget.bounds.height)
    beginRenderTexture(renderTarget)
    # Draw widget content
    widget.draw()
    endRenderTexture()

    # Cache texture
    widget.cachedTexture = renderTarget.texture
    widget.isDirty = false

  # Draw cached texture
  drawTexture(widget.cachedTexture, widget.bounds.x, widget.bounds.y)
```

### Drawing Primitives

Widgets use drawing_primitives for consistent rendering:

```nim
proc draw(button: Button) =
  let theme = getTheme(button.state, button.intent)

  # Use primitives
  drawRoundedRect(button.bounds, theme.backgroundColor, theme.borderRadius)
  drawText(button.text, button.bounds.center(), theme.textColor)

  if button.focused:
    drawFocusRing(button.bounds)
```

---

## Event System

### Event Flow

```
1. Raylib generates events (mouse, keyboard, etc.)
2. collectEvents() gathers into event queue
3. coalesceEvents() applies patterns (debounce, throttle)
4. Hit testing finds target widget(s)
5. routeEvent() delivers to widget
6. Widget handler executes
7. Handler may invalidate widgets
```

### Hit Testing

Uses dual interval trees for O(log n) queries:

```nim
proc findWidgetAt(x, y: float): seq[Widget] =
  # Query X interval tree
  let candidatesX = xTree.query(x)

  # Query Y interval tree
  let candidatesY = yTree.query(y)

  # Intersection = widgets containing point
  let widgets = candidatesX intersection candidatesY

  # Sort by z-index (highest first)
  return widgets.sortedByDescending(w => w.zIndex)
```

### Event Patterns

**Replaceable** (mouse move):
```nim
if eventQueue.hasEvent(MouseMove):
  # Discard all but last MouseMove
  eventQueue.keepLast(MouseMove)
```

**Debounced** (window resize):
```nim
if event.kind == WindowResize:
  # Wait 100ms of quiet before processing
  if now() - lastResizeTime > 100ms:
    processResize()
```

**Throttled** (scroll):
```nim
if event.kind == Scroll:
  # Maximum 60 events per second
  if now() - lastScrollTime > 16ms:
    processScroll()
    lastScrollTime = now()
```

**Batched** (touch gestures):
```nim
if event.kind in [TouchDown, TouchMove, TouchUp]:
  # Collect all touch events
  touchBatch.add(event)

if touchBatch.isComplete():
  # Process as gesture
  recognizeGesture(touchBatch)
  touchBatch.clear()
```

---

## Reactive Data Binding

### Link System

The Link[T] system provides efficient reactive updates by storing direct references to dependent widgets:

```nim
type Link*[T] = ref object
  valueInternal: T
  dependentWidgets: HashSet[Widget]  # Direct widget references, not IDs!
  onChange*: proc(oldVal, newVal: T)

proc value*[T](link: Link[T]): T =
  link.valueInternal

proc `value=`*[T](link: Link[T], newVal: T) =
  if link.valueInternal != newVal:
    let oldVal = link.valueInternal
    link.valueInternal = newVal

    # Direct widget updates - NO tree traversal needed!
    for widget in link.dependentWidgets:
      widget.isDirty = true
      # Can even re-render immediately:
      widget.render()  # Generates new texture
      # Layout pass will set bounds later

    # Call onChange callback
    if link.onChange != nil:
      link.onChange(oldVal, newVal)
```

**Key Optimization**: By storing direct widget references instead of IDs, we can:
1. Immediately mark widgets dirty (no lookup needed)
2. Re-render widgets directly (no tree traversal)
3. Let layout pass position them later
4. Achieve O(1) per dependent widget instead of O(tree size)

### Binding in DSL

```nim
buildUI:
  Label:
    text: bind <- store.username

# Expands to:
let label = Label.new()
label.textLink = store.username
store.username.dependentWidgets.incl(label)  # Store direct reference!
```

**At Binding Time**: The Link registers the widget in its `dependentWidgets` HashSet.

**When Value Changes**:
```nim
store.username.value = "John"  # User code

# Link internally does:
for widget in dependentWidgets:
  widget.isDirty = true
  widget.render()  # Can render immediately!
```

**On Next Frame**:
- Layout pass calculates bounds for all widgets (including dirty ones)
- Render pass draws already-rendered textures at new positions

### Manual Binding

```nim
# Explicit binding in code
proc bindToLink[T](widget: Widget, link: Link[T]) =
  link.dependentWidgets.incl(widget)  # Direct reference
  widget.linkedData.add(link)  # Optional: track for cleanup

# Usage
let label = Label.new()
label.bindToLink(store.counter)

# Now when counter changes:
store.counter.value += 1
# label is automatically marked dirty and re-rendered!
```

### Render-Before-Layout Pattern

This design enables an efficient pattern:
1. **Data changes** → Link notified
2. **Widgets re-render** → Generate new textures (content updated)
3. **Layout pass** → Calculate positions/bounds (geometry updated)
4. **Draw pass** → Blit textures at correct positions

This means widget *content* updates immediately without waiting for layout, but *positioning* happens in the layout pass. Perfect for responsive UIs!

---

## Theme System

### Theme Structure

```nim
type
  ThemeState* = enum
    tsNormal, tsDisabled, tsHovered, tsPressed, tsFocused, tsSelected

  ThemeIntent* = enum
    tiDefault, tiInfo, tiSuccess, tiWarning, tiDanger

  ThemeProps* = object
    backgroundColor*: Color
    textColor*: Color
    borderColor*: Color
    borderWidth*: float32
    borderRadius*: float32
    fontSize*: float32
    # ... more properties

  Theme* = ref object
    lookup*: Table[(ThemeState, ThemeIntent), ThemeProps]
    cache*: Table[(ThemeState, ThemeIntent), ThemeProps]
```

### Theme Lookup

```nim
proc getTheme*(widget: Widget, state: ThemeState, intent: ThemeIntent): ThemeProps =
  let key = (state, intent)

  # Check cache first
  if key in app.currentTheme.cache:
    return app.currentTheme.cache[key]

  # Lookup and cache
  let props = app.currentTheme.lookup.getOrDefault(key, defaultProps)
  app.currentTheme.cache[key] = props
  return props
```

### Theme Switching

```nim
# Instant theme switch - just pointer assignment
app.currentTheme = darkTheme

# Invalidate all widgets to use new theme
app.invalidateAll = true
```

---

## Text Rendering

### Pango Integration

```nim
# In text/pango_wrapper.nim

proc renderText*(text: string, style: TextStyle): Texture2D =
  # Create Pango layout
  let layout = pango_layout_new(pangoContext)
  pango_layout_set_text(layout, text)
  pango_layout_set_font_description(layout, style.fontDesc)

  # Measure
  var width, height: cint
  pango_layout_get_pixel_size(layout, addr width, addr height)

  # Render to Cairo surface
  let surface = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, width, height)
  let cr = cairo_create(surface)

  pango_cairo_show_layout(cr, layout)

  # Convert to Raylib texture
  let texture = convertCairoSurfaceToTexture(surface)

  # Cleanup
  cairo_destroy(cr)
  cairo_surface_destroy(surface)
  g_object_unref(layout)

  return texture
```

### Text Caching

```nim
type TextCache* = ref object
  cache*: Table[string, (Texture2D, Size)]
  maxSize*: int

proc getCachedText*(cache: TextCache, text: string, style: TextStyle): Texture2D =
  let key = text & $style

  if key in cache.cache:
    return cache.cache[key][0]

  # Render and cache
  let texture = renderText(text, style)
  let size = Size(width: texture.width, height: texture.height)
  cache.cache[key] = (texture, size)

  # LRU eviction if needed
  if cache.cache.len > cache.maxSize:
    cache.evictOldest()

  return texture
```

---

## Performance Optimizations

### 1. Dirty Flag Propagation

Only recalculate what changed:

```nim
proc markDirty(widget: Widget) =
  if not widget.isDirty:
    widget.isDirty = true
    app.dirtyWidgets.incl(widget.id)

    # Propagate to parent (layout may change)
    if widget.parent != nil:
      widget.parent.markLayoutDirty()
```

### 2. Spatial Indexing

Interval trees for O(log n) hit testing instead of O(n):

```nim
# Insert widget bounds into trees
xTree.insert(widget.bounds.x, widget.bounds.x + widget.bounds.width, widget)
yTree.insert(widget.bounds.y, widget.bounds.y + widget.bounds.height, widget)

# Query in O(log n)
let hits = findWidgetsAt(mouseX, mouseY)  # Much faster than checking all widgets
```

### 3. Event Coalescing

Reduce unnecessary work:

```nim
# Instead of 100 mouse move events per second
# Process only 1 per frame (16ms at 60 FPS)
if event.kind == MouseMove:
  eventQueue.keepLast(MouseMove)
```

### 4. Texture Caching

Render once, reuse many times:

```nim
# Widget renders to texture when dirty
if widget.isDirty:
  widget.cachedTexture = renderToTexture(widget)
  widget.isDirty = false

# Every frame: just draw texture (very fast)
drawTexture(widget.cachedTexture, widget.bounds)
```

### 5. Theme Caching

Avoid repeated lookups:

```nim
# Cache theme props for common (state, intent) combinations
let key = (Normal, Default)
if key notin theme.cache:
  theme.cache[key] = theme.lookup[key]

return theme.cache[key]  # Instant access
```

### 6. Layout Optimization (Future)

Current: Calculate every frame (simple, works well for small UIs)

Future optimization:
- Only recalculate subtrees with layoutDirty flag
- Cache layout results
- Incremental layout updates

---

## Data Flow Summary

### Input-Driven Updates

```
User Input → Events → Event Manager → Widget Handlers
                                           ↓
                                    Store Updates
                                           ↓
                                    Link Notifications
                                           ↓
                        Direct Widget Updates (O(1) per widget!)
                                           ↓
                              ┌────────────┴────────────┐
                              ↓                         ↓
                    Mark isDirty = true        Call widget.render()
                                           (generate new texture)
                              ↓                         ↓
                              └────────────┬────────────┘
                                           ↓
                              Next Frame: Layout Pass
                            (calculate bounds/positions)
                                           ↓
                              Draw Pass (blit textures)
                                           ↓
                                       Display
```

### Key Optimization: No Tree Traversal

When `store.counter.value = 42`:
1. Link has direct references to dependent widgets
2. Immediately marks each widget dirty: `widget.isDirty = true`
3. Can even render immediately: `widget.render()` (generates new texture)
4. Layout pass on next frame positions all widgets
5. Draw pass blits cached textures

**Performance**: O(n) where n = number of widgets bound to that specific Link, NOT O(total widgets in tree)!

## Thread Safety

Current: Single-threaded (Raylib is single-threaded)

Future considerations:
- Async data loading (separate thread)
- Background layout calculation (worker thread)
- Render queue submission (separate thread)

For now: Keep it simple, single-threaded, no locks needed.

---

## Design Decisions

This section documents critical design decisions made for RUI, with rationale and implications.

### Event Processing: Time-Budgeted with Pattern-Based Coalescing

**Decision**: Use time-budgeted event processing with pattern-based coalescing.

**Rationale**:
- UI responsiveness requires maintaining 60 FPS (16.67ms per frame)
- Some events may take significant time to process
- Different event types have different processing requirements
- Mouse moves generate many events (1000+/sec) but only the last position matters
- Keyboard input must preserve exact sequence for text input correctness

**Implementation**:

```nim
type EventPattern = enum
  epNormal      # Process immediately
  epReplaceable # Only last matters (mouse move) - compress 1000 → 1
  epDebounced   # Wait for quiet period (window resize - 350ms)
  epThrottled   # Rate limited (mouse wheel - max 1 per 50ms)
  epBatched     # Collect related events (touch gestures)
  epOrdered     # Sequence MUST be preserved (keyboard, clicks)
```

**Frame Cycle**:
1. Collect raw Raylib events
2. Add to EventManager (applies pattern-based coalescing)
3. EventManager.update() processes patterns
4. Process events from priority queue with time budget (default 8ms)
5. Layout if `tree.anyDirty`
6. Render

**Key Requirements**:
- **Order Preservation**: `epOrdered` events (keyboard, clicks) MUST maintain sequence
  - Example: TextArea with click → typing sequence must be exact
  - Priority queue uses timestamp for FIFO within same priority
- **Smart Compression**: `epReplaceable` events (mouse moves) compressed to single event
  - Example: 1000 mouse moves → 1 move (last position)
- **Budget Management**: Reserve 8ms for events, 8ms for layout+render
  - Adaptive: Learn from historical timing, adjust budget dynamically
  - Deferred processing: Events exceeding budget deferred to next frame

**Example Scenario** (TextArea click + typing):
```
User actions:
  MouseMove(100,50), MouseMove(105,50), MouseMove(110,50), MouseMove(115,50)
  MouseDown(115,50), MouseUp(115,50)
  KeyDown('H'), KeyDown('e'), KeyDown('l'), KeyDown('l'), KeyDown('o')

After coalescing:
  MouseMove(115,50)          # Last position only (4 → 1)
  MouseDown(115,50)          # In order!
  MouseUp(115,50)            # In order!
  KeyDown('H')               # In order!
  KeyDown('e')               # In order!
  KeyDown('l')               # In order!
  KeyDown('l')               # In order!
  KeyDown('o')               # In order!

Result: ✅ Click at correct position, text typed correctly
```

**Performance Impact**:
- Typical events: < 1ms each, budget handles easily
- Complex events: Deferred to next frame, prevents frame drops
- Mouse move compression: Reduces event count by 90%+

---

### Layout System: Every-Frame with Tree-Level Dirty Flag

**Decision**: Run layout every frame when `tree.anyDirty = true`, using Flutter-style two-pass algorithm.

**Rationale**:
- Flutter-style layout is proven, well-understood, sufficient for 99% of UIs
- Constraint solvers add complexity, dependencies (Kiwi), and debugging difficulty
- Modern CPUs can layout 1000+ widgets in < 5ms
- Tree-level dirty flag provides fast path when nothing changed

**Implementation**:

```nim
type WidgetTree = ref object
  root: Widget
  anyDirty: bool  # ← Tree-level optimization

proc mainLoop():
  # ... event processing ...

  if app.tree.anyDirty:
    layoutTree(app.tree)      # Two-pass Flutter-style
    app.tree.anyDirty = false
  # else: skip layout entirely (fast path)

  renderFrame(app)
```

**Two-Pass Algorithm**:
1. **Measure (Constraints Down, Sizes Up)**:
   - Parent passes constraints to children
   - Children measure themselves and return size
2. **Position**:
   - Parent positions children based on measured sizes

**Dirty Propagation**:
- Link value changes → mark dependent widgets dirty → set `tree.anyDirty = true`
- Widget property changes → mark widget dirty → set `tree.anyDirty = true`
- Layout only runs when something actually changed

**Why Not Constraint Solver?**
- ❌ Additional dependency (Kiwi library)
- ❌ More complex debugging
- ❌ Overkill for typical UI layouts
- ❌ Harder to reason about behavior
- ✅ Flutter-style is simpler, proven, fast enough

**Performance Target**: < 5ms for 1000 widgets

---

### Link[T]: Direct Widget References (Not IDs)

**Decision**: Link[T] stores `HashSet[Widget]` (direct references), not `HashSet[WidgetId]`.

**Rationale**:
- O(1) dirty marking without hashtable lookup
- Simpler code: `widget.isDirty = true` vs `widgetMap[id].isDirty = true`
- Memory overhead negligible (pointer vs int + hashtable)
- Enables immediate rendering after value change

**Implementation**:

```nim
type Link*[T] = ref object
  valueInternal: T
  dependentWidgets: HashSet[Widget]  # Direct refs, not IDs!
  onChange*: proc(oldVal, newVal: T)

proc `value=`*[T](link: Link[T], newVal: T) =
  if link.valueInternal != newVal:
    let oldVal = link.valueInternal
    link.valueInternal = newVal

    # Direct widget updates - NO lookup needed!
    for widget in link.dependentWidgets:
      widget.isDirty = true        # O(1)
      app.tree.anyDirty = true     # O(1)

    if link.onChange != nil:
      link.onChange(oldVal, newVal)
```

**Performance**:
- O(n) where n = number of widgets bound to this specific Link
- NOT O(total widgets in tree)
- Each widget update is O(1)

**Memory Management**:
- Widgets hold references to Links (for reading)
- Links hold references to Widgets (for updates)
- Circular references managed by Nim's GC

---

### Render-Before-Layout Pattern

**Decision**: Widgets can re-render immediately on Link change, layout positions them next frame.

**Rationale**:
- Content updates can happen immediately (new texture generated)
- Positioning happens in layout pass
- Separates content rendering from layout concerns
- Enables efficient caching

**Flow**:
```
Link value changes → Link notifies widgets
                                ↓
                    ┌───────────┴───────────┐
                    ↓                       ↓
            Mark isDirty=true      Optionally: widget.render()
                                   (generate new texture now)
                    ↓                       ↓
                    └───────────┬───────────┘
                                ↓
                    Next frame: Layout pass
                    (calculate positions/bounds)
                                ↓
                    Draw pass: blit textures
```

**Key Insight**: Widget *content* updates immediately, *positioning* happens in layout pass.

---

### Scripting System: Simple File-Based Polling

**Decision**: Poll command file once per second for test automation, no IPC.

**Rationale**:
- IPC (channels, sockets) is overkill for automated testing
- File-based is simpler, cross-platform, debuggable
- 1-second polling is sufficient for automated tests
- Can inspect commands/responses with text editor

**Implementation**:

```nim
# Test writes commands
/tmp/rui_test_12345/commands.json:
{
  "id": "cmd_001",
  "target": "mainWindow/form/nameInput",  # CSS-like path
  "action": "setText",
  "params": {"text": "John"}
}

# App reads every second, writes response
/tmp/rui_test_12345/responses.json:
{
  "id": "cmd_001",
  "success": true,
  "state": {"text": "John", "bounds": {"x": 10, "y": 20, "w": 100, "h": 30}}
}
```

**Widget Path Syntax** (CSS-like):
- `"mainWindow"` - Top level
- `"mainWindow/panel/button"` - Nested
- `"mainWindow//button"` - Any descendant
- `"#saveButton"` - By ID
- `"mainWindow/panel/*"` - All children

**Polling**:
```nim
var lastScriptPoll = getMonoTime()

proc mainLoop():
  let now = getMonoTime()
  if now - lastScriptPoll >= 1.seconds:
    processScriptCommands()
    lastScriptPoll = now
```

**Use Case**: Automated testing only, not production feature.

**Why No IPC?**
- ❌ IPC adds complexity (channels, locking, error handling)
- ❌ Platform-specific code
- ❌ Harder to debug
- ✅ Files are simple, portable, inspectable
- ✅ 1-second latency is fine for tests

---

### Module Structure Decisions

**Decision**: Keep drawing primitives separate from widgets.

**Rationale**:
- Widgets use drawing primitives for rendering
- Separation enables reuse
- Widgets: high-level components with state
- Primitives: stateless drawing functions

**Decision**: Managers handle cross-cutting concerns.

**Rationale**:
- RenderManager: Texture caching, dirty tracking
- LayoutManager: Size/position calculations
- EventManager: Coalescing, routing, priority
- FocusManager: Tab order, keyboard nav
- Each manager has single responsibility

---

*These design decisions provide a solid foundation for a fast, maintainable, professional GUI framework.*
