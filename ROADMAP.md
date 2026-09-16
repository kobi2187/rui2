# RUI2 Roadmap

Ordered by dependency and leverage: correctness before features before
optimization. See [STATUS.md](STATUS.md) for what works today.

---

> **Tracking.** Phases with open work are [GitHub
> milestones](https://github.com/kobi2187/rui2/milestones); cleanup and
> housekeeping live in a local taskwarrior project (`task project:rui2 list`).

## Phase 0 — Lock in the foundation *(small, do first)*
- [x] **Compile-check CI** — done in `298fcfa`. Runs `nim check` on the 7 package
  barrels + examples.
- [ ] **Choose a license** — fill the `# license` TODO in all 7 `.nimble` files.
  ([#26](https://github.com/kobi2187/rui2/issues/26))
- [ ] **Pin dependencies** — record the `naylib`/`yaml` versions known to build.
  Currently building against naylib 25.42.0.
  ([#27](https://github.com/kobi2187/rui2/issues/27))

## Phase 1 — Rendering correctness ✅ *(done — `f71d59e`)*
Dirty marking now propagates up the direct ancestor line via `markDirtyToRoot`,
called from `link.nim` and the event handlers, so a same-size child change
recomposites into the parent texture. Original plan below for reference.

<details><summary>Original Phase 1 plan</summary>

The two-pass texture cache only repaints correctly if dirty-marking matches the
compositing model.
- **Mark dirty up the direct ancestor line only.** On a content change, set
  `isDirty` on exactly the path from the changed widget to the root — *not* its
  siblings. Today link/event changes mark the child `isDirty` but the parent only
  `layoutDirty`, so no ancestor re-composites and the screen shows a stale
  combined texture. (`rui_core/src/{link,main_loop}.nim`)
- **Re-composite parents from their children's caches.** When a dirty widget
  rebuilds its texture it asks each child for its cache and combines them: a clean
  child (and any unaffected subtree) returns its existing cached texture
  unchanged; only dirty children rebuild theirs (recursively). So just the changed
  leaf→root line is recomputed while every untouched subtree is reused — correct
  *and* fast. `renderPass` already composites all children's caches; the only
  missing piece is the upward `isDirty` marking above.
- **Verify visually:** change state, confirm the repaint reaches the screen and
  that sibling subtrees are not redrawn.
</details>

## Phase 2 — Make reactivity real *(medium — the headline promise)*
**Push-based, no per-frame polling.** A `Link[T]` holds direct refs to its
dependent widgets; on `set` it marks exactly those widgets dirty to the root
(Phase 1). A bound widget re-reads the value only when it actually re-renders
(once per change, because it's dirty) — it does **not** fetch the value every
frame, and clean widgets keep their cached texture.

`Link[T]` already has the machinery (`addDependent` + O(1) dirty-marking); only
the binding sugar is missing. Provide both entry points:
- **Manual** — `link.addDependent(widget)` (explicit; stays supported).
- **DSL "gui word" `bind`:**
  - `bind <-> store.x` — two-way, for editable widgets (TextInput/Checkbox/Slider):
    register as dependent **and** write back via `store.x.set(...)` on edit.
  - `bind store.x` (no arrow) — one-way display (Label, …): register as dependent;
    direction is implied by the widget being read-only. (Explicit `->`/`<-` are
    optional; pin one arrow convention — the old `yaml-ui` and `ARCHITECTURE` docs
    disagreed on what `<-` meant.)
- Implementation: the widget holds the `Link` and reads `.value` inside its
  render (which only runs when dirty), instead of snapshotting at build time.
- Proof: convert the counter to true `bind` (drop the manual `.get()` snapshot).

## Phase 3 — DSL & callback ergonomics *(medium — restores the "elegant" API)*
- **Container types as template blocks.** Containers become templates that take a
  body, so `VStack(spacing = 10): Label(...); Button(...)` works directly instead
  of `newVStack(...)` + `addChild`. This is the intended elegant surface.
- **Callback ergonomics.** `onClick` is `Option[proc]` and non-capturing handlers
  need `{.closure.}`; add overloads / a wrapper so a bare closure "just works."

## Phase 4 — Text *(large)*
- **One unified text widget, variants by property.** Label, TextInput, and
  TextArea are the same widget with different flags — build **one good text widget**
  and derive the rest:
  - `editable: bool` → Label (false) vs input (true)
  - `multiline: bool` → TextInput (false) vs TextArea (true)
  - `disabled: bool`, plus selection/cursor state when editable.
  RichText (styled runs) can extend it later.
- [x] **Wire the Pango binding into it** — done. `drawText` routes through
  `drawTextPango`, glyph textures are LRU-cached in `pango_text` on naylib RAII,
  and `TextInput` uses `cursorPosition` / `indexFromPosition` for caret geometry
  and click-to-caret.
- [x] **Real text measurement** — done. `measureText` uses `measureTextPango`,
  which fixed the approximate label centring and is what lets containers size to
  content.
- [x] **The shared text engine** — `rui_widgets/text_content.nim`. Label,
  TextInput and TextArea all measure and draw through it, so what is drawn is
  what was measured. **TextArea now exists.** The three surfaces stay separate
  rather than collapsing into one flag-carrying type; the reasoning and the open
  question are on ([#30](https://github.com/kobi2187/rui2/issues/30)).

## Phase 5 — Performance refinements *(medium — after correctness; measure first, don't over-optimize)*
- **Stop rebuilding children every layout pass** — composites like `Button` do
  `children.setLen(0)` + reallocate each layout; diff/reuse so identity and caches
  survive.
- **Incremental hit-testing** — `Widget.previousBounds` exists but is unused;
  update the interval tree on changed bounds instead of a full rebuild per frame.
- **Remove per-event `echo`** from the event loop (`rui/src/app.nim`).

## Phase 6 — Widget library ✅ *(the parked widgets are back)*

All 35 parked widgets were restored from `a4bcc18^` and ported in September 2026:
raygui calls replaced with themed primitives, input moved out of `render` into
`events`, content-driven `layout` sections added, and popups taught to grow their
own bounds. Each has a runnable example under `examples/widgets/` and coverage in
`tests/test_restored_widgets.nim`. See the widget table in
[STATUS.md](STATUS.md).

Two of the collapses this phase asked for are still open:

- Fold `textinput` into the unified text widget
  ([#30](https://github.com/kobi2187/rui2/issues/30)).
- Turn the pure-container widgets into template blocks
  ([#28](https://github.com/kobi2187/rui2/issues/28)).

<details><summary>Original parked-widget table (all now restored)</summary>

| Category | Widgets | Notes |
|----------|---------|-------|
| Text | `input/textinput`, `textarea` | Fold into the unified text widget (Phase 4). |
| Basic | `numberinput`, `iconbutton`, `toolbutton`, `separator`, `tooltip`, `spinner`, `scrollbar` | `numberinput` = text widget + stepper; `scrollbar` likely extractable for ScrollView. |
| Selection | `combobox`, `listbox`, `listview` | `listview` may have virtualization ideas worth keeping. |
| Containers | `panel`, `groupbox`, `column`, `spacer`, `radiogroup`, `statusbar`, `toolbar`, `tabcontrol` | Several become template blocks (Phase 3). |
| Menus | `menu`, `menubar`, `menuitem`, `contextmenu` | Need overlay/z-order (ZStack exists). |
| Dialogs | `messagebox`, `filedialog`, `filepicker` | Overlay + focus trapping. |
| Data | `datagrid`, `datatable`(+helpers), `treeview` | Highest-value + hardest; review for innovations first. |
| Modern | `canvas`, `dragdroparea`, `mapwidget`, `timeline` | Experimental — likely where the novel ideas live; audit before reimplementing. |

Priority order to reintroduce: **unified text widget / TextInput → ListView /
ComboBox → Menus → Dialogs → DataGrid / TreeView**.
</details>

## Phase 6.5 — Keyboard navigation *(medium — new)*
Two-level navigation: Tab between containers, arrows within the focused one,
Escape to pop out. Nothing in this roadmap covered keyboard navigation before;
probed and tracked in `tests/test_keyboard_nav.nim` (13 cases).

What works today: Tab/Shift+Tab with wrap, configurable navigation keys, routing
to the focused widget, click-to-focus, and seven widgets that handle their own
keys.

Three defects block the feature, in dependency order:
- [ ] `isFocusable` on `Widget` — today every container and label is a tab stop
  ([#16](https://github.com/kobi2187/rui2/issues/16))
- [ ] Invalidate the focus chain when the tree changes — `markDirty` and
  `widgetRemoved` exist and are called from nowhere
  ([#17](https://github.com/kobi2187/rui2/issues/17))
- [ ] Scope keys to a container, so a list and its parent can both use arrows
  ([#18](https://github.com/kobi2187/rui2/issues/18))
- [ ] Focus groups — the feature itself
  ([#19](https://github.com/kobi2187/rui2/issues/19))

## Phase 7 — Testing infrastructure *(medium)*
Strategy is visual + scripting (no headless).
- [x] **Unit suite** — 18 suites under `tests/`, no GL context needed. Layout,
  binding, theming, hit-testing, text metrics, keyboard navigation, focus
  groups, widgets, and the frame pipeline.
- [x] **Example compiles in CI** — a real `nim c` over all 32 examples, since
  naylib's move-only GPU types only fail in a full build.
- [x] **Complexity gate** — `nimtools cyc --gate 5`. rui_core, rui_events,
  rui_widgets and rui pass with nothing over the ceiling. rui_drawing (11),
  rui_hittest (5) and rui_scripting (10) have not been through the pass;
  `interval_tree`'s rebalancing is essential complexity and stays.
- [x] **Scripting-driven test harness** — runs locally and in CI, 24 assertions
  against a real window on Xvfb.
- [x] **Headless frame tests** — `app.stepHeadless()` plus a `ListEventSource`
  runs input, routing, layout and hit-testing with no window at all. The render
  pass is the only part that needs one.
- Revisit **headless mode** later as a *real* feature (not the removed stub) if
  display-free CI becomes worthwhile.

## Phase 8 — Packaging & release *(medium)*
- **Split the packages** per [SPLITTING.md](SPLITTING.md) (`git subtree split` → 7
  repos, tagged `v0.2.0` in dependency order).
- **Publish to the Nimble registry**, then simplify each `.nimble` from git-URL
  `requires` to bare-name versioned requires.
- Add a CHANGELOG and a versioning policy.

---

**Critical path (original):** Phase 0 → 1 → 2 (CI, then dirty/cache propagation,
then binding) is the spine — it turns RUI2 from "compiles and draws static UIs"
into "reactive UIs that actually update." Phases 3–4 make it pleasant; 5–8 make
it fast, complete, and shippable.

**Where that leaves things (2026-09-16).** Phase 0 is done bar the license,
Phase 1 is done, Phase 4's Pango work is done, and Phase 6's widget library is
back. The spine now runs:

```
cleanup  →  bugs  →  features
   │          │          │
   │          │          └─ focus groups (6.5), template blocks + closures (3),
   │          │             unified text widget (4)
   │          └─ hover latch, focus chain, theme seam
   └─ dead text cache, raylib re-export, theme_manager / drawing_effects splits,
      the cc=43 scripting bridge
```

`app.nim` is the serialization point — six separate items touch it, so the
split ([#22](https://github.com/kobi2187/rui2/issues/22)) goes last. Dropping the
wholesale `export raylib` ([#23](https://github.com/kobi2187/rui2/issues/23))
goes early: it blocks nothing, but every file written before it lands accumulates
another qualification workaround.
