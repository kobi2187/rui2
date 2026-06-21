# RUI2 — Reactive UI Framework for Nim

**Fast, lightweight, immediate-mode-with-caching GUI toolkit for Nim, built on raylib.**

> ⚠️ **Alpha / work in progress.** The architecture is solid and the core widgets
> compile and run, but not every feature is wired yet. APIs may change. See
> [STATUS.md](STATUS.md) for an honest, feature-by-feature breakdown before you
> rely on anything.

RUI2 builds UIs from plain Nim — you describe a widget tree with ordinary
constructor calls, hold mutable state in `Link[T]`, and run a two-pass
layout/render loop that caches each widget to a texture and only redraws what
changed.

```nim
import rui

# 1. Reactive state lives in Link[T]
type CounterStore = object
  count: Link[int]

var store = CounterStore(count: newLink(0))

# 2. The widget tree is just a proc that returns a Widget
proc buildUI(): Widget =
  let root = newVStack(spacing = 12, padding = 16)
  root.addChild(newLabel(text = "Count: " & $store.count.get(), fontSize = 24))

  let row = newHStack(spacing = 8)
  row.addChild(newButton(text = "-", onClick = some(proc() {.closure.} =
    store.count.set(store.count.get() - 1))))
  row.addChild(newButton(text = "+", onClick = some(proc() {.closure.} =
    store.count.set(store.count.get() + 1))))
  root.addChild(row)
  result = root

# 3. Create the app, set the root widget, run
let app = newApp("Counter", 400, 300)
app.setRootWidget(buildUI())
app.run()   # `app.start()` is an alias
```

## The actual API

RUI2 has **no magic and no hidden globals**. Everything is regular Nim:

- **State** — `newLink(value)`, then `link.get()` / `link.set(v)` (or `link.value`).
  A `Link[T]` keeps direct references to the widgets that depend on it for O(1)
  dirty-marking.
- **Widget tree** — construct widgets with `newX(...)` and assemble with `addChild`:
  ```nim
  let box = newVStack(spacing = 10)
  box.addChild(newLabel(text = "Hello"))
  box.addChild(newButton(text = "OK", onClick = some(handleOk)))
  ```
  A tree builder is an ordinary `proc(): Widget`, so you can compose, inspect, and
  reuse it freely. (An ergonomic block-children DSL is a roadmap item.)
- **Callbacks** — widget actions are `Option[proc]`, so wrap handlers in `some(...)`.
  Capturing handlers become closures automatically; a non-capturing handler needs
  `proc() {.closure.} = ...` to match the closure type.
- **App lifecycle** — `newApp(title, width, height, fps = 60, resizable = true,
  minWidth = 320, minHeight = 240)`, then `app.setRootWidget(root)`,
  optionally `app.setStore(store)` / `app.setTheme("dark")`, then `app.run()`.

> **Note:** RUI2 does **not** use a YAML-style `buildUI:` block or a `bind <-`
> reactive operator. Earlier design notes described that syntax; it is not
> implemented. Widgets read their values when their `layout`/`render` runs.
> Automatic `bind` rebinding is a roadmap item (see [STATUS.md](STATUS.md)).

## Defining your own widgets

Two macros generate the widget boilerplate (type, constructor, methods). They
share the same section format — `props`, `state`, `actions`, `events`, plus
`render` (primitives) or `layout` (composites):

```nim
# A leaf that draws itself with drawing primitives
definePrimitive(Label):
  props:
    text: string
    fontSize: float = 14.0
    color: Color = BLACK
  render:
    drawText(widget.text, widget.bounds, ...)

# A composite that arranges/creates children
defineWidget(VStack):
  props:
    spacing: float = 8.0
    padding: float = 0.0
  layout:
    var y = widget.bounds.y + widget.padding
    for child in widget.children:
      child.bounds.x = widget.bounds.x + widget.padding
      child.bounds.y = y
      child.bounds.width = widget.bounds.width - widget.padding * 2
      child.layout()
      y += child.bounds.height + widget.spacing
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full `definePrimitive` vs
`defineWidget` distinction and every section.

## What works today

Widgets that compile and run: **Label, Rectangle, Circle, Button, Checkbox,
RadioButton, Slider, ProgressBar, Hyperlink, Image, VStack, HStack, ZStack,
ScrollView**. See STATUS.md for the authoritative list.

## Installation

RUI2 targets the [naylib](https://github.com/planetis-m/naylib) raylib binding.

```bash
git clone https://github.com/kobi2187/rui2
cd rui2
nimble install naylib yaml
```

Dependencies:

- **Nim** ≥ 2.0
- **naylib** — raylib binding (provides the bundled raylib)
- **yaml** — used for theme loading

The repo is a monorepo of packages (below); the root `config.nims` wires them up
for local development, so examples just `import rui`:

```bash
nim c -r examples/simple_counter_app.nim
```

RUI2 compiles and runs **graphics-only** against naylib (verified with
`nim check`). A headless mode was removed as a deferred future feature.

## Package layout

RUI2 is organised as **7 self-contained packages** under `packages/`, so each
subsystem can be used independently and later split into its own repository:

| Package          | Responsibility |
|------------------|----------------|
| `rui_core`       | Widget/Rect/Color/event types, `Link[T]`, two-pass main loop, `definePrimitive`/`defineWidget` macros |
| `rui_hittest`    | Generic interval tree + Widget-aware spatial hit-testing |
| `rui_events`     | Time-budgeted event manager + focus manager |
| `rui_drawing`    | Drawing primitives, effects, theme system (state × intent), text cache, theme-aware widget primitives |
| `rui_scripting`  | File-based GUI automation (query/set widget values) for testing |
| `rui_widgets`    | Concrete widgets: primitives, basic controls, containers |
| `rui` (umbrella) | `App` object + main-loop integrator + re-exports everything |

Each package has its own `.nimble` and `src/` barrel. The root `config.nims`
resolves them by bare name for local dev (`import rui`, `import rui_core`, ...).
To peel a subsystem into its own repo, see **[SPLITTING.md](SPLITTING.md)**.
Subsystems such as the interval-tree hit-tester, the event manager, and the theme
system are designed to stand alone.

## Documentation

- **[ARCHITECTURE.md](ARCHITECTURE.md)** — design philosophy, two-pass
  layout/render, the DSL macros, `Link[T]`, theme system, managers, package graph.
- **[STATUS.md](STATUS.md)** — honest implementation status: what works, what's a
  roadmap item, known issues, next steps.
- **[SPLITTING.md](SPLITTING.md)** — how to split each package into its own repo.

## License

To be determined.
