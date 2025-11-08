## HStack Widget - Horizontal Stack (Row)
##
## Uses existing layout types from layout_containers.nim
## Matches YAML-UI row syntax
## Horizontal counterpart to VStack

import ../core/[types, widget_dsl]
import ../drawing_primitives/layout_containers

export types, widget_dsl
# Re-export only the types we need, not the constructors
export Alignment, Justify

defineWidget(HStack):
  props:
    spacing: float32
    align: Alignment      # Cross-axis (vertical) alignment
    justify: Justify      # Main-axis (horizontal) distribution
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

    # Calculate total width of children
    var totalWidth = 0.0
    for child in widget.children:
      totalWidth += child.bounds.width

    # Add spacing between items
    let totalSpacing = if widget.children.len > 1:
                         widget.spacing * float32(widget.children.len - 1)
                       else:
                         0.0

    let totalContentWidth = totalWidth + totalSpacing

    # Calculate starting X based on justify (main axis)
    var x = case widget.justify
      of Start:
        contentX
      of Center:
        contentX + (contentWidth - totalContentWidth) / 2.0
      of End:
        contentX + contentWidth - totalContentWidth
      of SpaceBetween, SpaceAround, SpaceEvenly:
        contentX

    # Calculate actual spacing for space-based justification
    var actualSpacing = widget.spacing
    if widget.children.len > 1:
      case widget.justify
      of SpaceBetween:
        actualSpacing = (contentWidth - totalWidth) / float32(widget.children.len - 1)
      of SpaceAround:
        actualSpacing = (contentWidth - totalWidth) / float32(widget.children.len)
        x += actualSpacing / 2.0
      of SpaceEvenly:
        actualSpacing = (contentWidth - totalWidth) / float32(widget.children.len + 1)
        x += actualSpacing
      else:
        discard

    # Position each child
    for child in widget.children:
      # Y position based on align (cross axis)
      let childY = case widget.align
        of Leading, Top:
          contentY
        of Center:
          contentY + (contentHeight - child.bounds.height) / 2.0
        of Trailing, Bottom:
          contentY + contentHeight - child.bounds.height
        of Stretch:
          contentY
        else:
          contentY

      child.bounds.x = x
      child.bounds.y = childY

      # Stretch height if needed
      if widget.align == Stretch:
        child.bounds.height = contentHeight

      # Layout the child
      child.layout()

      # Move X right for next child
      x += child.bounds.width + actualSpacing

  render:
    # HStack is invisible, just render children
    for child in widget.children:
      child.render()
