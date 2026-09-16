## HStack Container Widget (DSL v2)
##
## Arranges children left to right, then sizes itself to what it arranged.
## The mirror of vstack_v2.nim, whose module comment explains the two-way
## sizing both share.
##
## The bug that shaped it: a stack with no height of its own used to force
## height 0 onto every child, so a row of buttons collapsed to a sliver. A child
## is given a height only when this stack actually has one.

import rui_core

defineWidget(HStack):
  props:
    spacing: float = 8.0
    padding: float = 0.0

  layout:
    # Arrange children left to right, then size to content.
    #
    # A container with no height of its own used to force height 0 onto every
    # child, so a row of buttons collapsed to a sliver. Now a child is only
    # given a height when this stack actually has one; otherwise it sizes itself
    # and the stack takes the tallest.
    var x = widget.bounds.x + widget.padding
    let hasHeight = widget.bounds.height > 0
    var maxChildHeight = 0.0'f32

    for child in widget.children:
      child.bounds.x = x
      child.bounds.y = widget.bounds.y + widget.padding
      if hasHeight:
        child.bounds.height = max(0.0, widget.bounds.height - (widget.padding * 2))
      # else: leave it at 0 so the child's own layout measures itself

      child.layout()

      maxChildHeight = max(maxChildHeight, child.bounds.height)
      x += child.bounds.width + widget.spacing

    # Trailing spacing is not part of the content extent
    let contentRight = if widget.children.len > 0: x - widget.spacing
                       else: widget.bounds.x + widget.padding

    if widget.bounds.width <= 0:
      widget.bounds.width = (contentRight - widget.bounds.x) + widget.padding
    if not hasHeight:
      widget.bounds.height = maxChildHeight + widget.padding * 2
