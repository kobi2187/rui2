## The overlay layer, and what the pointer is over.
##
## Every widget paints into its own render texture, so nothing it draws can
## leave its bounds. That is fine for almost everything and wrong for the few
## things that must float above the tree: a tooltip beside its target, a
## popup below its button. An overlay is a widget the App lays out, renders
## and composites *after* the root, at its own bounds, so it is drawn over
## everything and clipped by nothing.
##
## Overlays are display-only for now: they are not hit-tested, which is all a
## tooltip needs. Menus and combo-box lists grow their own bounds instead, and
## moving them here (with hit-testing first) is tracked in issue #43.
##
## The pointer state is here for the same reason: a widget has no App, and a
## tooltip needs to know whether the pointer is still over its target.
## Module-level, like `currentTheme`.

import std/tables
import types
import freeze

var
  layer: seq[Widget]
  interactive: seq[Widget]   # the overlays a pointer can land on
  layerVersion = 0
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

proc showOverlay*(widget: Widget, interactive = false) =
  ## Put `widget` on the overlay layer, above everything already there. An
  ## interactive overlay (a menu, a dropdown) takes the pointer before the
  ## tree under it does; others (focus rings, toasts) are only seen.
  if interactive and widget notin overlays.interactive:
    overlays.interactive.add widget
  if widget notin layer:
    layer.add widget
    widget.layoutDirty = true
    widget.isDirty = true
    inc layerVersion

proc hideOverlay*(widget: Widget) =
  let i = layer.find(widget)
  if i >= 0:
    layer.delete(i)
    inc layerVersion
  let k = interactive.find(widget)
  if k >= 0:
    interactive.delete(k)

proc overlays*(): seq[Widget] = layer

proc overlayVersion*(): int =
  ## Changes whenever an overlay is shown or hidden, so the App knows the
  ## screen needs presenting even when no widget texture was repainted.
  layerVersion

proc clearOverlays*() =
  layer.setLen(0)
  interactive.setLen(0)
  inc layerVersion

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

proc followWidget*(overlay, target: Widget, margin: float32, show: bool) =
  ## Keep `overlay` on the overlay layer `margin` beyond `target`'s bounds
  ## while `show` and the target is on the page (`onPage`); off it otherwise.
  ## What a focus ring and a decoration both do, every frame.
  if not show or not target.onPage:
    if overlay in layer: hideOverlay(overlay)
    return
  let want = Rect(x: target.bounds.x - margin, y: target.bounds.y - margin,
                  width: target.bounds.width + margin * 2,
                  height: target.bounds.height + margin * 2)
  if overlay.bounds != want:
    overlay.bounds = want
    overlay.isDirty = true
  if overlay notin layer: showOverlay(overlay)

proc containsPointer*(widget: Widget): bool =
  ## Whether the pointer is over this widget or anything inside it.
  pointerOver != nil and pointerOver.isWithin(widget)

proc deepestAt(widget: Widget, x, y: float32): Widget =
  ## The innermost visible widget under (x, y) in `widget`'s subtree, later
  ## children over earlier ones; nil when (x, y) is outside it.
  if not widget.visible or not widget.bounds.contains(x, y):
    return nil
  for i in countdown(widget.children.high, 0):
    let hit = deepestAt(widget.children[i], x, y)
    if hit != nil:
      return hit
  widget

proc overlayAt*(x, y: float32): Widget =
  ## What the pointer lands on in the interactive overlays, topmost first;
  ## nil when it lands on none of them.
  for i in countdown(layer.high, 0):
    if layer[i] in interactive:
      let hit = deepestAt(layer[i], x, y)
      if hit != nil:
        return hit
