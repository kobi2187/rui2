## ZStack Container Widget (DSL v2)
##
## Layers children in the same space: every child is given the container's full
## bounds less padding, so they overlap rather than tile. Paint order is child
## order -- last added is on top.
##
## Unlike VStack and HStack this one does not size itself to its content and
## cannot: with every child in the same cell there is no direction to grow in,
## and a child asked to fill a zero-sized parent would measure zero. A ZStack
## needs bounds from its own parent or from the caller.

import rui_core

defineWidget(ZStack):
  props:
    padding: float = 0.0

  layout:
    # All children occupy the same space (layered)
    for child in widget.children:
      # Each child fills the container (minus padding)
      child.bounds.x = widget.bounds.x + widget.padding
      child.bounds.y = widget.bounds.y + widget.padding
      child.bounds.width = max(0.0, widget.bounds.width - (widget.padding * 2))
      child.bounds.height = max(0.0, widget.bounds.height - (widget.padding * 2))

      # Layout the child recursively
      child.layout()
