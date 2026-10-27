## The overlay layer: widgets drawn over everything.
##
## Every widget paints into its own render texture, so nothing it draws can
## leave its bounds. That is right for almost everything and wrong for what
## must float above the tree. An overlay is a widget the App lays out, renders
## and composites *after* the root, at its own bounds, so it is drawn over
## everything and clipped by nothing. What uses it, each with its own module:
##
## - tooltips (basic/tooltip.nim): seen, not touched;
## - menus, dropdowns and in-app windows (menus/menu_panel.nim,
##   input/popup_field.nim, rui_windows): `interactive`, so they take the
##   pointer before the tree under them (`overlayAt`, which the router asks
##   first);
## - the focus ring (basic/focusring.nim) and decorations (decoration.nim),
##   which keep beside a widget as it moves (`followWidget`).
##
## Where the pointer is and who holds it is pointer_state.nim, re-exported here.

import types
import pointer_state
export pointer_state

var
  layer: seq[Widget]
  interactive: seq[Widget]   # the overlays a pointer can land on
  layerVersion = 0

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
