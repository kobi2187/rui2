## VStack Container Widget (DSL v2)
##
## Arranges children vertically with spacing

import ../../../core/widget_dsl

defineWidget(VStack):
  props:
    spacing: float = 8.0
    padding: float = 0.0

  layout:
    # Start from top with padding
    var y = widget.bounds.y + widget.padding

    for child in widget.children:
      # Position child
      child.bounds.x = widget.bounds.x + widget.padding
      child.bounds.y = y
      child.bounds.width = widget.bounds.width - (widget.padding * 2)
      # Keep child's own height

      # Layout the child recursively
      child.layout()

      # Move down for next child
      y += child.bounds.height + widget.spacing
