## ZStack Container Widget (DSL v2)
##
## Layers children in the same space: every child is given the container's full
## bounds less padding, so they overlap rather than tile. Paint order is child
## order -- last added is on top.
##
## With no size of its own a ZStack takes its largest child's natural size,
## then lays every child over that.

import rui_core

defineWidget(ZStack):
  props:
    padding: float = 0.0

  layout:
    # Size to the largest child when nothing assigned a size.
    if widget.bounds.width <= 0 or widget.bounds.height <= 0:
      var widest, tallest = 0.0'f32
      for child in widget.children:
        child.bounds.width = 0
        child.bounds.height = 0
        child.layout()
        widest = max(widest, child.bounds.width)
        tallest = max(tallest, child.bounds.height)
      if widget.bounds.width <= 0: widget.bounds.width = widest + widget.padding * 2
      if widget.bounds.height <= 0: widget.bounds.height = tallest + widget.padding * 2

    # All children occupy the same space (layered)
    for child in widget.children:
      # Each child fills the container (minus padding)
      child.bounds.x = widget.bounds.x + widget.padding
      child.bounds.y = widget.bounds.y + widget.padding
      child.bounds.width = max(0.0, widget.bounds.width - (widget.padding * 2))
      child.bounds.height = max(0.0, widget.bounds.height - (widget.padding * 2))

      # Layout the child recursively
      child.layout()
