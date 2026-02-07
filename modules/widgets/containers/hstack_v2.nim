## HStack Container Widget (DSL v2)
##
## Arranges children horizontally with spacing

import ../../../core/widget_dsl

defineWidget(HStack):
  props:
    spacing: float = 8.0
    padding: float = 0.0

  layout:
    # Start from left with padding
    var x = widget.bounds.x + widget.padding

    for child in widget.children:
      # Position child
      child.bounds.x = x
      child.bounds.y = widget.bounds.y + widget.padding
      child.bounds.height = widget.bounds.height - (widget.padding * 2)
      # Keep child's own width

      # Layout the child recursively
      child.layout()

      # Move right for next child
      x += child.bounds.width + widget.spacing
