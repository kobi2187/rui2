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

import types

var
  layer: seq[Widget]
  interactive: seq[Widget]   # the overlays a pointer can land on
  layerVersion = 0
  pointerOver: Widget
  pointerAt: Point

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
