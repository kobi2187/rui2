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
| Unit test suite (20 suites) + 32 compiled examples | ✅ Working — see "Testing strategy" |
| Scripted UI tests under Xvfb | ✅ Running, in CI too — 24 assertions |
| Frame pipeline testable headlessly (`app.stepHeadless`) | ✅ Working — event-source seam |
| Cyclomatic complexity | ⚠️ 4 of 7 packages pass `nimtools cyc --gate 5`; 26 routines over in the other 3 |
| Text rendering | ✅ Pango-backed — real font metrics, glyph cache |
| Pango/Cairo text (Unicode/BiDi/shaping) | ✅ Working — wired into every text widget and draw path |
| Unicode text *input* (typed codepoints, UTF-8-safe caret) | ✅ Working — no IME composition yet |
| Flex growth in stacks (`Widget.flexGrow`, `Spacer`) | ✅ Working |
| Scripting selectors by type (`Button`, `form/Label`) | ✅ Working |
| Clipboard, undo/redo, word editing, cursor shapes | ✅ Working |
| HiDPI scaling, accessibility, IME composition | ❌ Not started — see [TODO.md](TODO.md) |
| One text widget: TextArea, limited by properties into Label / TextInput | ✅ Working — `input/textarea.nim` over `text_content.nim` |
| Hover-vs-focus preference owned by the theme | ✅ Working — `Theme.statePreference`, per control role |
| License | ✅ MIT |
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
HStack has no cross-axis alignment, so a Label beside a taller TextInput sits
top-aligned (Column has alignment; the stacks do not).

### Reactivity
- `Link[T]`: `get`/`set`/`value`, direct-widget-reference dependency tracking,
  O(1) dirty-marking on change, optional `onChange`.
- `link.bindTo(widget, apply)` — one-way binding; `apply` re-runs once per
  change, before the next layout. Several links can drive one widget. Two-way
  binding is written by hand (`onChange = proc(v) = link.set(v)`); a `bind`
  word in `ui:` is on the roadmap.

### Theme system
- State × intent lookup with cascading resolution, `Option` props, focus-ring and
  effect fields. Built-in themes; `light` is default. Runtime switching via
  `app.setTheme(name|theme)`.

### Managers
- Event manager: time-budgeted processing (8 ms default) with `epReplaceable /
  epDebounced / epThrottled / epBatched / epOrdered` coalescing.
- Focus manager: focus state, keyboard routing, `onFocus`/`onBlur`, Tab/Shift+Tab
  cycling with wrap, configurable navigation keys (`setNavigationKeys` accepts
  Tab, arrows, vim-style — any key set). Opt-in tab stops (`focusable`), the
  chain rebuilt when the tree changes, and focus groups: Tab between groups,
  arrows within, Escape out. Covered by `test_keyboard_nav` / `test_focus_groups`.
- Hover tracking: `hovered` is set on enter and cleared on leave
  (`rui_events/hover_tracker.nim`), so hover styles and Tooltip un-latch.
- Hit-testing: interval-tree spatial queries, rebuilt after each layout pass.

### Scripting
- File-based protocol for automated testing: address widgets by `stringId` /
  CSS-like path, `handleScriptAction`/`getScriptableState` per widget,
  `blockReading` privacy flag, on-screen "SCRIPTING" indicator. The
  `rui_scripting` package also ships a `client.nim` driver and examples.

---

## Recently completed

- **Text editing.** Clipboard (through a seam tests can replace), undo/redo
  with typing grouped by word, word movement and deletion, Ctrl+A,
  double/triple-click selection, and the I-beam and link-hand cursors.
- **Modifiers on the event.** `GuiEvent.mods`; Shift+Tab, Shift+arrow and
  Ctrl-click are driven by the event, so scripts and headless tests reach
  them. Key queues are drained per frame (fast typing used to drop keys).
- **Idle.** An unchanged window is not redrawn: ~31% of a core → ~1%.
  Repaint timers let time-driven widgets ask for a frame; the caret blinks
  again.
