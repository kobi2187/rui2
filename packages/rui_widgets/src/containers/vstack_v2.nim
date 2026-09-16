## VStack Container Widget (DSL v2)
##
## Arranges children top to bottom, then sizes itself to what it arranged.
##
## The layout is two-way, which is the part worth knowing. A stack that has a
## width of its own imposes it on every child; a stack that does not leaves the
## child's width at 0 and lets the child's own `layout` measure itself, then
## takes the widest. Same for its own height: it is only computed when nothing
## has already assigned one.
##
## That is why a Label placed in a stack does not need its bounds set by the
## caller, and why passing width = 0 down the tree is deliberate rather than a
## missing value. A container that unconditionally forced its own dimensions on
## its children collapsed every text child to zero -- see the note in
## hstack_v2.nim, which had exactly that bug.
##
## Children are laid out but never rendered here: main_loop's renderPass and
## layoutPass both already recurse over `children`, so a container that drew its
## own children would draw them twice.

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
