## ZStack Container Widget (DSL v2)
##
## Layers children on top of each other (z-order)

import ../../core/widget_dsl_v3

defineWidget(ZStack):
  props:
    padding: float = 0.0

  layout:
    # All children occupy the same space (layered)
    for child in widget.children:
      # Each child fills the container (minus padding)
      child.bounds.x = widget.bounds.x + widget.padding
      child.bounds.y = widget.bounds.y + widget.padding
      child.bounds.width = widget.bounds.width - (widget.padding * 2)
      child.bounds.height = widget.bounds.height - (widget.padding * 2)

      # Layout the child recursively
      child.layout()
