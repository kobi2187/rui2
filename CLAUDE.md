# Working in this repo

- **Share, don't copy.** When you write widget code and notice behaviour that
  another widget already has (or will need), put it in a shared helper right then,
  and move the existing copies onto it. Related widgets must behave the same:
  `rui_widgets/src/press.nim` (everything button-like), `scroll_drag.nim` (scrolling
  row lists), `choice.nim` (pick-one), `value_input.nim` (sliders), `input/popup_field.nim`
  and `menus/menu_panel.nim` (popups), `dialogs/modal.nim` (modals). A widget keeps
  only what is its own.
- **Keep it primal.** Shared behaviour is plain library code a primitive calls
  (values, procs, a state object with one `handle`), never a wrapper widget or a
  convention to memorise ("child *i* is ..."). A widget is something you see.
  Library code changes what it was given and returns what it did; it does not
  call back into the caller, so a handler reads straight through in a debugger
  (`view_range.nim` `ZoomPan.handle`, `axis_marks.nim` `Marks.handle`).
- **Test the behaviour across the group**, not once per widget: see
  `tests/test_press_behavior.nim`, `test_choice_behavior.nim`, `test_popup_behavior.nim`,
  `test_drag_behavior.nim`, and `tests/ui_harness.nim` for driving widgets through the
  real event router. `test_widget_fuzz.nim` runs every registered widget through the
  same gestures.
- Anything that starts a drag takes the pointer (`capturePointer`) so the drag
  survives leaving the widget; the router releases it on mouse-up.
- Composite widgets build their children in `init:`, not `layout:` (a debug build
  warns otherwise), and keep typed refs to them in `state:`. Assigning a child's
  prop or state field from outside its module redraws it (the generated setter);
  changing one in place (`list.selection.clear()`, `list.items.add x`) does not,
  so call `markDirtyToRoot()` after (and set `layoutDirty` if its size or
  layout-time look depends on it).
- Examples and the gallery use the real widgets and the `ui:` DSL; if a widget is
  wrong, fix the widget.
- Run `./tools/run_tests.sh quick` and `tools/layout_snapshot.sh check` before pushing
  (Nim 2.x must be first on PATH).
