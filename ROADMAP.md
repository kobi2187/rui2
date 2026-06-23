# RUI2 Roadmap

Ordered by dependency and leverage: correctness before features before
optimization. See [STATUS.md](STATUS.md) for what works today.

---

## Phase 0 — Lock in the foundation *(small, do first)*
- **Compile-check CI** — a GitHub workflow running `nim check` on the 7 package
  barrels + examples. The tree had no CI and never compiled before this branch;
  without it, regressions are invisible.
- **Choose a license** — fill the `# license` TODO in all 7 `.nimble` files.
- **Pin dependencies** — record the `naylib`/`yaml` versions known to build.

## Phase 1 — Rendering correctness *(medium, load-bearing — blocks Phase 2)*
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

## Phase 2 — Make reactivity real *(medium — the headline promise)*
`Link[T]` already has `addDependent` + O(1) dirty-marking; only the wiring is
missing. Provide **both** entry points:
- **Manual binding** — keep/document `link.addDependent(widget)` for explicit use.
- **A DSL "gui word"** — a binding keyword in the widget DSL (e.g. `bind`) that
  registers the widget as a dependent and re-reads the value on change.
- Depends on Phase 1 to actually repaint. Convert the counter example to true
  binding (drop the manual `.get()` snapshot) as the proof.

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
- **Wire the Pango binding into it.** You already use Pango to render glyphs and
  compute offsets, handing a 2D texture to raylib — connect that path (the widget
  currently uses raylib `drawText`), leaning on naylib RAII for the texture rather
  than the abandoned manual GPU-cache experiment.
- **Real text measurement** → fixes approximate label centering and lets
  containers size to content.

## Phase 5 — Performance refinements *(medium — after correctness; measure first, don't over-optimize)*
- **Stop rebuilding children every layout pass** — composites like `Button` do
  `children.setLen(0)` + reallocate each layout; diff/reuse so identity and caches
  survive.
- **Incremental hit-testing** — `Widget.previousBounds` exists but is unused;
  update the interval tree on changed bounds instead of a full rebuild per frame.
- **Remove per-event `echo`** from the event loop (`rui/src/app.nim`).

## Phase 6 — Widget library *(large, ongoing)*
Cleanup parked many half-finished widgets. They are **not abandoned** — the intent
is to bring them back, and some may carry useful ideas/innovations worth mining
before any rewrite. Recover any of them from history:

```bash
git checkout efe72d6 -- widgets/<path>      # efe72d6 = pre-cleanup commit
```

Bring them back deliberately, one per PR: ported to the DSL + naylib, compiling,
with a scripting-driven test, then promoted into STATUS's "works" list. Collapse
near-duplicates into one well-made widget + flags (as with the text widget).

### Parked widgets (intended, recoverable)
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

## Phase 7 — Testing infrastructure *(medium)*
Strategy is visual + scripting (no headless).
- **Scripting-driven test harness** — use `rui_scripting`'s client to drive
  examples and assert widget state (`getScriptableState`/`handleScriptAction`),
  runnable in CI under a virtual display (Xvfb).
- Revisit **headless mode** later as a *real* feature (not the removed stub) if
  display-free CI becomes worthwhile.

## Phase 8 — Packaging & release *(medium)*
- **Split the packages** per [SPLITTING.md](SPLITTING.md) (`git subtree split` → 7
  repos, tagged `v0.2.0` in dependency order).
- **Publish to the Nimble registry**, then simplify each `.nimble` from git-URL
  `requires` to bare-name versioned requires.
- Add a CHANGELOG and a versioning policy.

---

**Critical path:** Phase 0 → 1 → 2 (CI, then dirty/cache propagation, then
binding) is the spine — it turns RUI2 from "compiles and draws static UIs" into
"reactive UIs that actually update." Phases 3–4 make it pleasant; 5–8 make it
fast, complete, and shippable.
