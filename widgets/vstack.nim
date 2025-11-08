## VStack Widget - Vertical Stack (Column)
##
## Uses existing layout types from layout_containers.nim
## Matches YAML-UI column syntax

import ../core/[types, widget_dsl]
import ../drawing_primitives/layout_containers

export types, widget_dsl
# Re-export only the types we need, not the constructors
export Alignment, Justify

defineWidget(VStack):
  props:
    spacing: float32
    align: Alignment      # Cross-axis (horizontal) alignment
    justify: Justify      # Main-axis (vertical) distribution
    padding: EdgeInsets

  init:
    widget.spacing = 0.0
    widget.align = Leading
    widget.justify = Start
    widget.padding = EdgeInsets(top: 0, right: 0, bottom: 0, left: 0)

  layout:
    if widget.children.len == 0:
      return

    # Calculate content area (inside padding)
    let contentX = widget.bounds.x + widget.padding.left
    let contentY = widget.bounds.y + widget.padding.top
    let contentWidth = widget.bounds.width - widget.padding.left - widget.padding.right
    let contentHeight = widget.bounds.height - widget.padding.top - widget.padding.bottom

    # Calculate total height of children
    var totalHeight = 0.0
    for child in widget.children:
      totalHeight += child.bounds.height

    # Add spacing between items
    let totalSpacing = if widget.children.len > 1:
                         widget.spacing * float32(widget.children.len - 1)
                       else:
                         0.0

    let totalContentHeight = totalHeight + totalSpacing

    # Calculate starting Y based on justify (main axis)
    var y = case widget.justify
      of Start:
        contentY
      of Center:
        contentY + (contentHeight - totalContentHeight) / 2.0
      of End:
        contentY + contentHeight - totalContentHeight
      of SpaceBetween, SpaceAround, SpaceEvenly:
        contentY

    # Calculate actual spacing for space-based justification
    var actualSpacing = widget.spacing
    if widget.children.len > 1:
      case widget.justify
      of SpaceBetween:
        actualSpacing = (contentHeight - totalHeight) / float32(widget.children.len - 1)
      of SpaceAround:
        actualSpacing = (contentHeight - totalHeight) / float32(widget.children.len)
        y += actualSpacing / 2.0
      of SpaceEvenly:
        actualSpacing = (contentHeight - totalHeight) / float32(widget.children.len + 1)
        y += actualSpacing
      else:
        discard

    # Position each child
    for child in widget.children:
      # X position based on align (cross axis)
      let childX = case widget.align
        of Leading, Left:
          contentX
        of Center:
          contentX + (contentWidth - child.bounds.width) / 2.0
        of Trailing, Right:
          contentX + contentWidth - child.bounds.width
        of Stretch:
          contentX
        else:
          contentX

      child.bounds.x = childX
      child.bounds.y = y

      # Stretch width if needed
      if widget.align == Stretch:
        child.bounds.width = contentWidth

      # Layout the child
      child.layout()

      # Move Y down for next child
      y += child.bounds.height + actualSpacing

  render:
    # VStack is invisible, just render children
    for child in widget.children:
      child.render()
