## Where the pointer is, and who holds it.
##
## A widget has no App, yet a tooltip must know whether the pointer is still
## over its target, a drag must keep the pointer when it leaves its widget, and
## a timer must know whether its widget is on the page at all. That state lives
## here, module-level, like `currentTheme`:
##
## - **Capture:** `capturePointer` gives a widget every move and release of a
##   pointer until it is let go (the router releases it on mouse-up).
## - **What is under it:** `pointerWidget`, `pointerPos`, `containsPointer`,
##   set by the router on every move.
## - **On the page:** `onPage` -- visible, sized, and not frozen behind a modal.
## - `onPointerPress`: told of every press before it is delivered.
##
## The overlay layer (overlays.nim) is the other half of what floats over the
## tree; it re-exports this module.

import std/tables
import types
import freeze

var
  pointerOver: Widget
  pointerAt: Point

var
  onPointerPress*: proc(target: Widget) {.closure.}
    ## Called by the router with the widget a press landed on (nil: empty space),
    ## before the press is delivered. How a window raises itself when anything
    ## inside it is clicked -- including a child that consumes the click -- and
    ## stands down when the page is. nil costs one check.
  captured: Table[int, Widget]   # pointer id -> the widget that holds it

proc capturePointer*(widget: Widget, pointer = 0) =
  ## Until `releasePointer` (or the next button release), moves and releases go
  ## to `widget` wherever the pointer is: a drag that outruns its widget keeps
  ## working. `pointer` is the pointer id (0: the mouse or first finger); a
  ## pinch holds two.
  captured[pointer] = widget

proc releasePointer*(pointer = 0) = captured.del pointer
proc releaseAllPointers*() = captured.clear()
proc pointerCapture*(pointer = 0): Widget = captured.getOrDefault(pointer)

proc setPointer*(over: Widget, at: Point) =
  ## Called by the event router on every pointer move.
  pointerOver = over
  pointerAt = at

proc pointerWidget*(): Widget = pointerOver
proc pointerPos*(): Point = pointerAt

proc isWithin*(widget, scope: Widget): bool =
  ## Is `widget` inside `scope` (or `scope` itself)? A nil scope is the whole
  ## tree, so everything is within it.
  if scope == nil:
    return true
  var w = widget
  while w != nil:
    if w == scope:
      return true
    w = w.parent
  false

proc onPage*(widget: Widget): bool =
  ## Whether `widget` is there to be seen: it and every ancestor visible, it
  ## has a size, and it is not on a page frozen behind a modal (freeze.nim) --
  ## a still picture is not a place for anything to move round.
  if widget == nil or widget.bounds.width <= 0 or widget.bounds.height <= 0:
    return false
  var w = widget
  var root = widget
  while w != nil:
    if not w.visible: return false
    root = w
    w = w.parent
  let modal = frozenBy(root)
  modal == nil or widget.isWithin(modal)

proc containsPointer*(widget: Widget): bool =
  ## Whether the pointer is over this widget or anything inside it.
  pointerOver != nil and pointerOver.isWithin(widget)
