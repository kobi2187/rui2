## Clip -- show only part of a widget.
##
## The child is laid out over the whole Clip as always; only the rectangle
## left after cutting `cut` from each side is drawn. Change `cut` and the edge
## moves -- to the sub-pixel: an edge between two pixels shows that row in
## part, so a slow wipe glides instead of stepping. The child stays a real,
## live widget the whole time.
##
## ```nim
## Stack(fit = StackFit.expand):
##   below = Clip(): Label(text = thisPage, wrap = true)     # under the line
##   above = Clip(): Label(text = nextPage, wrap = true)     # over it
## # each frame:
## above.cut = EdgeInsets(bottom: height - lineY)
## below.cut = EdgeInsets(top: lineY)
## ```
##
## Wipes, reveals, a before/after slider, a progress fill made of a real
## widget: one child each, cut to the part that should show. Only drawing is
## cut: the hidden part of the child still takes the pointer.

import rui_core
import std/options

proc shownPart*(widget: Widget): Rect

definePrimitive(Clip):
  props:
    cut: EdgeInsets = EdgeInsets()   ## what is cut off each side, px

  init:
    widget.softClip = true

  layout:
    widget.childClip = some(widget.shownPart)   # widget-local
    if widget.children.len > 0:
      widget.children[0].arrange(widget.bounds)

  render:
    widget.childClip = some(widget.shownPart)   # `cut` may change without a relayout

proc shownPart*(widget: Widget): Rect =
  ## The part drawn, in the Clip's own coordinates.
  let widget = Clip(widget)
  let c = widget.cut
  Rect(x: c.left, y: c.top,
       width: max(0'f32, widget.bounds.width - c.left - c.right),
       height: max(0'f32, widget.bounds.height - c.top - c.bottom))

method computeSize*(widget: Clip, c: Constraints): Size =
  if widget.children.len == 0:
    return Size(width: (if c.tightWidth: c.minWidth else: 0), height: (if c.tightHeight: c.minHeight else: 0))
  widget.children[0].measure(c)
