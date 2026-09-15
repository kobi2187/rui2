## VStack Container Widget (DSL v2)
##
## Arranges children vertically with spacing

import rui_core

defineWidget(VStack):
  props:
    spacing: float = 8.0
    padding: float = 0.0

  layout:
    # Arrange children top to bottom, then size to content.
    var y = widget.bounds.y + widget.padding
    let hasWidth = widget.bounds.width > 0
    var maxChildWidth = 0.0'f32

    for child in widget.children:
      child.bounds.x = widget.bounds.x + widget.padding
      child.bounds.y = y
      if hasWidth:
        child.bounds.width = max(0.0, widget.bounds.width - (widget.padding * 2))
      # else: leave it at 0 so the child's own layout measures itself

      child.layout()

      maxChildWidth = max(maxChildWidth, child.bounds.width)
      y += child.bounds.height + widget.spacing

    let contentBottom = if widget.children.len > 0: y - widget.spacing
                        else: widget.bounds.y + widget.padding

    if not hasWidth:
      widget.bounds.width = maxChildWidth + widget.padding * 2
    if widget.bounds.height <= 0:
      widget.bounds.height = (contentBottom - widget.bounds.y) + widget.padding
