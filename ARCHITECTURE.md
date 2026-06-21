# RUI2 Architecture

Technical reference for the RUI2 framework: design philosophy, the layout/render
pipeline, the widget DSL, reactivity, theming, the manager subsystems, and the
target package graph.

This document describes the design as it is actually implemented, plus clearly
labelled roadmap items. For a feature-by-feature status, see
[STATUS.md](STATUS.md). For usage, see [README.md](README.md).

## Table of contents

1. [Design philosophy](#design-philosophy)
2. [Core types](#core-types)
3. [Two-pass layout and render](#two-pass-layout-and-render)
4. [The widget DSL: definePrimitive vs defineWidget](#the-widget-dsl-defineprimitive-vs-definewidget)
5. [Reactivity: Link[T]](#reactivity-linkt)
6. [Theme system](#theme-system)
7. [Manager architecture](#manager-architecture)
8. [Scripting subsystem](#scripting-subsystem)
9. [Text rendering](#text-rendering)
10. [The 7-package architecture](#the-7-package-architecture)

---

## Design philosophy

### Immediate mode with caching

RUI2 follows immediate-mode principles — the UI is a function of state, redrawn
as needed — but layers caching on top so it stays cheap:

- Each widget renders to its own `RenderTexture2D` and the result is cached.
- A clean widget reuses its cached texture; only **dirty** widgets re-render.
- Two dirty flags per widget separate the two concerns: `layoutDirty` (geometry
  may have changed) and `isDirty` (pixels need redrawing).
- A tree-level `anyDirty` flag gives a fast path: when nothing changed, the whole
  layout/render pass is skipped.

The result is the simplicity of immediate mode (state in, pixels out, no retained
scene-graph bookkeeping) with the efficiency of retained mode (unchanged subtrees
cost a texture blit).

### No magic

The public API is plain Nim — explicit constructors, explicit `app` object,
explicit `Link[T]` state. There is a convenience global `app` var, but the app is
an ordinary object you can also pass around. Widget trees are ordinary
`proc(): Widget` builders you can inspect and recompose.

### Composition over inheritance

Complex widgets are built by composing simpler ones (a `Button` is a `Rectangle`
+ a `Label`), not by deep subclassing. The DSL's two macros make this distinction
first-class: primitives draw, composites arrange.

### Why this layout model (not a constraint solver)

RUI2 uses a simple parent-arranges-children layout rather than a constraint
solver (e.g. Cassowary/Kiwi). Rationale: a constraint solver adds a dependency,
is harder to debug, and is overkill for the small-to-medium desktop UIs RUI2
targets. A direct layout pass is simpler, predictable, and fast.

---

## Core types

Defined in `core/types.nim`.

```nim
type
  WidgetId* = distinct int      # internal numeric id (fast lookups)

  Rect*  = object
    x*, y*, width*, height*: float32
  Point* = object
    x*, y*: float32
  Size*  = object
    width*, height*: float32
  EdgeInsets* = object
    top*, right*, bottom*, left*: float32

  Widget* = ref object of RootObj
    id*: WidgetId               # internal numeric id
    stringId*: string           # user-facing id, used by scripting
    bounds*: Rect
    previousBounds*: Rect       # for incremental hit-test updates
    visible*, enabled*: bool
    hovered*, pressed*, focused*: bool
    isDirty*: bool              # needs re-render
    layoutDirty*: bool          # needs layout recalculation
    cachedTexture*: Option[RenderTexture2D]
    zIndex*: int
    hasOverlay*: bool           # if true, children are z-sorted when rendering
    blockReading*: bool         # scripting: hide sensitive values (passwords)
    onFocus*, onBlur*: Option[proc() {.closure.}]
    parent*: Widget
    children*: seq[Widget]

  WidgetTree* = ref object
    root*: Widget
    anyDirty*: bool             # tree-level fast-path flag
    isDirty*: bool
    widgetMap*: Table[WidgetId, Widget]
    widgetsByStringId*: Table[string, Widget]  # scripting lookups
```

The base `Widget` declares overridable methods that the DSL macros fill in:
`render`, `measure`, `layout`, `handleInput`, plus the scripting hooks
`handleScriptAction`, `getScriptableState`, and `getTypeName`.

`App` itself is defined in `core/app.nim` (not `types.nim`) to avoid circular
dependencies, since it depends on the managers. It owns the `WidgetTree`, the
optional `Store`, the `WindowConfig`, the managers, the theme manager + current
theme, and a text cache.

`WindowConfig` carries window sizing and resize policy: `width`, `height`,
`title`, `fps`, `resizable`, `minWidth`, `minHeight` (defaults 320×240 minimum).

---

## Two-pass layout and render

Implemented in `core/main_loop.nim`; driven from `core/app.nim`'s loop.

Each frame runs at most two passes over the tree, each gated by dirty flags.

### Pass 1 — Layout

`layoutPass(widget)` walks the tree. For any widget whose `layoutDirty` is set it
records the old bounds, calls `widget.layout()` (dynamic dispatch), and if the
bounds changed marks the widget `isDirty` so it will re-render. Then it clears
`layoutDirty` and recurses into children.

- **Composites** (`defineWidget`) override `layout()` to position/create children.
- **Primitives** (`definePrimitive`) use the base no-op `layout()` — they don't
  arrange anything.

### Pass 2 — Render

`renderPass(widget)` renders bottom-up so child textures exist before the parent
composites them:

1. Recurse into children first. If `hasOverlay` is set and there is more than one
   child, children are sorted by `zIndex` (ascending) so higher z-index draws on
   top (painter's algorithm). Otherwise children render in tree order.
2. If the widget is `isDirty`: free the old cached texture, create a fresh
   `RenderTexture2D` sized to its bounds, render the widget's own content at the
   texture origin, composite each visible child's cached texture at its relative
   position, then store the new texture in `cachedTexture` and clear `isDirty`.
3. If the widget is clean: its existing `cachedTexture` is reused as-is.

### Frame driver

`frame(rootWidget)` runs Pass 1 only if `rootWidget.layoutDirty` or any
descendant is layout-dirty, and Pass 2 only if `rootWidget.isDirty` or any
descendant is dirty. The app loop then composites the root's cached texture to
the screen.

### Why this is fast

For a 1000-widget tree where a click changes a single label, only that label's
ancestors are visited for layout and only the changed widgets re-render —
everything else is a cached texture blit.

### Cache invalidation rules

- Mark `layoutDirty` when: a container is resized, children are added/removed, a
  layout-affecting prop (spacing, padding) changes, or the window is resized.
- Mark `isDirty` when: layout changed the bounds, a visual prop changed, or a
  bound `Link[T]` value changed.
- A `Link[T].set` marks its dependent widgets both `isDirty` and `layoutDirty`
  (a content change may change size) and bubbles `layoutDirty` to the parent.

---

## The widget DSL: definePrimitive vs defineWidget

Both macros live in `core/widget_dsl.nim`. They generate the widget's `ref
object` type, a constructor (`newXxx`), the reactive-state plumbing, event
routing, and the lifecycle methods. They cut widget boilerplate dramatically
versus writing the type/constructor/methods by hand.

The two macros encode a single, clean distinction:

- **`definePrimitive`** = *"I draw myself."* A leaf that renders directly with
  drawing primitives (`drawText`, `drawRect`, `drawCircle`, …). It generates a
  `render` method and **no** `layout` — primitives are positioned by their parent.
  Examples: `Label`, `Rectangle`, `Circle`.
- **`defineWidget`** = *"I arrange others."* A composite that creates and/or
  positions children. It generates a `layout` method (and a default `render` that
  composites children). Examples: `Button` (Rectangle + Label), `VStack`,
  `HStack`, `ZStack`, `ScrollView`.

This mirrors raylib's immediate-mode style: low-level draw calls for atoms,
explicit composition for compound controls.

### Section format

A widget definition is organised into named sections. The common sections are:

| Section   | Purpose |
|-----------|---------|
| `props`   | Public, constructor-settable fields (with optional defaults). Become `newXxx` parameters. |
| `state`   | Internal reactive state; each field is auto-wrapped in `Link[T]` and initialised. Not in the constructor. Used for `isPressed`, `isHovered`, etc. |
| `actions` | Callback signatures (e.g. `onClick()`, `onChange(v: float)`). Generated as `Option[proc(...)]` fields and `newXxx` params (default `nil`). |
| `events`  | Event handlers (`on_mouse_down`, `on_mouse_up`, `on_mouse_move`, `on_key_down`, …). Each has access to `widget` and `event`; return `true` to consume, `false` to propagate. |
| `render`  | (Primitives) drawing code using drawing primitives. |
| `layout`  | (Composites) code that positions and/or builds `widget.children`. |

A real composite, from `widgets/basic/button_v2.nim` (condensed):

```nim
defineWidget(Button):
  props:
    text: string
    disabled: bool = false
    intent: ThemeIntent = Default
  state:
    isPressed: bool
    isHovered: bool
  actions:
    onClick()
  events:
    on_mouse_down:
      if not widget.disabled:
        widget.isPressed = true
        return true
      return false
    on_mouse_up:
      if widget.isPressed and not widget.disabled:
        widget.isPressed = false
        if widget.onClick.isSome: widget.onClick.get()()
        return true
      return false
    on_mouse_move:
      widget.isHovered = pointInRect(event.mousePos, widget.bounds)
      return false
  layout:
    widget.children.setLen(0)               # rebuilt each layout pass
    let state = if widget.disabled: Disabled
                elif widget.isPressed: Pressed
                elif widget.isHovered: Hovered
                else: Normal
    let props = currentTheme.getThemeProps(widget.intent, state)
    let bg = newRectangle(color = props.backgroundColor.get(GRAY),
                          cornerRadius = props.cornerRadius.get(4.0), filled = true)
    bg.bounds = widget.bounds
    widget.children.add(bg)
    let lbl = newLabel(text = widget.text,
                       fontSize = props.fontSize.get(14.0),
                       color = props.foregroundColor.get(WHITE))
    lbl.bounds = centeredRect(widget.bounds)
    widget.children.add(lbl)
```

Notes that hold in the current code:

- Events propagate child → parent until one handler returns `true`.
- A composite may rebuild its children on every layout pass (`children.setLen(0)`
  then re-add), reading theme + state at build time. This is deliberate for
  immediate-mode rendering; see the reactivity caveat below.

### Primitive purity

There was a real design question of whether primitives may also use internal
layout/children, or stay pure (draw-only). The resolution favours **pure
primitives** for performance and a clear conceptual boundary: pure primitives
avoid per-child widget allocation, extra layout calculations, and dispatch
indirection. Compound controls use `defineWidget` and compose primitives. (A
hybrid primitive remains possible but is not the default pattern.)

---

## Reactivity: Link[T]

Implemented in `core/link.nim`; the type is in `core/types.nim`.

```nim
type Link*[T] = ref object
  value*: T
  dependentWidgets*: HashSet[Widget]   # direct refs, not ids
  onChange*: proc(oldVal, newVal: T)
```

API: `newLink(initial)`, `link.value` / `link.get()` to read,
`link.value = v` / `link.set(v)` to write, `addDependent`/`removeDependent`/
`hasDependent`/`dependentCount` to manage subscribers, and `setOnChange` for a
side-effect callback.

**Key optimisation — direct widget references.** A `Link` stores the actual
dependent `Widget` objects, not their ids. On a value change it can mark each
dependent dirty in O(1) with no hashtable lookup and no tree traversal:

```nim
proc `value=`*[T](link: Link[T], newVal: T) =
  if link.value != newVal:
    let oldVal = link.value
    link.value = newVal
    for w in link.dependentWidgets:
      w.isDirty = true
      w.layoutDirty = true            # content change may affect size
      if w.parent != nil: w.parent.layoutDirty = true
    if link.onChange != nil: link.onChange(oldVal, newVal)
```

Cost is O(n) in the number of widgets bound to *that* link, not O(total widgets).
Because RUI2 is immediate-mode, the widget then simply reads the new value during
its next `layout`/`render` — there is no separate value-push step.

**Caveat (roadmap):** the `bind` DSL operator that would auto-register a widget
in a link's `dependentWidgets` is **not yet wired**. Today widgets read store
values at build/layout time, and a re-layout happens when the surrounding tree is
marked dirty. `addDependent` exists and can be called manually. Wiring `bind` so
a widget rebinds and auto-marks dirty on every relevant change is a roadmap item
(see STATUS.md).

---

## Theme system

Core in `drawing_primitives/theme_sys_core.nim`; built-ins in
`drawing_primitives/builtin_themes.nim`; runtime switching via a `ThemeManager`
(`drawing_primitives/theme_manager.nim`). Themes are loaded/serialised with the
`yaml` dependency.

### State × Intent → Props

The model is a 2-D lookup:

- **`ThemeState`** — interaction state: `Normal`, `Disabled`, `Hovered`,
  `Pressed`, `Focused`, `Selected`, `DragOver`.
- **`ThemeIntent`** — semantic role: `Default`, `Info`, `Success`, `Warning`,
  `Danger`.

A `Theme` holds a `base` table (props per intent) and a `states` table (per
intent, per state overrides). Resolution cascades: widget default → base intent →
state override (later wins).

```nim
type ThemeProps* = object
  backgroundColor*, foregroundColor*, borderColor*: Option[Color]
  borderWidth*, cornerRadius*, spacing*: Option[float32]
  padding*: Option[EdgeInsets]
  fontSize*: Option[float32]
  fontFamily*: Option[string]     # default "sans-serif" in built-ins
  textStyle*: Option[TextStyle]
  # focus styling: focusRingColor / focusRingWidth / focusGlowRadius / focusGlowColor
  # plus effect fields (bevel, gradient, drop/inner shadow, glow) for richer themes
```

All fields are `Option`, so a theme overrides only what it needs and everything
else inherits.

Widgets query the active theme during `layout`/`render`:

```nim
let state = if widget.disabled: Disabled
            elif widget.isPressed: Pressed
            elif widget.isHovered: Hovered
            elif widget.focused:   Focused
            else: Normal
let props = currentTheme.getThemeProps(widget.intent, state)
```

### Zero-cost switching

Because RUI2 is immediate-mode, switching themes is just swapping the active
`Theme` pointer and marking the tree dirty — no per-widget update, no Link needed
for the theme itself:

```nim
app.setTheme("dark")    # by name (registered in ThemeManager)
app.setTheme(myTheme)   # by Theme object
```

Both update `app.currentTheme`, the manager's current theme, and set
`tree.anyDirty` so widgets pick up new values on the next frame. Built-in themes:
`light`, `dark`, `beos`, `joy`, `wide` (light is the default).

### Focus styling

Focus is themeable via `focusRingColor`, `focusRingWidth`, and optional
`focusGlowRadius`/`focusGlowColor`. The `FocusManager` sets `widget.focused`, and
a widget draws its ring when `focused` and the theme provides a ring colour.

---

## Manager architecture

The framework is organised as a functional pipeline of single-responsibility
managers owned by `App`:

```
Widget Tree → Layout → Hit-Test → Render → Display
```

The frame loop in `core/app.nim` is, in order:

1. `collectRaylibEvents` — translate raylib input into `GuiEvent`s.
2. `eventManager.update()` — apply coalescing patterns.
3. `eventManager.processEvents(budget, handler)` — drain the queue within a time
   budget, routing each event via `handleEvent`.
4. `pollScriptCommands` — service the scripting file protocol.
5. `updateLayoutAndRender` — run the two-pass `frame`, then rebuild the hit-test
   tree from the freshly laid-out bounds.
6. `renderFrame` — composite the root texture to the window.

### Event manager (time-budgeted + coalesced)

`managers/event_manager_refactored.nim`. UI must hold ~60 FPS (16.7 ms/frame),
but events vary wildly in cost and volume, so the manager combines a **time
budget** (default 8 ms/frame) with **pattern-based coalescing**:

| Pattern         | Behaviour | Example |
|-----------------|-----------|---------|
| `epNormal`      | process immediately | generic |
| `epReplaceable` | keep only the latest | mouse move (1000 → 1) |
| `epDebounced`   | wait for a quiet period | window resize |
| `epThrottled`   | rate-limited | mouse wheel / scroll |
| `epBatched`     | collect related events | touch gestures |
| `epOrdered`     | preserve exact sequence | keyboard, clicks |

Ordering guarantees matter: keyboard and click sequences are `epOrdered` so text
input and click-then-type interactions stay correct, while high-volume mouse
moves are compressed to the last position. Events that would blow the frame
budget are deferred to the next frame instead of dropping a frame.

`GuiEvent` carries `kind` (`EventKind`), `priority` (`EventPriority`:
`epHigh`/`epNormal`/`epLow`), a timestamp, and the relevant payload (mouse
position, key, char, wheel delta, window size). Events are ordered in the queue
by priority then timestamp (FIFO within a priority).

### Focus manager

`managers/focus_manager.nim`. Tracks the focused widget, handles keyboard routing
(Tab / Shift-Tab order), and fires `onFocus`/`onBlur`. Keyboard events
(`evKeyDown`, `evChar`) are routed through the focus manager rather than by
hit-testing.

### Hit-test system

`hit-testing/`. Mouse events are routed by spatial lookup. The system builds
interval trees over widget bounds for O(log n) point queries instead of an O(n)
scan. After each layout pass the tree is rebuilt from the updated bounds
(`rebuildHitTestTree`); `previousBounds` exists to enable incremental updates as a
future optimisation. The interval-tree core is generic and usable on its own.

### Render

Rendering is the two-pass texture pipeline in `core/main_loop.nim` described
above; there is no separate retained render queue object — caching is per-widget
via `cachedTexture`.

---

## Scripting subsystem

`scripting/`, integrated through `core/app.nim` (`enableScripting(dir)` /
`disableScripting`). Purpose: drive and inspect a running GUI from outside for
**automated testing** — query and set widget values without visual confirmation.

- **File-based, not IPC.** The app polls a command file (the script manager owns
  its own timing) and writes responses; this is simple, language-agnostic,
  cross-platform, and inspectable with a text editor. No sockets, no FFI.
- **Widget addressing.** Widgets carry a user-facing `stringId`; the tree keeps a
  `widgetsByStringId` map. A CSS-like path syntax addresses widgets
  (`mainWindow/form/nameInput`, wildcards, etc.).
- **Per-widget hooks.** Each scriptable widget overrides `handleScriptAction(action,
  params): JsonNode` and `getScriptableState(): JsonNode` (the DSL provides
  `getTypeName`). For example, `Button` supports `click` and `getText`.
- **Privacy.** `blockReading` lets a widget refuse to expose sensitive values
  (e.g. password fields) while still accepting actions.
- **Visual cue.** While a script is in control, the app draws an orange border and
  a "SCRIPTING" indicator so it's obvious the UI is being driven.

This is a testing/automation facility, not a production feature.

---

## Text rendering

**Current:** text is drawn with raylib/naylib's basic `drawText` via the drawing
primitives and a text cache (`drawing_primitives/primitives/text_cache.nim`,
keyed on text + style with bounded entries / LRU eviction). The `Label` primitive
builds a `TextStyle` (family, size, colour, bold/italic/underline) and calls
`drawText` with an alignment.

**Roadmap — Pango/Cairo.** Professional text (full Unicode, BiDi for
Hebrew/Arabic, complex-script shaping, wrapping) via Pango+Cairo rendered to
raylib textures is a long-standing aspiration and is **not wired**. The `Label`
source still carries a `TODO: Integrate Pango`. The drawing API is intended to be
a drop-in target for a future Pango backend, and text caching is already designed
for the 2–5 ms-first/~0.1 ms-cached profile such a backend needs. See STATUS.md.

---

## The 7-package architecture

RUI2 is being restructured so each subsystem is a self-contained package under
`packages/<name>/`, later split into separate git repos via
`git subtree split`. Several subsystems (interval-tree hit-testing, the event
manager, the theme system) are deliberately decoupled and usable standalone.

| Package          | Responsibility |
|------------------|----------------|
| `rui_core`       | Shared base: Widget/Rect/Color/event types, `Link[T]` reactive primitive, two-pass main loop, the `definePrimitive`/`defineWidget` DSL macros. |
| `rui_hittest`    | Generic interval tree + Widget-aware spatial hit-testing. |
| `rui_events`     | Time-budgeted event manager + focus manager. |
| `rui_drawing`    | Drawing primitives, effects, theme system (state × intent), text cache, theme-aware widget primitives. |
| `rui_scripting`  | File-based GUI automation (query/set widget values) used for testing. |
| `rui_widgets`    | Concrete widgets: primitives (label/rectangle/circle), basic (button/checkbox/radiobutton/slider/progressbar/hyperlink/image), containers (vstack/hstack/zstack/scrollview). |
| `rui` (umbrella) | `App` object + main-loop integrator + re-exports everything. |

### Dependency graph

```
                         rui  (umbrella: App + main-loop integrator)
                          │
        ┌─────────────────┼──────────────────────────┐
        │                 │                           │
   rui_widgets        rui_events                rui_scripting
        │                 │                           │
        ├─────────────────┴───────────────┐          │
        │                                  │          │
   rui_drawing                        rui_hittest     │
        │                                  │          │
        └──────────────┬───────────────────┴──────────┘
                       │
                    rui_core   (types, Link[T], two-pass loop, DSL macros)
                       │
                 naylib (raylib)
```

- `rui_core` depends only on naylib.
- `rui_drawing`, `rui_hittest`, `rui_events`, `rui_scripting` build on `rui_core`.
- `rui_widgets` builds on `rui_core` + `rui_drawing` (and the event types).
- `rui` (umbrella) integrates the managers and re-exports the whole API.

> **Status:** this layout is the **target**. The current tree still uses the flat
> `core/`, `widgets/`, `drawing_primitives/`, `managers/`, `hit-testing/`,
> `scripting/` directories, with `rui.nim` as the umbrella and `modules/*/api`
> shims exposing each subsystem. See [STATUS.md](STATUS.md).
