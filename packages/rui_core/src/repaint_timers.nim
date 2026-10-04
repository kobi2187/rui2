## Repaint timers: a widget asking to be drawn again later.
##
## The loop only paints dirty widgets, and an idle app does not paint at all.
## So anything that changes with time and nothing else -- a blinking caret, a
## spinner, a delayed reveal -- has to say when it next needs a frame, or it
## freezes wherever its last repaint left it. That is what used to happen to
## the TextArea caret: it blinked only if something else happened to dirty
## the widget, and could sit in its "off" phase indefinitely.
##
## Module-level state, like `currentTheme`: widgets have no reference to the
## App, and a timer has to be settable from inside `render`.

import std/[monotimes, times, options]
import types

var pending: seq[tuple[widget: Widget, at: MonoTime, relayout: bool]]

proc repaintAt*(widget: Widget, at: MonoTime, relayout = false) =
  ## Mark `widget` dirty once `at` has passed -- and laid out again, if
  ## `relayout` (what an animation needs: its layout is where it reads the
  ## value for this frame). A widget holds one timer; asking again keeps the
  ## earlier time, and a request for relayout sticks.
  for entry in pending.mitems:
    if entry.widget == widget:
      if at < entry.at:
        entry.at = at
      entry.relayout = entry.relayout or relayout
      return
  pending.add((widget, at, relayout))

proc repaintAfter*(widget: Widget, delay: Duration, relayout = false) =
  widget.repaintAt(getMonoTime() + delay, relayout)

proc repaintAfter*(widget: Widget, seconds: float, relayout = false) =
  widget.repaintAfter(initDuration(nanoseconds = int64(seconds * 1e9)), relayout)

proc fireDueRepaints*(now = getMonoTime()): bool =
  ## Mark every widget whose time has come dirty up to the root. Returns
  ## whether any did, so the loop knows this frame has something to paint.
  var i = 0
  while i < pending.len:
    if pending[i].at <= now:
      if pending[i].relayout:
        pending[i].widget.layoutDirty = true
      pending[i].widget.markDirtyToRoot()
      pending.del(i)
      result = true
    else:
      inc i

proc nextRepaint*(): Option[MonoTime] =
  ## The earliest pending timer, if any.
  for entry in pending:
    if result.isNone or entry.at < result.get:
      result = some(entry.at)

proc clearRepaints*() =
  ## Drop every timer. For tests, and for an app replacing its whole tree.
  pending.setLen(0)
