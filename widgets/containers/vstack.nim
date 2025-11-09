## VStack Widget - Vertical Stack (Column)
##
## Uses composable layout helpers for clean, readable code
## Matches YAML-UI column syntax

import ../../core/[types, widget_dsl]
import ../../drawing_primitives/layout_containers
import ../../layout/layout_helpers

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

    # Calculate content area using helper
    let content = contentArea(widget.bounds, widget.padding)

    # Calculate total height of children using helper
    let totalHeight = totalChildrenSize(widget.children, isHorizontal = false)

    # Calculate spacing and start position using composable helper
    let distribution = calculateDistributedSpacing(
      widget.justify,
      content.height,
      totalHeight,
      widget.children.len,
      widget.spacing
    )

    # Position each child
    var y = content.y + distribution.startOffset
    for child in widget.children:
      # Calculate X position using alignment helper
      let xOffset = calculateAlignmentOffset(
        widget.align,
        content.width,
        child.bounds.width
      )

      child.bounds.x = content.x + xOffset
      child.bounds.y = y

      # Stretch width if needed
      if widget.align == Stretch:
        child.bounds.width = content.width

      # Layout the child
      child.layout()

      # Move Y down for next child
      y += child.bounds.height + distribution.spacing

  render:
    # VStack is invisible, just render children
    for child in widget.children:
      child.render()
