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

var pending: seq[tuple[widget: Widget, at: MonoTime]]

proc repaintAt*(widget: Widget, at: MonoTime) =
  ## Mark `widget` dirty once `at` has passed. A widget holds one timer; asking
  ## again keeps the earlier of the two.
  for entry in pending.mitems:
    if entry.widget == widget:
      if at < entry.at:
        entry.at = at
      return
  pending.add((widget, at))

proc repaintAfter*(widget: Widget, delay: Duration) =
  widget.repaintAt(getMonoTime() + delay)

proc repaintAfter*(widget: Widget, seconds: float) =
  widget.repaintAfter(initDuration(nanoseconds = int64(seconds * 1e9)))

proc fireDueRepaints*(now = getMonoTime()): bool =
  ## Mark every widget whose time has come dirty up to the root. Returns
  ## whether any did, so the loop knows this frame has something to paint.
  var i = 0
  while i < pending.len:
    if pending[i].at <= now:
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
