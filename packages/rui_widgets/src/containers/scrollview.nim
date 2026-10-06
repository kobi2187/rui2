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
## Content is clipped to the viewport -- bounds less the padding and whichever
## scrollbars are showing -- through `Widget.childClip`, which renderPass honours
## when it composites. Not through raylib's BeginScissorMode, which is unusable
## here: it computes its GL rectangle from the *screen* height, so inside
## beginTextureMode, where the bound framebuffer is this widget's own render
## texture, it clips the wrong region unless the texture happens to be
## screen-sized. Clipping by source rectangle is arithmetic rather than GL
## state, and is correct at any size.

import rui_core
import rui_drawing
import scroll_geometry
export scroll_geometry

import raylib

template scrollbarWidthOf(w: untyped): float =
  ## Scrollbar thickness: the prop, else the theme's (16 if it names none).
  themedSize(w.scrollbarWidth, currentTheme.metrics.scrollbarThickness.get(16.0))

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
    scrollbarWidth: scrollbarWidthOf(widget))

template thumbColor*(widget: untyped): Color =
  Color(r: widget.scrollbarColor.r, g: widget.scrollbarColor.g,
        b: widget.scrollbarColor.b, a: widget.scrollbarColor.a)

template barGeometry*(widget: untyped, vertical: bool):
    tuple[track, thumb: Rect, maxScroll: float32] =
  ## One scroll bar's track and thumb, and how far that axis scrolls.
  block:
    let bars = scrollBarsFor(widget.extent)
    if vertical:
      let track = verticalTrack(widget.bounds, widget.padding,
                                scrollbarWidthOf(widget), bars)
      let len = thumbLength(track.height, bars.innerHeight, widget.contentHeight)
      let maxS = widget.extent.maxScrollY(bars)
      let off = thumbOffset(track.height, len, widget.scrollOffsetY, maxS)
      (track, Rect(x: track.x, y: track.y + off, width: track.width, height: len), maxS.float32)
    else:
      let track = horizontalTrack(widget.bounds, widget.padding,
                                  scrollbarWidthOf(widget), bars)
      let len = thumbLength(track.width, bars.innerWidth, widget.contentWidth)
      let maxS = widget.extent.maxScrollX(bars)
      let off = thumbOffset(track.width, len, widget.scrollOffsetX, maxS)
      (track, Rect(x: track.x + off, y: track.y, width: len, height: track.height), maxS.float32)

template scrollTo(widget: untyped, vertical: bool, value: float) =
  ## Set one axis's offset, within the content, and re-place the children.
  block:
    let bars = scrollBarsFor(widget.extent)
    if vertical:
      widget.scrollOffsetY = clamp(value, 0.0, widget.extent.maxScrollY(bars))
    else:
      widget.scrollOffsetX = clamp(value, 0.0, widget.extent.maxScrollX(bars))
    widget.layoutDirty = true
    widget.isDirty = true