- **One text widget.** Label, TextInput and TextArea are one `TextArea`
  limited by properties (`editable`, `multiline`, `maxLength`, `maxLines`,
  `framed`, `disabled`). `Label`/`TextInput` are aliases with their own
  constructors, and `getTypeName` reports the role, so selectors still work.
  A non-editable one takes no input, so a Button's caption cannot eat clicks.
- **The theme owns hover-vs-focus.** Widgets declare a role (`crText` /
  `crPointer`); `Theme.statePreference` decides which state wins for each,
  read from the in-memory `currentTheme` on every lookup. Theme files may set
  `statePreference: {text: focus, pointer: hover}`. Checkbox and RadioButton
  are now `crPointer` (hover shows over focus), which they are.
- **MIT license**, in the root and in each package.
- **Flex growth.** `Widget.flexGrow` (CSS `flex-grow` semantics) and a Spacer
  that finally does what it says: a VStack/HStack with a fixed size hands its
  leftover space to flex children by weight. `rui_core/flex.nim`.
- **Unicode input.** `GuiEvent.rune` carries the typed codepoint (it was
  truncated to one byte), and TextBuffer's caret, Backspace and Delete step over
  whole UTF-8 characters. `maxLength` counts characters.
- **TextArea goal column.** Up/Down through a short line comes back to the
  column it started from.
- **Slider captions.** `textLeft`/`textRight` were never drawn and the value
  was drawn outside the widget's texture; both now sit inside the bounds.
- **Type selectors.** `Button`, `form/Label`, `form/**/Button` in scripting
  paths — type segments parsed but always matched nothing.
- Earlier: Pango everywhere, ancestor dirty propagation, the 35 restored
  widgets, hover un-latching, opt-in tab stops, focus groups, `ui:` syntax,
  plain-closure handlers, the `app.nim` split and headless frames.

---

## Known gaps

Verified against the code. The prioritised plan is in [TODO.md](TODO.md).

- **A content-sized container never re-grows.** `bounds` is both "the size my
  parent gave me" and "the size I computed last frame", and every widget tells
  them apart with `if bounds.width <= 0`. After its first layout a VStack that
  sized itself looks assigned, so adding a child later leaves it at the old
  height and the child overflows. The fix is a measure/arrange split (the
  unused `measure(Constraints)` method is where it starts) — TODO.md P0.
- **Tooltip never shows** — nothing generates the hover event it waits for,
  and as a sibling of its target the pointer is never over it. Needs an
  overlay layer (TODO.md #5).
- **No IME composition** — typed codepoints arrive, but pre-edit text for
  CJK input methods is not shown.
- **No HiDPI scaling** — nothing reads the monitor's scale factor.
- **No accessibility** — no screen-reader bridge (AT-SPI / UIA / NSAccessibility).
- **No animation system** — transitions are instant.
- **No mouse-cursor shapes** — the I-beam over text, resize arrows, etc.

---

## Testing strategy

`./tools/run_tests.sh` does three things:

1. **Unit tests** — `tests/test_*.nim`, 20 suites, no GL context required.
   Layout, binding, theming, hit-testing, text metrics, keyboard navigation,
   focus groups, the widget library, and — since the event-source seam — the
   frame pipeline itself.
2. **Example compiles** — a real `nim c` over all 32 examples, not `nim check`:
   naylib's GPU types are move-only and those failures only appear in a full
   build.
3. **Scripted UI tests** — drives a real window on Xvfb through the file-based
   scripting protocol, 32 assertions. Runs locally and in CI.

53 green as of this writing (20 unit suites, 32 example builds, the scripted UI run).

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

The prioritised, step-by-step plan is [TODO.md](TODO.md); the phase history is
[ROADMAP.md](ROADMAP.md). In short: text-editing essentials (clipboard, undo,
IME), then layout completeness (alignment, grid, min/max), then platform
polish (HiDPI, cursors, accessibility), then packaging and a 0.2 release.
