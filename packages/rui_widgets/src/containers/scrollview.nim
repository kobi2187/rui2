## ScrollView Container Widget
##
## A viewport over children that are larger than it. `layout` positions the
## children offset by the scroll amount and measures the content extent;
## `render` draws the scrollbars.
##
## It does NOT render its children, and must not. main_loop's renderPass draws
## each widget into its own RenderTexture2D and then composites its children's
## cached textures in -- so a container that also calls `child.render()` paints
## every child twice. Worse, renderPass zeroes the parent's bounds.x/y for the
## duration while leaving the children's absolute, so the second painting
## landed at the wrong coordinates entirely. That loop, and the
## beginScissorMode around it, have been removed.
##
## KNOWN GAP, issue #39: content is clipped to the ScrollView's own bounds,
## because that is the size of its render texture -- not to the viewport, which
## is smaller by the padding and the scrollbar width. So content can show
## underneath the scrollbars. The scissor call that used to be here could not
## have fixed it: raylib's BeginScissorMode computes its GL rectangle from the
## screen height, so inside beginTextureMode it clips the wrong region unless
## the texture happens to be screen-sized. A real fix belongs in renderPass,
## clipping the composite blit by source-rectangle maths rather than GL state.

import rui_core
import rui_drawing

import raylib

defineWidget(ScrollView):
  props:
    padding: float = 8.0
    scrollbarWidth: float = 16.0
    scrollbarColor: tuple[r, g, b, a: uint8] = (150'u8, 150'u8, 150'u8, 255'u8)
    scrollSpeed: float = 20.0  # Pixels per wheel tick

  state:
    scrollOffsetX: float
    scrollOffsetY: float
    contentWidth: float
    contentHeight: float

  layout:
    # Calculate total content size from children
    var maxX = 0.0f
    var maxY = 0.0f

    for child in widget.children:
      # Position child with scroll offset
      child.bounds.x = widget.bounds.x + widget.padding - widget.scrollOffsetX
      child.bounds.y = widget.bounds.y + widget.padding - widget.scrollOffsetY

      # Layout the child recursively
      child.layout()

      # Track content bounds
      let childRight = child.bounds.x + child.bounds.width - widget.bounds.x + widget.padding
      let childBottom = child.bounds.y + child.bounds.height - widget.bounds.y + widget.padding

      if childRight > maxX:
        maxX = childRight
      if childBottom > maxY:
        maxY = childBottom

    widget.contentWidth = maxX
    widget.contentHeight = maxY

    # Clamp scroll offsets to valid ranges
    let viewportWidth = widget.bounds.width - (widget.padding * 2)
    let viewportHeight = widget.bounds.height - (widget.padding * 2)

    # Reserve space for scrollbars if needed
    var effectiveViewportWidth = viewportWidth
    var effectiveViewportHeight = viewportHeight

    let needsVerticalScrollbar = widget.contentHeight > viewportHeight
    let needsHorizontalScrollbar = widget.contentWidth > viewportWidth

    if needsVerticalScrollbar:
      effectiveViewportWidth -= widget.scrollbarWidth
    if needsHorizontalScrollbar:
      effectiveViewportHeight -= widget.scrollbarWidth

    # Clamp scroll offsets
    let maxScrollX = max(0.0f, widget.contentWidth - effectiveViewportWidth)
    let maxScrollY = max(0.0f, widget.contentHeight - effectiveViewportHeight)

    widget.scrollOffsetX = clamp(widget.scrollOffsetX, 0.0f, maxScrollX)
    widget.scrollOffsetY = clamp(widget.scrollOffsetY, 0.0f, maxScrollY)

  events:
    on_mouse_wheel:
      # Scroll vertically with mouse wheel
      widget.scrollOffsetY -= event.wheelDelta * widget.scrollSpeed

      # Trigger layout to re-clamp and reposition children
      widget.layoutDirty = true

      return true  # Event handled

  render:
    # Draw background
    drawRectangle(
      Rectangle(
        x: widget.bounds.x,
        y: widget.bounds.y,
        width: widget.bounds.width,
        height: widget.bounds.height
      ),
      Color(r: 245, g: 245, b: 245, a: 255)  # Light gray background
    )

    # Determine which scrollbars to show
    let viewportWidth = widget.bounds.width - (widget.padding * 2)
    let viewportHeight = widget.bounds.height - (widget.padding * 2)

    let needsVerticalScrollbar = widget.contentHeight > viewportHeight
    let needsHorizontalScrollbar = widget.contentWidth > viewportWidth

    # Calculate viewport rectangle (for clipping)
    var viewportRect = Rect(
      x: widget.bounds.x + widget.padding,
      y: widget.bounds.y + widget.padding,
      width: viewportWidth,
      height: viewportHeight
    )

    # Adjust viewport if scrollbars are present
    if needsVerticalScrollbar:
      viewportRect.width -= widget.scrollbarWidth
    if needsHorizontalScrollbar:
      viewportRect.height -= widget.scrollbarWidth

    # Children are NOT rendered here -- renderPass composites them. See the
    # module comment.

    # Draw vertical scrollbar if needed
    if needsVerticalScrollbar:
      let scrollbarX = widget.bounds.x + widget.bounds.width - widget.scrollbarWidth
      let scrollbarY = widget.bounds.y + widget.padding
      let scrollbarHeight = if needsHorizontalScrollbar:
                              viewportHeight - widget.scrollbarWidth
                            else:
                              viewportHeight

      # Draw scrollbar track
      drawRectangle(
        Rectangle(
          x: scrollbarX,
          y: scrollbarY,
          width: widget.scrollbarWidth,
          height: scrollbarHeight
        ),
        Color(r: 220, g: 220, b: 220, a: 255)  # Track color
      )

      # Calculate thumb size and position
      let thumbRatio = viewportRect.height / widget.contentHeight
      let thumbHeight = max(20.0f, scrollbarHeight * thumbRatio)

      let scrollRatio = if widget.contentHeight > viewportRect.height:
                          widget.scrollOffsetY / (widget.contentHeight - viewportRect.height)
                        else:
                          0.0f

      let thumbY = scrollbarY + scrollRatio * (scrollbarHeight - thumbHeight)

      # Draw thumb
      drawRectangle(
        Rectangle(
          x: scrollbarX + 2,
          y: thumbY,
          width: widget.scrollbarWidth - 4,
          height: thumbHeight
        ),
        Color(
          r: widget.scrollbarColor.r,
          g: widget.scrollbarColor.g,
          b: widget.scrollbarColor.b,
          a: widget.scrollbarColor.a
        )
      )

    # Draw horizontal scrollbar if needed
    if needsHorizontalScrollbar:
      let scrollbarX = widget.bounds.x + widget.padding
      let scrollbarY = widget.bounds.y + widget.bounds.height - widget.scrollbarWidth
      let scrollbarWidth = if needsVerticalScrollbar:
                             viewportWidth - widget.scrollbarWidth
                           else:
                             viewportWidth

      # Draw scrollbar track
      drawRectangle(
        Rectangle(
          x: scrollbarX,
          y: scrollbarY,
          width: scrollbarWidth,
          height: widget.scrollbarWidth
        ),
        Color(r: 220, g: 220, b: 220, a: 255)  # Track color
      )

      # Calculate thumb size and position
      let thumbRatio = viewportRect.width / widget.contentWidth
      let thumbWidth = max(20.0f, scrollbarWidth * thumbRatio)

      let scrollRatio = if widget.contentWidth > viewportRect.width:
                          widget.scrollOffsetX / (widget.contentWidth - viewportRect.width)
                        else:
                          0.0f

      let thumbX = scrollbarX + scrollRatio * (scrollbarWidth - thumbWidth)

      # Draw thumb
      drawRectangle(
        Rectangle(
          x: thumbX,
          y: scrollbarY + 2,
          width: thumbWidth,
          height: widget.scrollbarWidth - 4
        ),
        Color(
          r: widget.scrollbarColor.r,
          g: widget.scrollbarColor.g,
          b: widget.scrollbarColor.b,
          a: widget.scrollbarColor.a
        )
      )

    # Draw border around viewport
    drawRectangleLines(
      Rectangle(
        x: widget.bounds.x,
        y: widget.bounds.y,
        width: widget.bounds.width,
        height: widget.bounds.height
      ),
      1.0,
      Color(r: 180, g: 180, b: 180, a: 255)
    )