defineWidget(ScrollView):
  props:
    padding: float = 8.0
    scrollbarWidth: float = 0.0   # 0: the theme's
    scrollbarColor: tuple[r, g, b, a: uint8] = (150'u8, 150'u8, 150'u8, 255'u8)
    scrollSpeed: float = 20.0  # Pixels per wheel tick

  state:
    scrollOffsetX: float
    scrollOffsetY: float
    contentWidth: float
    contentHeight: float
    dragAxis: int                # 0 none, 1 the vertical thumb, 2 the horizontal
    dragGrab: float32            # where on the thumb it was taken

  layout:
    # Keep the offset inside what the content allowed last time *before* the
    # children are placed by it; clamping afterwards left them at a stale
    # offset for a frame, and one beyond the end placed them off the screen.
    let before = scrollBarsFor(widget.extent)
    widget.scrollOffsetX = clamp(widget.scrollOffsetX, 0.0f,
                                 widget.extent.maxScrollX(before))
    widget.scrollOffsetY = clamp(widget.scrollOffsetY, 0.0f,
                                 widget.extent.maxScrollY(before))

    # Calculate total content size from children
    var maxX = 0.0f
    var maxY = 0.0f

    for child in widget.children:
      # The content at its natural size, shifted by the scroll offset. Its
      # measurement is remembered, so scrolling only moves it.
      let natural = child.measure(unbounded())
      child.arrange(Rect(x: widget.bounds.x + widget.padding - widget.scrollOffsetX,
                         y: widget.bounds.y + widget.padding - widget.scrollOffsetY,
                         width: natural.width, height: natural.height))

      # Track content bounds
      # In the content's own coordinates: the scroll offset is added back, or
      # the content would measure shorter the further it was scrolled, and the
      # end would slide out of reach.
      let childRight = child.bounds.x + widget.scrollOffsetX + child.bounds.width -
                       widget.bounds.x + widget.padding
      let childBottom = child.bounds.y + widget.scrollOffsetY + child.bounds.height -
                        widget.bounds.y + widget.padding

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

    # Widget-local, because renderPass zeroes bounds.x/y while compositing.
    widget.childClip = some(Rect(
      x: widget.padding, y: widget.padding,
      width: bars.innerWidth, height: bars.innerHeight))

  events:
    on_mouse_wheel:
      # Down the content; with Shift, or when only the horizontal bar shows,
      # across it. At the end of the travel the wheel is left to an
      # enclosing scroll view.
      let bars = scrollBarsFor(widget.extent)
      let sideways = event.shift or (bars.horizontal and not bars.vertical)
      let before = if sideways: widget.scrollOffsetX else: widget.scrollOffsetY
      widget.scrollTo(not sideways, before - event.wheelDelta * widget.scrollSpeed)
      let after = if sideways: widget.scrollOffsetX else: widget.scrollOffsetY
      return after != before

    on_mouse_down:
      # The thumb is dragged where it was taken; a press elsewhere on the
      # track moves a page towards the pointer.
      let bars = scrollBarsFor(widget.extent)
      for vertical in [true, false]:
        if (vertical and not bars.vertical) or (not vertical and not bars.horizontal):
          continue
        let g = widget.barGeometry(vertical)
        if not g.track.contains(event.mousePos.x, event.mousePos.y):
          continue
        let along = if vertical: event.mousePos.y else: event.mousePos.x
        let thumbStart = if vertical: g.thumb.y else: g.thumb.x
        let thumbLen = if vertical: g.thumb.height else: g.thumb.width
        if along >= thumbStart and along <= thumbStart + thumbLen:
          widget.dragAxis = if vertical: 1 else: 2
          widget.dragGrab = along - thumbStart
        else:
          let page = if vertical: bars.innerHeight else: bars.innerWidth
          let current = if vertical: widget.scrollOffsetY else: widget.scrollOffsetX
          widget.scrollTo(vertical, current + (if along < thumbStart: -page else: page))
        return true
      return false

    on_mouse_move:
      if widget.dragAxis == 0:
        return false
      let vertical = widget.dragAxis == 1
      let g = widget.barGeometry(vertical)
      let along = if vertical: event.mousePos.y else: event.mousePos.x
      let start = if vertical: g.track.y else: g.track.x
      let travel = (if vertical: g.track.height - g.thumb.height
                    else: g.track.width - g.thumb.width)
      if travel > 0:
        widget.scrollTo(vertical, (along - widget.dragGrab - start) / travel * g.maxScroll)
      return true

    on_mouse_up:
      if widget.dragAxis == 0:
        return false
      widget.dragAxis = 0
      widget.isDirty = true
      return true

  render:
    drawRectangle(widget.bounds.asRectangle, BackgroundColor)

    let bars = scrollBarsFor(widget.extent)

    if bars.vertical:
      let track = verticalTrack(widget.bounds, widget.padding,
                                scrollbarWidthOf(widget), bars)
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
                                  scrollbarWidthOf(widget), bars)
      drawRectangle(track.asRectangle, TrackColor)
      let len = thumbLength(track.width, bars.innerWidth, widget.contentWidth)
      let off = thumbOffset(track.width, len, widget.scrollOffsetX,
                            widget.extent.maxScrollX(bars))
      drawRectangle(Rectangle(x: track.x + off, y: track.y + 2,
                              width: len, height: track.height - 4),
                    widget.thumbColor)

    drawRectangleLines(widget.bounds.asRectangle, 1.0, BorderColor)
