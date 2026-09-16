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
| `Link[T].bindTo` (widget follows a Link, repainting on change) | ✅ Working — see `examples/widgets/binding.nim` |
| Theme system (ThemeState × ThemeIntent), runtime switching | ✅ Working |
| Event manager (time-budgeted + coalescing) | ✅ Working |
| Focus manager (focus tracking, keyboard routing) | ✅ Working — opt-in tab stops, chain rebuilt on tree change |
| Keyboard navigation between/within containers | ✅ Working — focus groups: Tab between, arrows within, Escape out |
| Hit-testing (interval trees, O(log n)) | ✅ Working |
| Scripting subsystem (file-based query/set) | ✅ Working (testing tool) |
| naylib port, graphics-only build | ✅ Done — `nim check` clean |
| 7-package split under `packages/` | ✅ Done |
| Widget library (48 widgets) | ✅ Working — see the table below |
| Unit test suite (18 suites) + 32 compiled examples | ✅ Working — 51 green |
| Scripted UI tests under Xvfb | ✅ Running, in CI too — 24 assertions |
| Frame pipeline testable headlessly (`app.stepHeadless`) | ✅ Working — event-source seam |
| Cyclomatic complexity | ⚠️ 4 of 7 packages pass `nimtools cyc --gate 5`; 26 routines over in the other 3 |
| Text rendering | ✅ Pango-backed — real font metrics, glyph cache |
| Pango/Cairo text (Unicode/BiDi/shaping) | ✅ Working — wired into every text widget and draw path |
| Text engine shared by Label / TextInput / TextArea | ✅ Working — `text_content.nim`; TextArea now exists |
| `ui:` block syntax for widget trees | ✅ Working — `VStack(spacing = 10.0): Label(...)` |
| Handlers as bare closures (`btn.onClick = proc() = ...`) | ✅ Working — no `some(...)`, no `{.closure.}` |

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

| Category | Widgets |
|----------|---------|
| Primitives | Label, Rectangle, Circle |
| Basic | Button, Checkbox, RadioButton, Slider, ProgressBar, Hyperlink, Image, ComboBox, IconButton, ListBox, ListView, NumberInput, ScrollBar, Separator, Spinner, ToolButton, Tooltip |
| Containers | VStack, HStack, ZStack, ScrollView, Column, GroupBox, Panel, RadioGroup, Spacer, StatusBar, TabControl, ToolBar |
| Input | TextInput |
| Menus | Menu, MenuBar, MenuItem, ContextMenu |
| Dialogs | MessageBox, FileDialog, FilePicker |
| Data | DataTable, DataGrid, TreeView |
| Modern | Canvas, DragDropArea, Timeline, MapWidget |

All of them construct, size themselves, answer the scripting bridge, and have a
runnable example under `examples/widgets/`. Covered by
`tests/test_restored_widgets.nim`.

> The 35 widgets deleted by `a4bcc18` as "dead code" were restored and ported in
> September 2026 — they had only ever been unreferenced because the aggregator
> modules had not caught up with the v2 DSL port.

Known gaps within the working set: `DataTable`'s filter strip *displays* the
active filter but cannot be edited through the UI (set `filters` from code);
`Tooltip` cannot hide until the hover defect below is fixed; `Spacer.flexGrow`
is inert because the stacks do not distribute leftover space yet.

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
- Focus manager: focus state, keyboard routing, `onFocus`/`onBlur`, Tab/Shift+Tab
  cycling with wrap, configurable navigation keys (`setNavigationKeys` accepts
  Tab, arrows, vim-style — any key set). Covered by `tests/test_keyboard_nav.nim`.
  **Three known defects**, see "Known defects" below.
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

