# RUI2 Status

**Honest, current implementation status. No overselling.**

RUI2 is **alpha / work-in-progress**. The architecture is solid and, as of this
cleanup, the whole tree **compiles cleanly** (`nim check`, 0 errors) graphics-only
against [naylib](https://github.com/planetis-m/naylib). Not every feature in the
design is wired yet. APIs may change. This document is the source of truth for
what actually works.

See [ARCHITECTURE.md](ARCHITECTURE.md) for the design and [README.md](README.md)
for usage.

---

## At a glance

| Area | Status |
|------|--------|
| Core types, Widget tree, App, main loop | ✅ Working |
| Two-pass layout + render with per-widget texture caching | ✅ Working |
| `definePrimitive` / `defineWidget` DSL macros | ✅ Working |
| `Link[T]` reactive primitive (O(1) dirty-marking) | ✅ Working |
| `bind` DSL operator (auto-rebind widgets to a Link) | 🚧 Roadmap — **not wired** |
| Theme system (ThemeState × ThemeIntent), runtime switching | ✅ Working |
| Event manager (time-budgeted + coalescing) | ✅ Working |
| Focus manager (focus tracking, keyboard routing) | ✅ Working |
| Hit-testing (interval trees, O(log n)) | ✅ Working |
| Scripting subsystem (file-based query/set) | ✅ Working (testing tool) |
| naylib port, graphics-only build | ✅ Done — `nim check` clean |
| 7-package split under `packages/` | ✅ Done |
| Text rendering | ⚠️ Basic raylib `drawText` only |
| Pango/Cairo text (Unicode/BiDi/shaping) | 🚧 Roadmap — binding exists, not wired into `Label` |

---

## Package layout

The library is split into 7 self-contained packages under `packages/`, each with
its own `.nimble` and `src/` barrel, ready to `git subtree split` into its own
repo (see [SPLITTING.md](SPLITTING.md)):

| Package | Depends on | Purpose |
|---------|-----------|---------|
| `rui_core` | naylib | types, `Link[T]`, two-pass main loop, widget DSL |
| `rui_hittest` | rui_core | interval tree + spatial hit-testing |
| `rui_events` | rui_core | event manager + focus manager |
| `rui_drawing` | rui_core, naylib, yaml | primitives, effects, theme system, text cache |
| `rui_scripting` | rui_core | file-based GUI automation (query/set) |
| `rui_widgets` | rui_core, rui_drawing | primitives, basic controls, containers |
| `rui` | all of the above | umbrella: App integrator + re-exports |

Local dev resolves packages by bare name via the root `config.nims` (`import rui`,
`import rui_core`, ...). Build for graphics: `nim c -r examples/<name>.nim`.

---

## What works

### Core and rendering
- `newApp(...)`, `setRootWidget`, `setStore`, `run` (`start` is an alias),
  `setTheme`, `enableScripting`, text-cache helpers, and window helpers
  (`setWindowSize`, `setWindowResizable`).
- Two-pass frame: layout pass arranges/creates children; render pass draws dirty
  widgets to a `RenderTexture2D` and composites bottom-up; clean widgets reuse
  their cached texture. Tree-level `anyDirty` fast-path.
- Window resizing with `resizable` + `minWidth`/`minHeight` (default min 320×240).

### Widget DSL
- Both macros in `rui_core` generate type, constructor, reactive `state`
  (auto-wrapped `Link[T]`), `Option[proc]` actions, event routing, and lifecycle
  methods. `definePrimitive` generates `render`; `defineWidget` generates `layout`
  (+ a default child-compositing `render`) and auto-generates `getTypeName`.

### Widgets that compile and work
**Label, Rectangle, Circle, Button, Checkbox, RadioButton, Slider, ProgressBar,
Hyperlink, Image, VStack, HStack, ZStack, ScrollView.**

> Many half-finished/unwired widgets (combobox, listview, tabcontrol, menus,
> dialogs, data grids, etc.) were removed during cleanup; they remain in git
> history if needed.

### Reactivity
- `Link[T]`: `get`/`set`/`value`, direct-widget-reference dependency tracking,
  O(1) dirty-marking on change, optional `onChange`.

### Theme system
- State × intent lookup with cascading resolution, `Option` props, focus-ring and
  effect fields. Built-in themes; `light` is default. Runtime switching via
  `app.setTheme(name|theme)`.

### Managers
- Event manager: time-budgeted processing (8 ms default) with `epReplaceable /
  epDebounced / epThrottled / epBatched / epOrdered` coalescing.
- Focus manager: focus state, keyboard routing, `onFocus`/`onBlur`.
- Hit-testing: interval-tree spatial queries, rebuilt after each layout pass.

### Scripting
- File-based protocol for automated testing: address widgets by `stringId` /
  CSS-like path, `handleScriptAction`/`getScriptableState` per widget,
  `blockReading` privacy flag, on-screen "SCRIPTING" indicator. The
  `rui_scripting` package also ships a `client.nim` driver and examples.

---

## Roadmap (designed, not wired)

### Reactive `bind` operator
`Link[T]` has the machinery (`addDependent` + O(1) dirty-marking), but the `bind`
DSL sugar that auto-registers a widget as a dependent and re-reads on change is
**not implemented**. Today widgets read store values at build/layout time;
`addDependent` can be called manually.

### Pango/Cairo text rendering
A Pango binding exists and is used only to *render glyphs and compute text
offsets*, handing the result to raylib as a 2D texture. Wiring it into `Label`
(which still uses raylib `drawText`) for full Unicode / bidirectional /
complex-script text is a roadmap item. Note: an earlier experiment tried to keep
GPU-side cached texture refs and manage their cleanup manually — that was a
premature optimization and was left half-finished. naylib's RAII textures now
handle GPU memory automatically (the main loop caches one `RenderTexture` per
widget and frees it by resetting the `Option`), so a Pango backend can lean on
RAII rather than hand-rolled cleanup.

---

## Known issues / caveats

- **Composite widgets rebuild children each layout pass.** Several composites
  (e.g. `Button`) do `children.setLen(0)` and recreate children every layout.
  Correct for immediate-mode, but allocation-heavy; a future optimisation could
  diff/reuse children.
- **Hit-test tree is fully rebuilt** after every layout pass. `previousBounds`
  exists to enable incremental updates later; not yet used.
- **Stale-cache risk in compositing:** a child content change marks the child
  dirty and the parent `layoutDirty`, but not the parent `isDirty`, so a same-size
  child change may not recomposite into the parent texture. Ancestor dirty
  propagation is a known follow-up.
- **Label centering / measurement is approximate** pending real text measurement.
- **No license chosen yet** (`.nimble` files have a TODO placeholder).

---

## Testing strategy

There is no headless mode (it was an experiment, deferred as a future feature).
Validate by:

1. **Running visually** against the naylib graphics build (`nim c -r examples/...`).
2. **Using the scripting subsystem** to query/set widget values programmatically
   (`enableScripting(dir)`), driving interactions and verifying state.

---

## Next steps

1. Wire the `bind` DSL operator onto the existing `Link[T]` dependency machinery.
2. Fix ancestor dirty-propagation so child content changes recomposite correctly.
3. Reduce per-frame child re-allocation in composites; add real text measurement.
4. Wire the Pango backend into `Label` behind the existing drawing/text-cache API.
5. Publish the `packages/*` as separate repos (see SPLITTING.md) when ready.
