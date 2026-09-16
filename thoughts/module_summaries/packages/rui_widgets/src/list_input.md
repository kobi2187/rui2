# packages/rui_widgets/src/list_input.nim

## Purpose

What a click or key press *means* in a row list: which rows end up selected,
and where the focus moves. Paired with [virtual_rows](virtual_rows.md), which
owns where things are. Both are plain functions over plain values, so both are
testable without a widget.

## Public interface

- `ActivateKeys*` — `{Enter, KpEnter, Space}`, the keys that act on the focused
  row rather than moving the focus.
- `toggleSelection*[T](selected: var HashSet[T], item: T)` — add if absent,
  remove if present.
- `setSingleSelection*[T](selected: var HashSet[T], item: T)` — replace the
  whole selection with one row.
- `updateSelection*[T](selected: var HashSet[T], item: T, additive: bool)` —
  apply a click.
- `nextFocusIndex*(key: KeyboardKey, current, total, pageSize: int): Option[int]`
  — where Up/Down/Home/End/PageUp/PageDown move the focus. **`none` when the key
  does not navigate**, which is how a caller knows to leave the event unhandled
  instead of swallowing every key press. Asserts `total > 0`.

Generic over the key because lists identify rows differently: ListBox,
ListView, DataTable and DataGrid select by index, FilePicker by path.

## Usage pattern

```nim
# Click. `additive` is the CALLER's decision, not the raw modifier state, so a
# single-select list cannot be talked into multi-selecting:
let additive = widget.multiSelect and
               (isKeyDown(LeftControl) or isKeyDown(RightControl))
updateSelection(widget.selection, idx, additive)

# Key press:
if event.key in ActivateKeys:
  ... activate the focused row ...
  return true

let moved = nextFocusIndex(event.key, widget.focusIndex, total, widget.visibleRows)
if moved.isNone:
  return false                       # not ours; let it bubble
if moved.get() != widget.focusIndex:
  widget.focusIndex = moved.get()
  widget.scrollY = viewportOf(widget).scrollToShow(moved.get(), total)
  widget.isDirty = true
return true
```

## Circumstances

2026-09-16, the same refactor pass as `virtual_rows`. These rules were written
out in ListBox, ListView and FilePicker, and a fourth time in
`data/datatable_helpers.nim` as `updateSelection`. That module now imports and
re-exports them from here, so its existing callers and tests are untouched.

Two things changed on the way through, both worth keeping:

- The flag is `additive`, not `ctrlDown`. A single-select list must ignore ctrl,
  and that is a decision about the list rather than about the keyboard.
- `nextFocusIndex` returns `Option[int]` rather than signalling "not a
  navigation key" through the index value — no sentinel.
</content>