### One unified text widget
Label, TextInput and TextArea should be the same widget with variants by
property (`editable`, `multiline`, `disabled`). Today the first two are separate
modules and TextArea does not exist. See [#30].

The Pango backend this depends on is **done** — see below.

[#30]: https://github.com/kobi2187/rui2/issues/30

---

## Recently completed

### Pango/Cairo text rendering ✅
Wired throughout, not just into `Label`. `measureText` uses real font metrics via
`measureTextPango`, which is what lets containers size to content and fixed the
approximate label centring. `TextInput` uses `cursorPosition` for caret geometry
and `indexFromPosition` for click-to-caret, replacing a loop that measured every
prefix of the string against raylib's 10-pixel bitmap font. Glyph textures are
cached with LRU eviction in `pango_text`, leaning on naylib's RAII rather than
the abandoned manual GPU-cache experiment.

### Ancestor dirty propagation ✅
A content change now marks `isDirty` up the direct ancestor line
(`markDirtyToRoot`, called from `link.nim` and the event handlers), so a
same-size child change recomposites into the parent texture correctly.

### The 35 restored widgets ✅
See the widget table above.

---

## Known defects

Verified, with a failing case or a grep behind each. Tracked as GitHub issues.

- **`hovered` is never cleared** ([#14]) — `app.nim:391` is the only write to the
  flag anywhere and it only ever sets `true`. Hover highlights latch on, and
  `Tooltip` can never hide once shown.
- **Every widget is a tab stop** ([#16]) — `collectFocusableWidgets` adds every
  visible+enabled widget, carrying its own `TODO: Add isFocusable field`. Tab
  lands on containers and static labels.
- **The focus chain is built once and never rebuilt** ([#17]) —
  `FocusManager.markDirty` and `widgetRemoved` exist and are called from nowhere.
  Widgets added after the first Tab are unreachable by keyboard.
- **No key scoping** ([#18]) — a container and its children cannot both use the
  arrow keys, which blocks two-level keyboard navigation.
- **`primitives/text_cache.nim` is dead** ([#15]) — 428 lines, zero callers, and
  `app.clearTextCache` / `getTextCacheStats` report on it rather than on the real
  glyph cache in `pango_text`.
- **Theme lookup has no seam** ([#21]) — 35 widget files hand-copy the same
  state ladder, `ThemeManager.getProps` has zero callers so the theme cache is
  never on the path, and `App.currentTheme` is written four times and read never.

## Caveats

- **Composite widgets rebuild children each layout pass** ([#31]) — `children.setLen(0)`
  and recreate every layout, so widget identity and per-child caches are lost.
- **Hit-test tree is fully rebuilt** after every layout pass ([#32]);
  `previousBounds` exists for incremental updates and is still unused.
- **Some enum names still need qualifying** ([#23]) — `rui_core` now exports a
  named list of raylib types rather than the whole module, but exporting an enum
  exposes its fields unqualified, so `KeyboardKey.Menu` still collides with the
  Menu widget and `KeyboardKey.Down`/`Up` with `ArrowDirection`. Separately,
  `Info` and `Warning` each appear in two of rui_drawing's own enums. Both need
  renames, not import changes.
- **No license chosen yet** ([#26]) — `.nimble` files have a TODO placeholder.

[#14]: https://github.com/kobi2187/rui2/issues/14
[#15]: https://github.com/kobi2187/rui2/issues/15
[#16]: https://github.com/kobi2187/rui2/issues/16
[#17]: https://github.com/kobi2187/rui2/issues/17
[#18]: https://github.com/kobi2187/rui2/issues/18
[#21]: https://github.com/kobi2187/rui2/issues/21
[#23]: https://github.com/kobi2187/rui2/issues/23
[#26]: https://github.com/kobi2187/rui2/issues/26
[#31]: https://github.com/kobi2187/rui2/issues/31
[#32]: https://github.com/kobi2187/rui2/issues/32

---

## Testing strategy

There is no headless mode (it was an experiment, deferred as a future feature).
`./tools/run_tests.sh` does three things:

1. **Unit tests** — `tests/test_*.nim`, 18 suites, no GL context required.
   Layout, binding, theming, hit-testing, text metrics, keyboard navigation,
   focus groups, the widget library, and — since the event-source seam — the
   frame pipeline itself.
2. **Example compiles** — a real `nim c` over all 32 examples, not `nim check`:
   naylib's GPU types are move-only and those failures only appear in a full
   build.
3. **Scripted UI tests** — drives a real window on Xvfb through the file-based
   scripting protocol, 32 assertions. Runs locally and in CI.

51 green as of this writing.

### Inspection: text for structure, pixels for appearance

A harness gets two channels. The screenshot is the honest answer for
appearance — a wrong colour, an upside-down composite, a font that failed to
load. For structure and geometry it is the wrong tool, so `-d:ruiInspect`
compiles in a read-only `inspect` verb:

```
<id> <selector> inspect visible     # where the widget lands after clipping
<id> * inspect hit <x> <y>          # what a click reaches, and where focus goes
<id> * inspect tree                 # the hierarchy, in a diffable order
<id> * inspect settle               # how much is still dirty
```

`visible` is the one that matters most: the `visible` **field** is a flag and
stays true for a widget clipped away, scrolled out of a viewport or off-window.
`inspect visible` reports the rectangle actually on screen and names the
ancestor doing the clipping.

Gated separately from `-d:ruiTestKeys` on purpose. These are read-only queries
about the framework and carry none of the objection input emulation does; a
harness can have one without the other. An ordinary build answers
`Inspection not available: build with -d:ruiInspect`.

### The frame pipeline is testable without a window

`app.stepHeadless()` is a frame with the render pass left out — input
collection, routing, layout, hit-testing — which is everything except the one
part that needs a GL context. Input comes from an `EventSource`:
`RaylibEventSource` in an app, `ListEventSource` in a test. See
`tests/test_frame.nim`.

### Complexity gate

`nimtools cyc --gate 5`.

| Package | Over the ceiling |
|---------|------------------|
| `rui_core` | 0 |
| `rui_events` | 0 |
| `rui_widgets` | 0 (205 routines in 79 files) |
| `rui` | 0 |
| `rui_drawing` | 11 — mostly `theme_file` parsing and the Pango/Cairo edge |
| `rui_hittest` | 5 — 4 of them `interval_tree`, rebalancing |
| `rui_scripting` | 10 — selectors, the command parser, the client |

The four clean packages are the ones this cleanup pass went through. The
remaining 26 have not been assessed one by one; `interval_tree.removeNode`
(cc=16) was examined during the architecture review and judged **essential**
complexity — interval-tree rebalancing does not decompose into smaller pieces
without becoming harder to read.

Note that cyc cannot see inside `definePrimitive` bodies — they are macro
arguments, not routines — so it reports "0 routines" for a file that is all
widget. Widget logic has to be extracted into named modules to be measured at
all, which is most of why `rui_widgets` is 79 files rather than 47.

---

## Next steps

Tracked as [GitHub milestones](https://github.com/kobi2187/rui2/milestones).

1. **Architecture & code health** — delete the dead text cache, fix the hover
   latch, give theme lookup a seam, collapse the cc=43 scripting bridge.
2. **Keyboard navigation** — `isFocusable`, chain invalidation, key scoping,
   then focus groups for navigation between and within containers.
3. **Phase 3, DSL ergonomics** — containers as template blocks, callbacks that
   accept a bare closure.
4. **Phase 4, Text** — fold Label, TextInput and TextArea into one widget with
   variants by property. The Pango backend they need is already wired.
5. **Phase 8, Packaging** — choose a license, pin dependency versions, then
   `git subtree split` the seven packages (see SPLITTING.md).
