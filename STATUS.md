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
| Focus manager (focus tracking, keyboard routing) | ⚠️ Partial — Tab works; three known defects |
| Keyboard navigation between/within containers | 🚧 Roadmap — no key scoping exists |
| Hit-testing (interval trees, O(log n)) | ✅ Working |
| Scripting subsystem (file-based query/set) | ✅ Working (testing tool) |
| naylib port, graphics-only build | ✅ Done — `nim check` clean |
| 7-package split under `packages/` | ✅ Done |
| Widget library (47 widgets) | ✅ Working — see the table below |
| Unit test suite (8 suites) + 26 compiled examples | ✅ Working |
| Scripted UI tests under Xvfb | ⚠️ Skipped — Xvfb not installed in CI |
| Text rendering | ✅ Pango-backed — real font metrics, glyph cache |
| Pango/Cairo text (Unicode/BiDi/shaping) | ✅ Working — wired into `Label`, `TextInput` and every draw path |
| One unified text widget (Label/TextInput/TextArea by flags) | 🚧 Roadmap — the three are still separate; no TextArea |

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
- **`export raylib` is wholesale** ([#23]) — every raylib enum field is in scope
  in every widget, which already costs several qualification workarounds.
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

1. **Unit tests** — `tests/test_*.nim`, 8 suites, no GL context required. Layout,
   binding, theming, hit-testing, text metrics, keyboard navigation and the
   widget library are all CPU-side.
2. **Example compiles** — a real `nim c` over all 26 examples, not `nim check`:
   naylib's GPU types are move-only and those failures only appear in a full
   build.
3. **Scripted UI tests** — drives a real window on Xvfb through the file-based
   scripting protocol. **Currently skipped**: Xvfb is not installed ([#36]).

Complexity is gated with `nimtools cyc --gate 5` over `rui_widgets`. Note that
cyc cannot see inside `definePrimitive` bodies — they are macro arguments, not
routines — so widget logic must be extracted into named procs to be measured.

[#36]: https://github.com/kobi2187/rui2/issues/36

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
