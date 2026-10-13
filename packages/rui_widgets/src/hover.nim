## Hover state that must clear when the pointer leaves: a widget's own move
## handler never hears the pointer go, so it asks to be told instead.

import rui_core

template resetOnLeave*(widget, body: untyped) =
  ## Run `body` (reset the hover fields) when the pointer leaves the widget and
  ## everything under it, then repaint.
  widget.onPointerLeave = proc() =
    body
    widget.markDirtyToRoot()
