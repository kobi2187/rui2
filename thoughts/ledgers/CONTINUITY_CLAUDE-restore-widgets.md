# Restore Deleted Widgets

## Goal
All 35 widgets deleted by `a4bcc18` ("Stage A: remove dead code") are restored under
`packages/rui_widgets/src/` and ported to the post-merge system. Done means:
- `nim check packages/rui_widgets/src/rui_widgets.nim` passes with every widget wired
  into its aggregator module.
- Each widget has `examples/widgets/<name>.nim` (pattern set by 5413f03).
- Each widget has a case in `tests/test_widgets.nim`.

## Constraints
Port delta per file (the old code predates Stages B/D and the Pango merge):
1. `import ../../core/widget_dsl` + `../../drawing_primitives/*` -> `import rui_core` / `import rui_drawing`.
2. Delete `when defined(useGraphics)` guards and their `echo` fallbacks. Graphics-only since 3741a81.
3. raygui `Gui*` calls are gone. Use rui_drawing primitives: drawComboBox, drawScrollbar,
   drawTab, drawMenuItem, drawListItem, drawStatusBar, drawGroupBox, drawTooltip,
   drawSpinner, drawSpinnerButtons, drawToggleSwitch, drawBadge, drawPanel, drawCursor.
4. Add a `layout:` section that sizes to content via `measureText(text, TextStyle(...))`.
   VStack/HStack pass width=0 down and read `child.bounds` back, so a widget that does
   not measure itself renders at zero size.
5. Hardcoded `Color` props -> `currentTheme.getThemeProps(intent, state)` + `ThemeIntent`.
6. naylib casing: `GetTime()` -> `getTime()`, `Rectangle` -> `Rect`.
7. Containers must NOT call `child.render()` / rely on rendering children themselves.
   main_loop.renderPass() and layoutPass() already recurse over `children`. The old
   containers all called child.render() explicitly -> would double-render.
8. OVERLAY CLIPPING: renderPass draws each widget into a RenderTexture2D sized to
   `widget.bounds` (and zeroes bounds.x/y for the duration). Anything a widget draws
   outside its own bounds is silently clipped. So any widget with a popup -- ComboBox
   dropdown, Tooltip, Menu, ContextMenu, MessageBox, FileDialog -- must grow its
   `bounds` to cover the popup and set `layoutDirty = true` when the popup opens.
9. Event names: only on_mouse_down/up/move/hover/wheel, on_key_down/up, on_char exist.
   `on_mouse_enter`/`on_mouse_leave` do NOT -> use on_mouse_hover + `widget.hovered`.

## Key Decisions
- 2026-09-15: User chose full scope (all 35, not a core tier) and full verification
  (nim check + example + test per widget).
- `.old` files (button/label/hstack/vstack) are NOT restored - superseded by the _v2 versions.

