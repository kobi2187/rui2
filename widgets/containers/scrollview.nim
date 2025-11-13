## ScrollView Widget - RUI2
##
## A scrollable container for content larger than the visible area.
## Supports horizontal and/or vertical scrolling with scrollbars.
## Ported from Hummingbird to RUI2's defineWidget DSL.

import ../../core/widget_dsl_v3
import std/options

when defined(useGraphics):
  import raylib

defineWidget(ScrollView):
  props:
    contentWidth: float = 0.0    # Content size (0 = auto-calculate)
    contentHeight: float = 0.0
    scrollX: bool = false        # Enable horizontal scrolling
    scrollY: bool = true         # Enable vertical scrolling
    scrollBarWidth: float = 12.0
    showScrollBars: bool = true

  state:
    scrollOffsetX: float
    scrollOffsetY: float

  actions:
    onScroll(offsetX: float, offsetY: float)

  events:
    on_mouse_wheel:
      # Handle mouse wheel scrolling
      when defined(useGraphics):
        if widget.scrollY:
          let wheelDelta = 0.0  # Would come from event
          let currentOffset = widget.scrollOffsetY
          let maxOffset = max(0.0, widget.contentHeight - widget.bounds.height)
          let newOffset = clamp(currentOffset - wheelDelta * 20.0, 0.0, maxOffset)

          widget.scrollOffsetY = newOffset

          if widget.onScroll.isSome:
            widget.onScroll.get()(widget.scrollOffsetX, newOffset)

          return true
      return false

  layout:
    # Children are positioned relative to scroll offset
    for child in widget.children:
      child.bounds.x = widget.bounds.x - widget.scrollOffsetX
      child.bounds.y = widget.bounds.y - widget.scrollOffsetY

      # If contentWidth/Height not specified, use child's size
      if widget.contentWidth == 0.0:
        child.bounds.width = child.bounds.width  # Keep existing
      else:
        child.bounds.width = widget.contentWidth

      if widget.contentHeight == 0.0:
        child.bounds.height = child.bounds.height  # Keep existing
      else:
        child.bounds.height = widget.contentHeight

      child.layout()

  render:
    when defined(useGraphics):
      # Calculate visible area (excluding scrollbars)
      let viewWidth = if widget.scrollY and widget.showScrollBars:
                        widget.bounds.width - widget.scrollBarWidth
                      else:
                        widget.bounds.width

      let viewHeight = if widget.scrollX and widget.showScrollBars:
                         widget.bounds.height - widget.scrollBarWidth
                       else:
                         widget.bounds.height

      # Draw vertical scrollbar if enabled
      if widget.scrollY and widget.showScrollBars:
        var scrollY = widget.scrollOffsetY.cint
        let maxScroll = max(0.0, widget.contentHeight - viewHeight).cint

        if GuiScrollBar(
          Rectangle(
            x: widget.bounds.x + viewWidth,
            y: widget.bounds.y,
            width: widget.scrollBarWidth,
            height: viewHeight
          ),
          scrollY,
          0,
          maxScroll
        ):
          widget.scrollOffsetY = scrollY.float

      # Draw horizontal scrollbar if enabled
      if widget.scrollX and widget.showScrollBars:
        var scrollX = widget.scrollOffsetX.cint
        let maxScroll = max(0.0, widget.contentWidth - viewWidth).cint

        if GuiScrollBar(
          Rectangle(
            x: widget.bounds.x,
            y: widget.bounds.y + viewHeight,
            width: viewWidth,
            height: widget.scrollBarWidth
          ),
          scrollX,
          0,
          maxScroll
        ):
          widget.scrollOffsetX = scrollX.float

      # Use scissor mode to clip content to visible area
      BeginScissorMode(
        widget.bounds.x.cint,
        widget.bounds.y.cint,
        viewWidth.cint,
        viewHeight.cint
      )

      # Render children (they're already offset by layout)
      for child in widget.children:
        child.render()

      EndScissorMode()
    else:
      # Non-graphics mode
      echo "ScrollView (", widget.contentWidth, "x", widget.contentHeight, "):"
      echo "  Offset: (", widget.scrollOffsetX, ", ", widget.scrollOffsetY, ")"
      for child in widget.children:
        echo "  ", child
