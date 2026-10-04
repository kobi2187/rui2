# RUI2 — TODO roadmap

What it takes to go from "a solid alpha" to **the GUI toolkit people pick**.
Ordered by priority, and within a priority by dependency. Every item names the
files it starts in and how to know it is done. [STATUS.md](STATUS.md) says what
works today; [ROADMAP.md](ROADMAP.md) is the phase history.

**Where RUI2 is already strong:** retained widgets with per-widget texture
caching, push-based `Link[T]` reactivity with O(1) invalidation, Pango text
(Unicode, BiDi, shaping), 48 widgets, keyboard focus groups, a scripting
protocol plus headless frames for testing, and a codebase under a complexity
gate. The gaps below are what stands between that and Qt/Flutter-level trust.

## Principles (they decide what gets built, and in what order)

1. **Instantaneous and beautiful.** A change must land inside one frame at
   10,000 widgets, and every widget ships with a considered look in every
   brand. Speed is measured (`tools/bench.sh`, docs/PERFORMANCE.md), not
   assumed.
2. **Full Unicode text.** Shaping, BiDi, emoji and combining marks, CJK input
   (IME), grapheme-aware editing. Text is never second-class.
3. **Accessibility: low priority.** Screen-reader support is not a goal for
   now (#17 stays parked); don't spend effort there.
4. **Integrates, but looks the same everywhere.** Drag and drop in and out,
   clipboard, system dark/light preference -- yes. Native file dialogs and
   native-looking widgets -- no: the drawn FileDialog stays, so an app looks
   identical on every platform.
5. **Open to new widgets, each small and focused.** Innovate freely: nothing
   has to copy a platform widget, and there are tons in the box. A widget does
   one job; the ceiling is a chart or a kanban board, and only data-backed
   grids and tables are bigger. Anything larger (a text editor with
   highlighting, a rich-text editor) is built from our primitives by the app,
   not shipped.
6. **Lean on raylib.** It is a game engine: batching, double buffering,
   shaders, render textures, MSAA, texture filtering, event waiting. Reuse
   what it has before writing our own (what it does *not* cull or smooth for
   us is listed under #8 and #18). Animation and effects use it directly.
7. **Preferences are the user's; themes are the author's.** How the person
   works with applications (navigation keys, motion, scroll speed, caret
   blink, double-click speed) is one per-user file shared by every RUI app,
   with stable defaults an app cannot override. Looks and the app's own
   behaviour are the theme, set by the author. docs/preferences.md.
8. **The DSL is the API, and it stays transparent.** `ui:` is plain sugar over
   constructors, props are named and typed, there is no hidden state. A new
   user should be able to read an example and write the next one.

Legend: **P0** blocks real apps · **P1** expected of any modern toolkit ·
**P2** differentiators · **P3** breadth and ecosystem.

---

## P0 — Blocks real applications

### 1. Measure/arrange layout *(defect fixed; the redesign is P1 now)*
`bounds` is both "the size my parent assigned" and "the size I computed last
frame", told apart by `if bounds.width <= 0`. After one layout a self-sized
container looked assigned, so it never re-grew when content was added.
- [x] **The defect.** Every DSL `layout` is bracketed by `beginSelfSizing` /
  `endSelfSizing` (`rui_core/types.nim`): a dimension still equal to what the
  widget gave itself last time is reset to 0 and re-measured. Stacks now grow
  and shrink with their children; 8 examples render pixel-identical to
  before. Residual risk: a parent assigning *exactly* the child's previous
  self-size reads as self-sized -- the redesign below removes the guess.

The redesign, for min/max constraints and a cheaper second pass:
- [ ] Add `measure(widget, Constraints): Size` as the first pass. The method
  already exists in `rui_core/types.nim` and nothing calls it. Leaves measure
  content; containers measure children and sum.
- [ ] Make `layout` the arrange pass: it receives a final rect and never infers
  "was I assigned?" from a zero.
- [ ] Put explicit sizing on `Widget`: `width`/`height: Option[float32]`,
  `minSize`/`maxSize`. Fixed size becomes a declaration, not a side effect.
- [ ] Port the stacks, Column and ScrollView first, then sweep the
  `bounds.x <= 0` idiom out of all widgets (`grep -rn "bounds.width <= 0"`).
- [ ] Cache measurements per (widget, constraints) and invalidate on
  `layoutDirty`, so the extra pass costs nothing when nothing changed.
- **Done when:** no widget infers "assigned?" from a zero, and min/max
  constraints are honoured by every container.

### 2. Modifier keys on the event ✅
- [x] `GuiEvent.mods: set[KeyMod]`, stamped once per poll by the event source.
- [x] The 7 live-keyboard reads (Shift+arrow, Ctrl-click in five widgets, the
  focus manager's Shift+Tab) ask the event instead.
- [x] `parseKeyChord("Ctrl+Shift+Z")`; the test-key injector takes chords, and
  the scripted UI run checks Shift+Tab through a real window.
- [x] Key and character queues are drained each frame -- one of each used to
  be read, dropping keystrokes that shared a frame.

### 3. Text-editing essentials *(mostly done)*
- [x] **Clipboard.** Ctrl+C/X/V through a seam (`rui_core/clipboard.nim`):
  in-memory for tests, the system clipboard once a window opens. Pastes are
  fitted, not refused: line breaks become spaces in a single-line field, and
  `maxLength` / `maxLines` truncate.
- [x] **Undo/redo.** `EditHistory` in `text_buffer.nim`; a typing run is one
  step (undo takes back a word), Ctrl+Z / Ctrl+Shift+Z / Ctrl+Y, selection
  restored with the text.
- [x] **Word navigation.** Ctrl+Left/Right (Shift extends), Ctrl+Backspace /
  Ctrl+Delete, Ctrl+Home/End, Ctrl+A; double-click selects a word and
  triple-click the line. Ctrl+Enter submits a multi-line area.
- [ ] Word boundaries from Pango's `PangoLogAttr` for scripts written without
  spaces (Thai, CJK). Today a word is a run of letters/digits/underscores,
  per rune -- right for alphabetic scripts, including Hebrew and accented Latin.
- [x] **Caret and scroll.** Text scrolls to keep the caret in view --
  sideways in a TextInput, both ways in a TextArea -- clipped to the frame by
  source rectangle (`drawTextPangoClipped`). No scrollbar or wheel scrolling
  on a TextArea yet; it scrolls by caret.
- [ ] **Wrap while editing.** `wrap` and `markup` apply to display text only;
  an editable TextArea lays out one visual line per `\n`. Caret movement
  over soft-wrapped lines needs Pango's line iterator.
- [x] **Mouse cursor shapes.** `Widget.cursorShape` (rui's own `CursorShape`,
  inherited from ancestors), applied by the app when the hovered widget's
  shape changes: I-beam over editable text, a hand over links.
- **Done when:** a user can edit a paragraph in TextArea without reaching for
  another program.

### 4. Idle efficiency ✅ *(one follow-up)*
- [x] A frame that paints nothing is not presented: no draw, no swap, input
  polled and the rest of the frame slept. Measured on a 42-widget window:
  31% of a core → about 1% (`App.idleWhenClean`, default on).
- [x] Repaint timers (`rui_core/repaint_timers.nim`): a widget asks to be
  drawn again later. The caret uses it -- it used to freeze in whichever
  blink phase the last edit left it.
- [ ] Block instead of sleeping per frame (GLFW `waitEventsTimeout` until the
  next timer), and wake on Link sets from other threads with a posted event.

---

## P1 — Expected of any modern toolkit

### 5. Layout completeness *(mostly done)*
Positioning belongs to the layout primitives: widgets *ask* for a size and
the containers place them. No example writes `bounds` any more.
- [x] **Size requests** -- `frame(width, height, minWidth, ..., maxHeight)`,
  `unframe`, `flex(weight)`, chaining and usable inside `ui:`. A request
  beats stretch, min/max clamp either way (`Widget.sizeRequest/sizeMin/sizeMax`).
- [x] **Flutter's layout model and names**, restoring the original
  `modules/layout` design and its arithmetic (`rui_core/layout.nim`):
  `Row` / `Column` / `Flex` (`mainAxisAlignment`, `crossAxisAlignment`,
  `mainAxisSize`), `Expanded` / `Flexible` / `Spacer`, `Padding`,
  `SizedBox`, `ConstrainedBox` (`BoxConstraints`), `Align` / `Center`
  (`Alignment.topLeft` ...), `Container` + `BoxDecoration`, `Stack` +
  `Positioned`, `Wrap` (`runSpacing`), `Table` (`Fixed`/`Intrinsic`/
  `FlexColumnWidth`), `GridView`, `EdgeInsets.all/symmetric/only`, and
  `Dock` from the old design. VStack/HStack/ZStack stay as shorthands.
  Covered by `tests/test_flutter_layout.nim`.
- [x] Cached widget textures composite on whole pixels, so centred
  content is not resampled into blurry, doubled text.
- [x] **Theme geometry** -- borders and widths, not only colours: stroke
  width, radius, padding, caption weight/case, hard drop shadow, control
  height, indicator/track/thumb/progress sizes (`BrandSpec`, `ThemeProps`,
  `Theme.metrics`, theme files). Honoured by Button, TextArea/TextInput,
  Checkbox, Radio, RadioGroup, Slider, ProgressBar, ComboBox. Showcased by
  the `punch` and `hairline` brands.
- [x] Geometry in the remaining widgets: list/tree/table/menu row height
  (`metrics.rowHeight`), tab/menu/tool/status bar and table header height
  (grown to the control height), scrollbar thickness, tab indicator and
  group-box/panel strokes, radius and padding, table cell text size.
- [ ] Table cells spanning several columns or rows.
- [x] **SplitView** with a draggable divider (`layout/split.nim`; themed thickness, min pane sizes, `onResize`).
- [ ] Right-to-left layout mirroring, driven by the text direction Pango
  already reports.
- [x] **An overlay layer** (`rui_core/overlays.nim`): widgets drawn above the
  whole tree, laid out and rendered by the App and composited after the root.
  Tooltip now wraps its target, waits on a repaint timer and floats its tip
  there -- it could never show before (no hover-event producer, the pointer
  was never over it, and `drawTooltip` drew outside its own texture).
- [ ] Hit-test the overlay layer first, then move Menu, ContextMenu and the
  ComboBox list onto it instead of growing their own bounds.
- [x] **ToolBar with captioned ToolButtons overlapped them** -- captions
  were measured at 9 px and drawn at the theme's ~14 px, and the bar forced
  its 32 px height on 43 px buttons. Both fixed.

### 5a. Themes: one obvious format, real inheritance *(next)*
- [x] The theme file format, written down (docs/themes.md), with every key
  validated: an error names the file, the key and the likely fix. Unknown
  intents and states are errors rather than silent defaults.
- [x] Inheritance: `extends` chains through registry and sibling files, cycles
  and unknown names are errors, and `derive` copies a whole theme (it used to
  drop the control metrics).
- [ ] `describe(theme)`: print what each level of an inheritance chain changed.
- [ ] A theme set in code and a theme in a file are the same thing, and
  round-trip: `theme.toYaml()` writes what `parseTheme` reads.

### 5b. Branded themes ✅ *(follow-ups open)*
- [x] `brandTheme(BrandSpec)` (`rui_drawing/brand_themes.nim`): accent,
  canvas, surface, text, border, radius, font in; a complete theme out --
  every intent and state, hovers and presses leaning toward the accent, a
  solid primary (Info) action, and the typography as the default family.
- [x] Eight shipped brands: daylight (the new `light`), midnight (the new
  `dark`), aurora, ocean, forest (serif), rose, ember, graphite. See
  `examples/widgets/theme_gallery.nim`.
- [x] A theme file takes a `brand:` section (the `BrandSpec` fields), with `base`/`states` overriding it.
- [ ] Theme transitions (fade between palettes) once animation exists (#9).
- [ ] A per-brand elevation/shadow token for cards and popups.

### 6. Reactivity you can write declaratively *(medium)*
- [ ] A `bind` word inside `ui:` — `TextInput(bind <-> store.name)` for two-way
  and `Label(bind store.count)` for one-way — lowering to `bindTo` plus the
  `onChange` write-back that apps write by hand today (`rui_core/ui_tree.nim`).
- [x] Derived links: `derive(a, b, proc(x, y): int = x + y)` (one to three
  sources, chainable), recomputed eagerly when a source changes and dirtying
  only their own dependents, and only on a real change.
- [ ] A `LinkSeq[T]` with insert/remove/move notifications, so ListView,
  DataTable and TreeView update rows incrementally instead of rebuilding.
- [x] Batched sets: `transaction: a.set(1); b.set(2)` announces each changed
  link once, after the block; nests; derived links recompute from the final
  values.

### 7. HiDPI *(medium)*
- [ ] Read `getWindowScaleDPI()` and keep layout in logical pixels. Render
  textures at physical size and give Pango the DPI (`pango_cairo_context_set_resolution`).
- [ ] Re-rasterize the glyph cache on scale change (moving between monitors).
- **Done when:** text is sharp on a 2× display and sizes match 1×.

### 8. Performance you can prove *(medium)*
- [x] A benchmark (`tools/bench.sh`, `benchmarks/bench.nim`, results and
  findings in docs/PERFORMANCE.md): 1k/10k widgets, `--gate` fails on a
  budget breach. Found and fixed a text-measure cache that wiped itself when
  full (10k layout 164 -> 21 ms).
- [ ] Run `tools/bench.sh --gate` in CI and record the `--json` line.
- [x] Render textures without the unused 32-bit depth buffer (about half the
  GPU memory per widget; full repaint of 1k widgets 22 -> 13 ms).
- [ ] Widgets taller than the GPU texture limit (16384 px) cannot be cached:
  tile them, or clip to the viewport.
- [x] Viewport culling: widgets wholly outside the window and every scroll
  viewport are skipped, and painted when scrolled in (`renderView`,
  `Widget.culled`; GL-checked in tests/gl/culling.nim). 10,000 widgets:
  full repaint 877 -> 4 ms. Layout and hit-testing are not culled yet.
- [ ] What raylib already does, and what it does not. It batches draw calls
  (so fewer texture switches is faster: draw cheap leaves straight into
  their parent instead of caching each), double-buffers, and clips to the
  framebuffer. It does *not* cull 2D draws, and its BeginScissorMode is wrong
  inside render textures (see scrollview.nim), which is why culling is ours.
  Idle waiting stays a sleep: raylib's EnableEventWaiting blocks with no
  timeout, so it would starve repaint timers (caret blink) and animations.
- [ ] Incremental hit-testing. `HitTestSystem.updateWidget` exists, but
  `app.rebuildHitTestTree` still clears and rebuilds every frame.
- [ ] A texture-memory budget. Every widget owns a `RenderTexture2D`, so large
  trees exhaust VRAM. Cache only containers and expensive leaves, and draw
  cheap leaves directly into their parent.
- [ ] Clip and cull children outside the viewport before layout and render,
  not only at composite time.

### 9. Animation and effects *(medium; needs #4; built on raylib)*
- [x] Rounded corners and edges that are actually smooth: a signed-distance
  shader draws every box (fill + border, one pass, antialiased at any radius;
  `primitives/sdf.nim`, GL-tested).
- [ ] The same shader for soft drop shadows, glow and blur.
- [x] `Animated[T]` with easing curves, driving frames only while something
  moves (`rui_core/animation.nim`); Button fades its colours between states
  over the theme's `transitionMs` (120 by default, 0 = instant), and a theme
  switch snaps. Next: the other controls, `Animated` for layout (expand /
  collapse), and a `Transition` helper for widgets entering and leaving.
- [ ] Effects through raylib shaders (drop shadow, glow, blur, gradient,
  frosted glass), exposed as theme tokens and a small `Effect` set a widget
  can opt into, never as per-widget GL code.
- [ ] `Animated[T]`: a Link that tweens toward its target with easing curves,
  keeping the loop awake only while it runs.
- [ ] Theme-level transitions for hover/press/focus colour changes, so state
  changes fade rather than snap.
- [ ] Animated layout changes (expand/collapse, list insertions) driven by the
  measure pass from #1.

---

## P2 — What would make RUI2 stand out

### 11. Input methods and international text *(medium; needs #3)*
- [ ] IME pre-edit (composition) display for CJK input. This needs platform
  text-input events that GLFW does not surface, so it probably means SDL3 as
  the backend or a GLFW patch.
- [ ] Grapheme-cluster caret movement (emoji ZWJ sequences, combining marks),
  using Pango's cursor-position attributes instead of UTF-8 boundaries.
- [ ] BiDi caret movement: visual rather than logical order for Left/Right in
  mixed Hebrew/English text.

### 12. Developer experience *(medium)*
- [ ] An in-app inspector overlay (F12): the widget tree, bounds, dirty flags
  and theme props, built on the `-d:ruiInspect` verbs that already exist.
- [ ] Theme hot-reload: watch the YAML theme files and re-apply on save.
- [ ] A widget **gallery** app with every widget and every state, doubling as
  the visual regression target (screenshot diffs in CI).
- [ ] API docs generated by `nim doc` and published to GitHub Pages, plus a
  tutorial: counter → form → data app.
- [ ] A `nimble init`-style app template.

### 13. Platform integration *(medium)*
- ~~Native file dialogs~~ -- decided against: the drawn FileDialog stays, so
  the look is the same on every platform.
- [ ] OS drag-and-drop in (`isFileDropped`) wired into `DragDropArea`.
- [ ] Follow the system dark/light preference and accent colour.
- [ ] Multiple windows. raylib owns a single window, so this is a backend
  decision; decide it together with #11.

---

## P3 — Breadth and ecosystem

### 14. Widgets
- [ ] DataTable: edit filters from the UI (the strip only displays them).
- [ ] Date/time picker, colour picker, toasts/notifications, a docking layout.
- [ ] New widgets, free of platform precedent (principle 5): command palette,
  tag/chip input, rating, knob/dial, range slider, sparkline, calendar
  heat-map, kanban board, node graph, breadcrumb, stepper/wizard, avatar
  stack, skeleton loaders, rich tooltip/popover, pull-to-refresh list,
  masonry grid, timeline (exists: extend), toggle/segmented controls.
- ~~Rich-text and code editors~~ -- out of scope (principle 5). `TextArea`,
  `text_content` and the text primitives are what an app builds one from.
- [x] `Plot`: lines, areas, bars and scatter on round axes with a grid and
  legend, in the theme's colours (`modern/plot.nim`, pure scale helpers tested).
- [ ] A `KanbanBoard` of cards -- with `Plot`, the largest single widgets we ship.

### 15. Code health
- [ ] Bring rui_drawing (11), rui_hittest (5, of which interval-tree
  rebalancing is essential) and rui_scripting (10) under `nimtools cyc --gate 5`.
- [x] Dropped the `_v2` / `_refactored` file suffixes (`button.nim`, `event_manager.nim`).
- [ ] Rename the enum values that collide (`Info`/`Warning` exist in two
  rui_drawing enums; `KeyboardKey.Menu` against the Menu widget).
- [ ] The remaining drawing TODOs: the three-ring focus effect, and rounded and
  radial gradients via shaders (`rui_drawing/effects/rect_effects.nim`).

### 16. Packaging and release
- [ ] CI on Windows and macOS. Pango on Windows means MSYS2 bundling, so
  document it or ship prebuilt DLLs.
- [ ] Split into seven repos per SPLITTING.md
  ([#35](https://github.com/kobi2187/rui2/issues/35)) and publish to Nimble
  ([#36](https://github.com/kobi2187/rui2/issues/36)).
- [ ] A CHANGELOG, a semver policy, and a tagged `v0.2.0`.

---

### 17. Accessibility *(large -- low priority for now)*
Deferred by the project owner: important eventually, not now.
- [ ] Integrate [AccessKit](https://github.com/AccessKit/accesskit) through its
  C API: map the widget tree to AccessKit nodes (role, name, value, bounds,
  actions) and route its action requests back as events. It speaks AT-SPI,
  UIA and NSAccessibility.
- [ ] Add `accessibleName` / `accessibleRole` to `Widget`, defaulting from the
  type and text. The scripting bridge's `getScriptableState` already holds
  most of the data.
- [ ] High-contrast themes and a minimum focus-ring contrast check in
  `test_theme`.

---

## Suggested order

```
#2 mods ─┬─ #3 text editing ─── #11 IME/graphemes
         │
#1 measure/arrange ─┬─ #5 layout ─── #9 animation
                    └─ #8 performance
#4 idle ─────────────── #9 animation
#6 bind (independent)     #7 HiDPI (independent)
#16 split ─── publish ─── v0.2.0   (MIT chosen)
#17 accessibility -- low priority, later
```

#2 and #4 are small and unblock the most. #1 is the one architectural change
left, and it is cheaper now than after more widgets are written against the
`<= 0` idiom.


### 18. Keyboard navigation you can rebind
Two axes on two sets of keys -- within a container, and between containers --
set by the *user* in their preferences file (docs/preferences.md), not by apps.
- [x] `KeyMap` of five actions (next/prev within a group, leave, next/prev
  group), each with any number of chords (`"Ctrl+Tab"`), exact matching,
  conflict check, loaded from `~/.config/rui/preferences.yaml`
  (`RUI_PREFERENCES` overrides); `setGroupKeys`/`setNavigationKeys` remain as
  wrappers. Also in the file: motion (reduced = no animations), scroll speed,
  caret blink, double-click speed, colour-scheme preference.
- [x] `FocusScope` declares a container a focus group in the DSL.
- [ ] Apps start on the theme matching `prefs.colorScheme` (and follow the OS
  when it is `system`).
- [ ] A small in-app keyboard help overlay listing the active bindings.
- [ ] Windows/macOS config path check in CI.
