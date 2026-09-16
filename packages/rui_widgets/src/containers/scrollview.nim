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
import scroll_geometry
export scroll_geometry

import raylib

const
  BackgroundColor = Color(r: 245, g: 245, b: 245, a: 255)
  TrackColor = Color(r: 220, g: 220, b: 220, a: 255)
  BorderColor = Color(r: 180, g: 180, b: 180, a: 255)

proc asRectangle*(r: Rect): Rectangle =
  Rectangle(x: r.x, y: r.y, width: r.width, height: r.height)

template extent*(widget: untyped): ScrollExtent =
  ## The widget's content-against-viewport numbers. A template, not a proc: the
  ## ScrollView type does not exist until the macro below has expanded.
  ##
  ## layout and render both ask here, which is the point -- they used to work
  ## it out separately and disagreed about whether the scrollbars had already
  ## been taken out of the viewport.
  ScrollExtent(
    contentWidth: widget.contentWidth, contentHeight: widget.contentHeight,
    viewportWidth: widget.bounds.width - widget.padding * 2,
    viewportHeight: widget.bounds.height - widget.padding * 2,
    scrollbarWidth: widget.scrollbarWidth)

template thumbColor*(widget: untyped): Color =
  Color(r: widget.scrollbarColor.r, g: widget.scrollbarColor.g,
        b: widget.scrollbarColor.b, a: widget.scrollbarColor.a)

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

    let bars = scrollBarsFor(widget.extent)
    widget.scrollOffsetX = clamp(widget.scrollOffsetX, 0.0f,
                                 widget.extent.maxScrollX(bars))
    widget.scrollOffsetY = clamp(widget.scrollOffsetY, 0.0f,
                                 widget.extent.maxScrollY(bars))

  events:
    on_mouse_wheel:
      # Scroll vertically with mouse wheel
      widget.scrollOffsetY -= event.wheelDelta * widget.scrollSpeed

      # Trigger layout to re-clamp and reposition children
      widget.layoutDirty = true

      return true  # Event handled

  render:
    drawRectangle(widget.bounds.asRectangle, BackgroundColor)

    let bars = scrollBarsFor(widget.extent)

    if bars.vertical:
      let track = verticalTrack(widget.bounds, widget.padding,
                                widget.scrollbarWidth, bars)
      drawRectangle(track.asRectangle, TrackColor)
      let len = thumbLength(track.height, bars.innerHeight,
                            widget.contentHeight)
      let off = thumbOffset(track.height, len, widget.scrollOffsetY,
                            widget.extent.maxScrollY(bars))
      drawRectangle(Rectangle(x: track.x + 2, y: track.y + off,
                              width: track.width - 4, height: len),
                    widget.thumbColor)

    if bars.horizontal:
      let track = horizontalTrack(widget.bounds, widget.padding,
                                  widget.scrollbarWidth, bars)
      drawRectangle(track.asRectangle, TrackColor)
      let len = thumbLength(track.width, bars.innerWidth, widget.contentWidth)
      let off = thumbOffset(track.width, len, widget.scrollOffsetX,
                            widget.extent.maxScrollX(bars))
      drawRectangle(Rectangle(x: track.x + off, y: track.y + 2,
                              width: len, height: track.height - 4),
                    widget.thumbColor)

    drawRectangleLines(widget.bounds.asRectangle, 1.0, BorderColor)
