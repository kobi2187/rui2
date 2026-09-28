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
## moving them here (with hit-testing first) is on TODO.md.
##
## The pointer state is here for the same reason: a widget has no App, and a
## tooltip needs to know whether the pointer is still over its target.
## Module-level, like `currentTheme`.

import types

var
  layer: seq[Widget]
  layerVersion = 0
  pointerOver: Widget
  pointerAt: Point

proc showOverlay*(widget: Widget) =
  ## Put `widget` on the overlay layer, above everything already there.
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

proc overlays*(): seq[Widget] = layer

proc overlayVersion*(): int =
  ## Changes whenever an overlay is shown or hidden, so the App knows the
  ## screen needs presenting even when no widget texture was repainted.
  layerVersion

proc clearOverlays*() =
  layer.setLen(0)
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