## State
- Done:
  - [x] Phase 0: Locate deletion commit, restore all 35 files verbatim into package tree
  - [x] Phase 1: basic/ (10 widgets) - combobox, iconbutton, listbox, listview,
        numberinput, scrollbar, separator, spinner, toolbutton, tooltip.
        DROPPED basic/button_yaml.nim: it was a demo of an `on_click:` DSL section
        that findSection() never parsed, called .get() on a non-Option, and
        duplicated button_v2. Not a widget; restoring it means inventing DSL syntax.
  - [x] Phase 2: containers/ (8) - column, groupbox, panel, radiogroup, spacer,
        statusbar, tabcontrol, toolbar. Column keeps its alignment enums and is no
        longer marked {.deprecated.}: VStack, its stated replacement, does not
        implement MainAxisAlignment/CrossAxisAlignment. RadioGroup draws its own
        options instead of owning RadioButton children (one selectedIndex is what
        makes the group exclusive). TabControl hides inactive children with
        `visible = false`. IconButton/ToolButton lost their `tooltip` prop -- see
        constraint 8, a button cannot draw outside its own bounds.
  - [x] Phase 3: input/ + menus/ (5) - textinput, menuitem, menu, menubar, contextmenu.
        TextInput now uses Pango indexFromPosition/cursorPosition for click-to-caret
        and caret geometry; its old `input:` and `on_click:` sections were never
        parsed by the DSL, so none of its editing ever ran. Its hand-written
        handleScriptAction/getScriptableState/getTypeName were dropped - the DSL
        generates all three now, and duplicates would not compile.
        Menu/ContextMenu collapse to zero bounds when closed, and expose
        open()/close()/openAt() which set layoutDirty (constraint 8).
  - [x] Phase 4: dialogs/ (3) - messagebox, filedialog, filepicker, plus a new
        shared dialogs/file_listing.nim. Neither dialog had ever scanned a
        directory; both just rendered an always-empty `files` field. Modals size
        their bounds to the whole screen so the dim overlay has somewhere to go
        (constraint 8 again). MessageBox gained the mbYesNoCancel case the old
        file left as a TODO, and real button hit-testing instead of raygui
        buttons fired from inside render.
  - [x] Phase 5: data/ (4) - treeview, datatable, datagrid, datatable_helpers.
        datatable_helpers compiled unchanged (pure logic, no rui imports), but
        datatable had re-declared FilterKind/Filter/TableRow AND a second, buggier
        matcher inline - it now imports the helpers. SortOrder moved into helpers
        (both table widgets had their own). std/algorithm is imported with `from`
        because it exports its own SortOrder. datagrid's Column/Row renamed
        GridColumn/GridRow: `Column` is the layout container widget's name.
        TreeView `hovered` and DataTable/DataGrid `hovered` state fields renamed -
        Widget already has a `hovered: bool`.
  - [x] Phase 6: modern/ (4) - canvas, dragdroparea, timeline, mapwidget.
        Canvas stores commands in canvas-relative coords (constraint 8: render
        zeroes bounds.x/y). DragDropArea gained pollFileDrops(), called once per
        frame by the app: file drops are not GuiEvents, and the old code polled
        raylib from inside render. Timeline/MapWidget put their projection in a
        plain TimelineAxis / MapView value plus an `axisOf`/`viewOf` template,
        because a proc taking the widget type cannot be declared before the macro
        that creates that type, and the widget body needs the geometry.
  - [x] All 35 widgets compile: nim check packages/rui_widgets/src/rui_widgets.nim
  - [x] Phase 7: tests/test_restored_widgets.nim (60 cases, all green) and 11
        examples under examples/widgets/ covering all 35. Both globs are picked
        up automatically by tools/run_tests.sh.
- Now: [->] Done. Full suite green; every package still compiles.

## Fixes made along the way (found by the port, not asked for)
- ComboBox/RadioGroup `initialSelected` never seeded `selectedIndex`: the DSL
  seeds state from a prop named initial<StateField>. Renamed initialSelectedIndex.
- `contains(Rect, x, y)` existed in rui_hittest and was re-declared by four
  restored widgets; importing two of them through the `rui` barrel made every
  call ambiguous. It now lives once, in rui_core/types.nim next to Rect.
- `panelRect` was exported by both messagebox and filedialog -> dialogs/modal.nim.
- App gained an `onFrame*: Option[proc()]` hook. DragDropArea cannot work without
  one: file drops are not GuiEvents, and polling raylib from inside `render` only
  works on frames where the widget happens to be dirty.
- MapWidget had dead seeding code in `layout`; the constructor already does it.

## Open Questions
- Tooltip: state field `visible` collides with the Widget base field -> renamed `showing`.
- NAME CLASH: naylib's KeyboardKey has a `Menu` field and rui_core re-exports raylib
  wholesale, so the widget type `Menu` is ambiguous wherever raylib is in scope.
  menubar.nim qualifies it as `menu.Menu`. Watch for the same with other widget
  names that collide with raylib enum fields.
- `fadeColor` in primitives/controls.nim is private; widgets that need to tint a theme
  color inline the alpha math. Worth exporting.
- UNCONFIRMED: modern/ (canvas, mapwidget, timeline, dragdroparea) may be half-finished
  experiments rather than working widgets.

## Working Set
- Branch: main
- Restore source: `git show a4bcc18^:widgets/<path>`
- Check: `nim check --hints:off packages/rui_widgets/src/rui_widgets.nim`
- Per-file check: `nim check --hints:off packages/rui_widgets/src/<cat>/<name>.nim`
