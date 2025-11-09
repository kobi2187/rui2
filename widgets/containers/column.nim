## Column Widget - Vertical layout container (Flutter-style)
##
## DEPRECATED: Use VStack instead, which provides the same functionality
## with more consistent naming (Justify/Alignment).
##
## Migration guide:
##   Column -> VStack
##   MainAxisAlignment -> Justify
##     MainStart -> Start
##     MainCenter -> Center
##     MainEnd -> End
##   CrossAxisAlignment -> Alignment
##     CrossStart -> Leading
##     CrossCenter -> Center
##     CrossEnd -> Trailing
##     CrossStretch -> Stretch
##
## Arranges children vertically with spacing
##
## Flutter equivalent:
##   Column(
##     mainAxisAlignment: MainAxisAlignment.start,
##     crossAxisAlignment: CrossAxisAlignment.start,
##     children: [...]
##   )

{.deprecated: "Use VStack instead - provides same functionality with consistent naming".}

import ../../core/[types, widget_dsl]
import std/math

export types, widget_dsl

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
    spacing: float32
    mainAxisAlignment: MainAxisAlignment
    crossAxisAlignment: CrossAxisAlignment
    padding: EdgeInsets

  init:
    widget.spacing = 0.0
    widget.mainAxisAlignment = MainStart
    widget.crossAxisAlignment = CrossStart
    widget.padding = EdgeInsets(top: 0, right: 0, bottom: 0, left: 0)

  layout:
    if widget.children.len == 0:
      return

    # Calculate available space inside padding
    let contentX = widget.bounds.x + widget.padding.left
    let contentY = widget.bounds.y + widget.padding.top
    let contentWidth = widget.bounds.width - widget.padding.left - widget.padding.right
    let contentHeight = widget.bounds.height - widget.padding.top - widget.padding.bottom

    # Calculate total height of all children + spacing
    var totalChildHeight = 0.0
    for child in widget.children:
      totalChildHeight += child.bounds.height

    let totalSpacing = if widget.children.len > 1:
                         widget.spacing * float32(widget.children.len - 1)
                       else:
                         0.0

    let totalContentHeight = totalChildHeight + totalSpacing

    # Calculate starting Y based on mainAxisAlignment
    var y = case widget.mainAxisAlignment
      of MainStart:
        contentY
      of MainCenter:
        contentY + (contentHeight - totalContentHeight) / 2.0
      of MainEnd:
        contentY + contentHeight - totalContentHeight
      of SpaceBetween, SpaceAround, SpaceEvenly:
        contentY

    # Calculate spacing for space-based alignments
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

    # Position children
    for child in widget.children:
      # X position based on crossAxisAlignment
      let childX = case widget.crossAxisAlignment
        of CrossStart:
          contentX
        of CrossCenter:
          contentX + (contentWidth - child.bounds.width) / 2.0
        of CrossEnd:
          contentX + contentWidth - child.bounds.width
        of CrossStretch:
          contentX

      child.bounds.x = childX
      child.bounds.y = y

      # Stretch width if needed
      if widget.crossAxisAlignment == CrossStretch:
        child.bounds.width = contentWidth

      # Layout the child
      child.layout()

      # Move y down for next child
      y += child.bounds.height + actualSpacing

  render:
    # Column itself is invisible, just render children
    for child in widget.children:
      child.render()
