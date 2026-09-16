## Column Widget - Vertical layout container (Flutter-style)
##
## Arranges children vertically with spacing, main-axis distribution and
## cross-axis alignment.
##
## Prefer VStack for the common case (stack things top to bottom with a gap).
## Column is the one to reach for when you need MainAxisAlignment /
## CrossAxisAlignment; VStack does not implement those.
##
## Flutter equivalent:
##   Column(
##     mainAxisAlignment: MainAxisAlignment.start,
##     crossAxisAlignment: CrossAxisAlignment.start,
##     children: [...]
##   )

import rui_core

type
  MainAxisAlignment* = enum
    MainStart        # Children at start
    MainCenter       # Children centered
    MainEnd          # Children at end
    SpaceBetween     # Space between children
    SpaceAround      # Space around children
    SpaceEvenly      # Even space

  CrossAxisAlignment* = enum
    CrossStart       # Align to start (left)
    CrossCenter      # Center children
    CrossEnd         # Align to end (right)
    CrossStretch     # Stretch to fill width

defineWidget(Column):
  props:
    spacing: float32 = 0.0
    mainAxisAlignment: MainAxisAlignment = MainStart
    crossAxisAlignment: CrossAxisAlignment = CrossStart
    padding: EdgeInsets = EdgeInsets(top: 0, right: 0, bottom: 0, left: 0)

  layout:
    if widget.children.len == 0:
      return

    let contentX = widget.bounds.x + widget.padding.left
    let contentY = widget.bounds.y + widget.padding.top
    let contentWidth = widget.bounds.width - widget.padding.left - widget.padding.right
    let contentHeight = widget.bounds.height - widget.padding.top - widget.padding.bottom

    # Pass 1: let every child measure itself. Distribution needs all the heights
    # up front, which is why this cannot be done in a single top-to-bottom sweep
    # the way VStack does it. Children are laid out again in pass 2 once their
    # final position is known -- layout() is idempotent, so that is safe, and it
    # is what keeps grandchildren from being left behind at the scratch position.
    for child in widget.children:
      child.bounds.x = contentX
      child.bounds.y = contentY
      if widget.crossAxisAlignment == CrossStretch and contentWidth > 0:
        child.bounds.width = contentWidth
      child.layout()

    var totalChildHeight = 0.0'f32
    for child in widget.children:
      totalChildHeight += child.bounds.height

    let totalSpacing = if widget.children.len > 1:
                         widget.spacing * float32(widget.children.len - 1)
                       else:
                         0.0'f32
    let totalContentHeight = totalChildHeight + totalSpacing

    var y = case widget.mainAxisAlignment
      of MainStart, SpaceBetween, SpaceAround, SpaceEvenly:
        contentY
      of MainCenter:
        contentY + (contentHeight - totalContentHeight) / 2.0
      of MainEnd:
        contentY + contentHeight - totalContentHeight

    var actualSpacing = widget.spacing
    if widget.children.len > 1:
      case widget.mainAxisAlignment
      of SpaceBetween:
        actualSpacing = (contentHeight - totalChildHeight) / float32(widget.children.len - 1)
      of SpaceAround:
        actualSpacing = (contentHeight - totalChildHeight) / float32(widget.children.len)
        y += actualSpacing / 2.0
      of SpaceEvenly:
        actualSpacing = (contentHeight - totalChildHeight) / float32(widget.children.len + 1)
        y += actualSpacing
      else:
        discard

    # Pass 2: final placement.
    var maxChildWidth = 0.0'f32
    for child in widget.children:
      child.bounds.x = case widget.crossAxisAlignment
        of CrossStart, CrossStretch:
          contentX
        of CrossCenter:
          contentX + (contentWidth - child.bounds.width) / 2.0
        of CrossEnd:
          contentX + contentWidth - child.bounds.width
      child.bounds.y = y

      if widget.crossAxisAlignment == CrossStretch and contentWidth > 0:
        child.bounds.width = contentWidth

      child.layout()

      maxChildWidth = max(maxChildWidth, child.bounds.width)
      y += child.bounds.height + actualSpacing

    # Size to content when the parent did not dictate a size.
    if widget.bounds.width <= 0:
      widget.bounds.width = maxChildWidth + widget.padding.left + widget.padding.right
    if widget.bounds.height <= 0:
      widget.bounds.height = totalContentHeight + widget.padding.top + widget.padding.bottom
