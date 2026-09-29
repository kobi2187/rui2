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
##
## A stack with a height of its own hands any height its children leave unused
## to the ones with `flexGrow > 0` -- that is what makes a Spacer push the
## children after it to the bottom. See rui_core/flex.nim.

import rui_core

defineWidget(VStack):
  props:
    spacing: float = 8.0
    padding: float = 0.0
    # Stretch (the default) gives every child the stack's width, when it has
    # one. The others let children keep their own width and place them.
    crossAlign: CrossAxisAlignment = CrossStretch
    # How spare main-axis room is spent when no child flexes into it.
    mainAlign: MainAxisAlignment = MainStart

  layout:
    # Arrange children top to bottom, then size to content.
    var y = widget.bounds.y + widget.padding
    let hasWidth = widget.bounds.width > 0
    let hasHeight = widget.bounds.height > 0
    resetFlexChildren(widget.children, faVertical)
    var maxChildWidth = 0.0'f32

    for child in widget.children:
      child.bounds.x = widget.bounds.x + widget.padding
      child.bounds.y = y
      if hasWidth and widget.crossAlign == CrossStretch:
        child.bounds.width = max(0.0, widget.bounds.width - (widget.padding * 2))
      # else: leave it at 0 so the child's own layout measures itself

      child.layout()

      maxChildWidth = max(maxChildWidth, child.bounds.width)
      y += child.bounds.height + widget.spacing

    let contentBottom = if widget.children.len > 0: y - widget.spacing
                        else: widget.bounds.y + widget.padding

    if hasHeight:
      # Leftover height goes to the children with flexGrow (Spacer, ...)
      let used = (contentBottom - widget.bounds.y) + widget.padding
      let leftover = widget.bounds.height - used
      var flexing = false
      for child in widget.children:
        flexing = flexing or child.flexGrow > 0
      if flexing:
        applyFlex(widget.children, leftover, faVertical)
      else:
        justify(widget.children, faVertical, widget.mainAlign, leftover)

    if widget.crossAlign != CrossStretch:
      let cross = if hasWidth: widget.bounds.width - widget.padding * 2
                  else: maxChildWidth
      alignCross(widget.children, faVertical, widget.crossAlign, cross)

    if not hasWidth:
      widget.bounds.width = maxChildWidth + widget.padding * 2
    if widget.bounds.height <= 0:
      widget.bounds.height = (contentBottom - widget.bounds.y) + widget.padding
