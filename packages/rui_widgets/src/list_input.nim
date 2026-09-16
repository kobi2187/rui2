## Selection and keyboard navigation shared by every row list.
##
## Paired with [virtual_rows], which owns the geometry. This module owns what a
## click or a key press *means*: which rows end up selected, and where the focus
## moves. Both are plain functions over plain values, so both are testable
## without a widget.
##
## The selection rules were previously written out in ListBox, ListView,
## FilePicker and (as `updateSelection`) datatable_helpers. datatable_helpers
## re-exports them from here so its own callers keep working.

import std/[sets, options]
import raylib

const ActivateKeys* = {Enter, KpEnter, Space}
  ## Keys that act on the focused row rather than moving the focus.

proc toggleSelection*(selected: var HashSet[int], idx: int) =
  ## Add the row if absent, remove it if present.
  if idx in selected:
    selected.excl(idx)
  else:
    selected.incl(idx)

proc setSingleSelection*(selected: var HashSet[int], idx: int) =
  ## Replace the whole selection with one row.
  selected = [idx].toHashSet

proc updateSelection*(selected: var HashSet[int], idx: int, additive: bool) =
  ## Apply a click. `additive` is the caller's decision -- usually "this list
  ## allows multi-select AND ctrl is held" -- not the raw modifier state, so
  ## a single-select list cannot be talked into multi-selecting.
  assert idx >= 0, "callers must reject a click that missed every row first"
  if additive:
    toggleSelection(selected, idx)
  else:
    setSingleSelection(selected, idx)

proc nextFocusIndex*(key: KeyboardKey, current, total, pageSize: int): Option[int] =
  ## Where an arrow, Home, End or Page key moves the focus. `none` when the key
  ## does not navigate, which is how a caller knows to leave the event unhandled
  ## rather than swallowing every key press.
  assert total > 0, "callers must handle the empty list before navigating"
  case key
  of Up:       some(max(0, current - 1))
  of Down:     some(min(total - 1, current + 1))
  of Home:     some(0)
  of End:      some(total - 1)
  of PageUp:   some(max(0, current - pageSize))
  of PageDown: some(min(total - 1, current + pageSize))
  else:        none(int)
