## HStack Widget - Horizontal Stack (Row)
##
## Uses composable layout helpers for clean, readable code
## Matches YAML-UI row syntax
## Horizontal counterpart to VStack

import ../../core/[types, widget_dsl]
import ../../drawing_primitives/layout_containers
import ../../layout/layout_helpers

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

    # Calculate content area using helper
    let content = contentArea(widget.bounds, widget.padding)

    # Calculate total width of children using helper
    let totalWidth = totalChildrenSize(widget.children, isHorizontal = true)

    # Calculate spacing and start position using composable helper
    let distribution = calculateDistributedSpacing(
      widget.justify,
      content.width,
      totalWidth,
      widget.children.len,
      widget.spacing
    )

    # Position each child
    var x = content.x + distribution.startOffset
    for child in widget.children:
      # Calculate Y position using alignment helper
      let yOffset = calculateAlignmentOffset(
        widget.align,
        content.height,
        child.bounds.height
      )

      child.bounds.x = x
      child.bounds.y = content.y + yOffset

      # Stretch height if needed
      if widget.align == Stretch:
        child.bounds.height = content.height

      # Layout the child
      child.layout()

      # Move X right for next child
      x += child.bounds.width + distribution.spacing

  render:
    # HStack is invisible, just render children
    for child in widget.children:
      child.render()
