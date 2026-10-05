## SplitView -- two panes with a draggable divider between them.
##
## Flutter has no splitter in its core, but desktop apps are built with them
## (an explorer beside an editor, an editor above a console), so it is part of
## the layout set. The first child takes `ratio` of the room, the second the
## rest, and dragging the divider changes the ratio. Neither pane is ever
## squeezed below `minFirst` / `minSecond`.
##
## ```nim
## ui:
##   SplitView(axis = Axis.horizontal, initialRatio = 0.3):
##     TreeView(...)
##     TextArea()
## ```
##
## `axis` is the direction the panes sit in, as for a Row: `horizontal` puts
## them side by side with a vertical divider. The divider's thickness is the
## theme's (twice its stroke width, at least 6px).

import rui_core
import rui_drawing

proc splitFirstSize*(avail, ratio, minFirst, minSecond: float32): float32 =
  ## Size of the first pane when `avail` is shared out by `ratio`, honouring
  ## both minimums. When the room cannot satisfy both, the ratio decides --
  ## the minimums are a preference, not a reason to overflow.
  let wanted = clamp(ratio, 0.0'f32, 1.0'f32) * avail
  if avail < minFirst + minSecond:
    return max(0.0'f32, wanted)
  clamp(wanted, minFirst, avail - minSecond)

proc splitRatioAt*(pos, origin, avail, thickness: float32): float32 =
  ## The ratio that puts the middle of the divider at `pos` (along the axis,
  ## in the same space as `origin`, the start of the widget).
  if avail <= 0: return 0.5
  clamp((pos - origin - thickness / 2) / avail, 0.0'f32, 1.0'f32)

template dividerOf(w: untyped): float32 =
  ## Divider thickness: the prop, else the theme's.
  themedSize(w.dividerThickness,
             max(6.0'f32, currentTheme.getThemeProps(w.intent).strokeWidth * 2))

template horizontalAxis(w: untyped): bool = w.axis == Axis.horizontal

template firstSizeOf(w: untyped): float32 =
  ## Where the divider currently sits, along the axis.
  splitFirstSize(
    (if w.horizontalAxis: w.bounds.width else: w.bounds.height) - w.dividerOf,
    w.ratio, w.minFirst, w.minSecond)

proc dividerRect*[W](w: W): Rect =
  ## The strip between the panes, in the widget's coordinates.
  let first = w.firstSizeOf
  if w.horizontalAxis:
    Rect(x: w.bounds.x + first, y: w.bounds.y, width: w.dividerOf, height: w.bounds.height)
  else:
    Rect(x: w.bounds.x, y: w.bounds.y + first, width: w.bounds.width, height: w.dividerOf)

proc splitNatural[W](widget: W, c: Constraints): Size =
  ## With no size given: the panes at their natural size, side by side, plus
  ## the divider. A fixed side is kept.
  let horizontal = widget.horizontalAxis
  var along, across = 0.0'f32
  for i, child in widget.children:
    if i > 1: break
    let s = child.measure(unbounded())
    along += (if horizontal: s.width else: s.height)
    across = max(across, (if horizontal: s.height else: s.width))
  along += widget.dividerOf
  Size(width: (if c.tightWidth and c.minWidth > 0: c.minWidth
               elif horizontal: along else: across),
       height: (if c.tightHeight and c.minHeight > 0: c.minHeight
                elif horizontal: across else: along))

defineWidget(SplitView):
  props:
    axis: Axis = Axis.horizontal
    initialRatio: float32 = 0.5        # share of the room the first pane takes
    minFirst: float32 = 48.0
    minSecond: float32 = 48.0
    dividerThickness: float32 = 0.0    # 0: the theme's
    intent: ThemeIntent = Default

  state:
    ratio: float32
    dragging: bool

  actions:
    onResize(ratio: float32)

  events:
    on_mouse_down:
      if widget.dividerRect.contains(event.mousePos.x, event.mousePos.y):
        widget.dragging = true
        return true
      return false

    on_mouse_move:
      let over = widget.dividerRect.contains(event.mousePos.x, event.mousePos.y)
      widget.cursorShape =
        if not (over or widget.dragging): csDefault
        elif widget.horizontalAxis: csResizeH
        else: csResizeV
      if widget.dragging:
        let thick = widget.dividerOf
        let along = if widget.horizontalAxis: event.mousePos.x else: event.mousePos.y
        let origin = if widget.horizontalAxis: widget.bounds.x else: widget.bounds.y
        let total = if widget.horizontalAxis: widget.bounds.width else: widget.bounds.height
        widget.ratio = splitRatioAt(along, origin, total - thick, thick)
        widget.layoutDirty = true
        widget.markDirtyToRoot()
        if widget.onResize != nil:
          widget.onResize(widget.ratio)
        return true
      return false

    on_mouse_up:
      if widget.dragging:
        widget.dragging = false
        widget.isDirty = true
        return true
      return false

  layout:
    let thick = widget.dividerOf
    let horizontal = widget.horizontalAxis
    let hasSize = widget.bounds.width > 0 and widget.bounds.height > 0

    if not hasSize:
      # Nothing assigned: the panes at their natural size, side by side.
      let own = widget.splitNatural(constraintsOf(widget.bounds))
      widget.bounds.width = own.width
      widget.bounds.height = own.height

    let first = widget.firstSizeOf
    let total = if horizontal: widget.bounds.width else: widget.bounds.height
    let secondStart = first + thick
    for i, child in widget.children:
      if i > 1: break                    # a SplitView has two panes
      let start = if i == 0: 0.0'f32 else: secondStart
      let size = if i == 0: first else: max(0.0'f32, total - secondStart)
      child.arrange(
        if horizontal:
          Rect(x: widget.bounds.x + start, y: widget.bounds.y,
               width: size, height: widget.bounds.height)
        else:
          Rect(x: widget.bounds.x, y: widget.bounds.y + start,
               width: widget.bounds.width, height: size))

  render:
    # The panes are composited by renderPass; only the divider is ours.
    let props = currentTheme.getThemeProps(widget.intent,
      if widget.dragging: Pressed elif widget.hovered: Hovered else: Normal)
    let strip = widget.dividerRect
    let color = if widget.dragging: props.activeColor.get(props.borderColor.get(GRAY))
                else: props.borderColor.get(GRAY)
    drawRect(strip, color.withAlpha(if widget.dragging: 1.0 else: 0.35))
    # A grip: three dots across the middle of the strip.
    let cx = strip.x + strip.width / 2
    let cy = strip.y + strip.height / 2
    let dot = max(1.0'f32, strip.width.min(strip.height) / 6)
    let step = dot * 3
    for k in -1 .. 1:
      let (dx, dy) = if widget.horizontalAxis: (0.0'f32, float32(k) * step)
                     else: (float32(k) * step, 0.0'f32)
      drawRect(Rect(x: cx + dx - dot / 2, y: cy + dy - dot / 2, width: dot, height: dot),
               props.foregroundColor.get(BLACK).withAlpha(0.6))

method computeSize*(widget: SplitView, c: Constraints): Size =
  if c.tightWidth and c.minWidth > 0 and c.tightHeight and c.minHeight > 0:
    Size(width: c.minWidth, height: c.minHeight)
  else:
    widget.splitNatural(c)
