## Paint -- a widget that is only a drawing.
##
## The escape hatch: when what a widget should show is not made of other
## widgets, `onPaint` draws it with rui_drawing's calls, at the bounds the
## layout gave it, every time it is repainted. Give it a size (`.frame`) or put
## it where it is stretched. Most exotic widgets need none of this: a Stack of
## real widgets, `Clip`, `onKey`, `every`/`onTick` and the layout modifiers go
## a long way (see examples/widgets/wave_reader.nim).
##
## ```nim
## Paint(onPaint = proc(area: Rect) =
##   discard drawSdfBox(area, 8, 2, Gold, Black)).frame(width = 80, height = 80)
## ```

import rui_core

definePrimitive(Paint):
  actions:
    onPaint(area: Rect)

  render:
    if widget.onPaint != nil:
      widget.onPaint(widget.bounds)
