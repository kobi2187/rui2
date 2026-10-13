## Where a list's selection, focus, hover and scroll go when its rows are edited.
##
## ListView, ListBox and DataTable all show a `LinkSeq`. When a row is inserted,
## removed or moved the widget applies the same edit to its copy -- and *this*
## decides what happens to the user's place in the list: the selection stays on
## the rows it was on, the focus follows its row (or lands next to where it
## was), and the scroll position holds still relative to what is on screen. Pure
## values in and out, so each rule is a test and no widget is needed.

import std/[sets, math]
import rui_core

type
  RowPlace* = object
    ## A list's place in its rows.
    selection*: HashSet[int]
    focus*, hover*, anchor*: int
    scrollY*: float32

proc followEdit*(place: var RowPlace, change: SeqChange, itemCount: int,
                 rowHeight, viewHeight: float32): bool =
  ## Carry `place` across `change`; `itemCount` is the length *after* it. Returns
  ## whether the selection lost a row (the owner may want to say so).
  let before = place.selection.len
  case change.kind
  of scReset:
    place.selection.clear()
    place.focus = 0
    place.hover = -1
    place.anchor = 0
    place.scrollY = 0
    return before > 0
  of scReplace:
    return false
  else: discard

  place.selection = change.remap(place.selection)
  result = place.selection.len < before

  let last = max(0, itemCount - 1)
  var focus = change.remap(place.focus)
  if focus < 0: focus = clamp(change.index, 0, last)       # its row is gone: stay beside it
  place.focus = clamp(focus, 0, last)
  let hover = change.remap(place.hover)
  place.hover = if hover >= itemCount: -1 else: hover
  var anchor = change.remap(place.anchor)
  if anchor < 0: anchor = place.focus
  place.anchor = clamp(anchor, 0, last)

  # Scroll: rows added or removed above the first visible row would push what
  # the user is looking at; move the scroll by the same amount to hold it still.
  if rowHeight > 0 and place.scrollY > 0:
    let firstVisible = int(floor(place.scrollY / rowHeight))
    case change.kind
    of scInsert:
      if change.index < firstVisible:
        place.scrollY += float32(change.count) * rowHeight
    of scRemove:
      let above = min(change.count, max(0, firstVisible - change.index))
      place.scrollY -= float32(above) * rowHeight
    else: discard
  if rowHeight > 0 and viewHeight > 0:
    let maxScroll = max(0.0'f32, float32(itemCount) * rowHeight - viewHeight)
    place.scrollY = clamp(place.scrollY, 0.0'f32, maxScroll)
  else:
    place.scrollY = max(0.0'f32, place.scrollY)


template followItemsLink*(list: untyped, source: untyped) =
  ## `ListBox(items = -> items)` where `items` is a `Link[seq[string]]` (e.g. from a
  ## `state:` block): show the seq, and show it again whenever the Link is set.
  list.items = source.value
  list.isDirty = true
  source.bindTo(list, proc (v: seq[string]) =
    list.items = v
    list.layoutDirty = true
    list.markDirtyToRoot())
