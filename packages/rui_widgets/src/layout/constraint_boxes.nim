## The boxes that change the constraints their child sees -- Flutter's, one
## render object each:
##
## - `UnconstrainedBox`: the child at its natural size, whatever the parent
##   allows. The way back to "my size wins" (the CSS rule): inside a stretch,
##   an Expanded or a tight parent, the child keeps its own size and the box
##   takes the parent's, the child overflowing it if it must.
## - `OverflowBox`: the child under constraints of your choosing, which may be
##   bigger than the parent's; the box itself is as big as the parent allows.
## - `LimitedBox`: a size limit that only applies where the parent has none
##   (inside a scroll view, along a Row) -- "fill, but not infinitely".
## - `AspectRatio`: width / height fixed, as big as the constraints allow.
## - `FractionallySizedBox`: a share of the room the parent gives.
## - `IntrinsicWidth` / `IntrinsicHeight`: every child as wide / tall as the
##   widest / tallest wants to be ("make the stretched divider as tall as the
##   tallest card").
## - `Offstage` and `Visibility`: laid out or not, shown or not, taking room
##   or not.
##
## ```nim
## ui:
##   Row(crossAxisAlignment = CrossAxisAlignment.stretch):
##     UnconstrainedBox():                 # not stretched: keeps its 40 px
##       Button(text = "OK")
##     AspectRatio(aspectRatio = 16 / 9):
##       ImageWidget(imagePath = "cover.png")
## ```

import rui_core
import std/math

proc child0(widget: Widget): Widget =
  if widget.children.len > 0: widget.children[0] else: nil

proc placeChild(widget: Widget, size: Size, alignment = AlignmentCenter) =
  ## The child at `size`, placed in the box by `alignment` (it may overflow).
  let child = widget.child0
  if child == nil: return
  let off = alignmentOffset(alignment, (widget.bounds.width - size.width,
                                        widget.bounds.height - size.height))
  child.arrange(Rect(x: widget.bounds.x + off.x, y: widget.bounds.y + off.y,
                     width: size.width, height: size.height))

proc settle(widget: Widget): Constraints =
  ## Arrange's first step for these boxes: its own size from its measure.
  result = widget.arrangeConstraints
  let own = result.constrain(widget.measure(result))
  widget.bounds.width = own.width
  widget.bounds.height = own.height

# --- UnconstrainedBox ----------------------------------------------------------

proc unconstrainedChild(widget: Widget, c: Constraints, constrainedAxis: int): Constraints =
  ## `constrainedAxis`: 0 none, 1 keep the parent's width limits, 2 its height's.
  result = unbounded()
  if constrainedAxis == 1:
    result.minWidth = c.minWidth; result.maxWidth = c.maxWidth
  elif constrainedAxis == 2:
    result.minHeight = c.minHeight; result.maxHeight = c.maxHeight

defineWidget(UnconstrainedBox):
  props:
    alignment: Alignment = AlignmentCenter
    constrainedAxis: int = 0       ## 0 none, 1 horizontal, 2 vertical: that axis stays the parent's

  layout:
    let given = widget.settle()
    let child = widget.child0
    if child != nil:
      widget.placeChild(child.measure(unconstrainedChild(widget, given, widget.constrainedAxis)),
                        widget.alignment)

method computeSize*(widget: UnconstrainedBox, c: Constraints): Size =
  let child = widget.child0
  let natural = if child == nil: Size()
                else: child.measure(unconstrainedChild(widget, c, widget.constrainedAxis))
  c.constrain(natural)

# --- OverflowBox ------------------------------------------------------------------

proc overflowConstraints(widget: Widget, c: Constraints,
                         minW, maxW, minH, maxH: float32): Constraints =
  ## Each limit given (not NaN) replaces the parent's.
  Constraints(minWidth: (if minW.isNaN: c.minWidth else: minW),
              maxWidth: (if maxW.isNaN: c.maxWidth else: maxW),
              minHeight: (if minH.isNaN: c.minHeight else: minH),
              maxHeight: (if maxH.isNaN: c.maxHeight else: maxH))

defineWidget(OverflowBox):
  props:
    alignment: Alignment = AlignmentCenter
    minWidth: float32 = NaN
    maxWidth: float32 = NaN
    minHeight: float32 = NaN
    maxHeight: float32 = NaN

  layout:
    let given = widget.settle()
    let child = widget.child0
    if child != nil:
      widget.placeChild(child.measure(overflowConstraints(widget, given, widget.minWidth,
        widget.maxWidth, widget.minHeight, widget.maxHeight)), widget.alignment)

method computeSize*(widget: OverflowBox, c: Constraints): Size =
  ## As big as the parent allows; the child is measured (and may overflow) in
  ## layout. On an unbounded axis there is no "as big", so it is the smallest.
  let child = widget.child0
  if child != nil:
    discard child.measure(overflowConstraints(widget, c, widget.minWidth, widget.maxWidth,
                                              widget.minHeight, widget.maxHeight))
  Size(width: (if c.hasBoundedWidth: c.maxWidth else: c.minWidth),
       height: (if c.hasBoundedHeight: c.maxHeight else: c.minHeight))

# --- LimitedBox ---------------------------------------------------------------------

proc limited(c: Constraints, maxW, maxH: float32): Constraints =
  result = c
  if not c.hasBoundedWidth: result.maxWidth = max(c.minWidth, maxW)
  if not c.hasBoundedHeight: result.maxHeight = max(c.minHeight, maxH)

defineWidget(LimitedBox):
  props:
    maxWidth: float32 = Inf
    maxHeight: float32 = Inf

  layout:
    let given = widget.settle()
    let child = widget.child0
    if child != nil:
      child.arrange(Rect(x: widget.bounds.x, y: widget.bounds.y,
                         width: widget.bounds.width, height: widget.bounds.height))
    discard given

method computeSize*(widget: LimitedBox, c: Constraints): Size =
  widget.wrapSize(limited(c, widget.maxWidth, widget.maxHeight))

# --- AspectRatio ------------------------------------------------------------------------

proc aspectSize(c: Constraints, ratio: float32): Size =
  ## Flutter's RenderAspectRatio._applyAspectRatio.
  if c.tightWidth and c.tightHeight: return Size(width: c.minWidth, height: c.minHeight)
  let r = max(0.0001'f32, ratio)
  var w = c.maxWidth
  var h: float32
  if w < Inf: h = w / r
  else:
    h = c.maxHeight
    w = h * r
  if w > c.maxWidth: (w = c.maxWidth; h = w / r)
  if h > c.maxHeight: (h = c.maxHeight; w = h * r)
  if w < c.minWidth: (w = c.minWidth; h = w / r)
  if h < c.minHeight: (h = c.minHeight; w = h * r)
  if w == Inf or h == Inf: return Size()       # unbounded both ways: nothing to fit
  c.constrain(Size(width: w, height: h))

defineWidget(AspectRatio):
  props:
    aspectRatio: float32 = 1.0     ## width / height

  layout:
    discard widget.settle()
    let child = widget.child0
    if child != nil:
      child.arrange(Rect(x: widget.bounds.x, y: widget.bounds.y,
                         width: widget.bounds.width, height: widget.bounds.height))

method computeSize*(widget: AspectRatio, c: Constraints): Size =
  result = aspectSize(c, widget.aspectRatio)
  let child = widget.child0
  if child != nil: discard child.measure(tight(result))

# --- FractionallySizedBox ----------------------------------------------------------------

proc fractionConstraints(c: Constraints, wf, hf: float32): Constraints =
  result = c
  if not wf.isNaN and c.hasBoundedWidth:
    let w = c.maxWidth * wf
    result.minWidth = w; result.maxWidth = w
  if not hf.isNaN and c.hasBoundedHeight:
    let h = c.maxHeight * hf
    result.minHeight = h; result.maxHeight = h

defineWidget(FractionallySizedBox):
  props:
    widthFactor: float32 = NaN     ## a share of the parent's width; NaN: the parent's constraints
    heightFactor: float32 = NaN
    alignment: Alignment = AlignmentCenter

  layout:
    let given = widget.settle()
    let child = widget.child0
    if child != nil:
      widget.placeChild(child.measure(fractionConstraints(given, widget.widthFactor,
                                                          widget.heightFactor)), widget.alignment)

method computeSize*(widget: FractionallySizedBox, c: Constraints): Size =
  let inner = fractionConstraints(c, widget.widthFactor, widget.heightFactor)
  let child = widget.child0
  if child != nil: c.constrain(child.measure(inner))
  else: c.constrain(inner.constrain(Size()))

# --- IntrinsicWidth / IntrinsicHeight -----------------------------------------------------
#
# Flutter asks the child for its intrinsic size; here that is its measure with
# the axis unbounded (and the other as given), which is what the intrinsic
# is for the containers that hold such rows and columns.

proc intrinsicConstraints(widget: Widget, c: Constraints, horizontal: bool): Constraints =
  result = c
  let child = widget.child0
  if child == nil: return
  if horizontal and not c.tightWidth:
    var free = c
    free.minWidth = 0; free.maxWidth = Inf
    let w = clamp(child.measure(free).width, c.minWidth, c.maxWidth)
    result.minWidth = w; result.maxWidth = w
  elif not horizontal and not c.tightHeight:
    var free = c
    free.minHeight = 0; free.maxHeight = Inf
    let h = clamp(child.measure(free).height, c.minHeight, c.maxHeight)
    result.minHeight = h; result.maxHeight = h

defineWidget(IntrinsicWidth):
  layout:
    discard widget.settle()
    let child = widget.child0
    if child != nil:
      child.arrange(Rect(x: widget.bounds.x, y: widget.bounds.y,
                         width: widget.bounds.width, height: widget.bounds.height))

defineWidget(IntrinsicHeight):
  layout:
    discard widget.settle()
    let child = widget.child0
    if child != nil:
      child.arrange(Rect(x: widget.bounds.x, y: widget.bounds.y,
                         width: widget.bounds.width, height: widget.bounds.height))

method computeSize*(widget: IntrinsicWidth, c: Constraints): Size =
  widget.wrapSize(intrinsicConstraints(widget, c, horizontal = true))
method computeSize*(widget: IntrinsicHeight, c: Constraints): Size =
  widget.wrapSize(intrinsicConstraints(widget, c, horizontal = false))

# --- Offstage / Visibility ------------------------------------------------------------------

defineWidget(Offstage):
  ## The child is laid out but not shown, and takes no room.
  props:
    offstage: bool = true

  layout:
    let given = widget.settle()
    let child = widget.child0
    if child != nil:
      child.visible = not widget.offstage
      let s = child.measure(given)
      child.arrange(Rect(x: widget.bounds.x, y: widget.bounds.y, width: s.width, height: s.height))

method computeSize*(widget: Offstage, c: Constraints): Size =
  if not widget.offstage: return widget.wrapSize(c)
  let child = widget.child0
  if child != nil: discard child.measure(c)
  c.constrain(Size())

defineWidget(Visibility):
  ## Shown, or hidden -- and then either gone (no room) or, with
  ## `maintainSize`, an empty space of the child's size. Flutter's `visible`
  ## is `shown` here: every widget already has a `visible` field.
  props:
    shown: bool = true
    maintainSize: bool = false

  layout:
    let given = widget.settle()
    let child = widget.child0
    if child != nil:
      child.visible = widget.shown
      let s = if widget.shown or widget.maintainSize: Size(width: widget.bounds.width,
                                                             height: widget.bounds.height)
              else: child.measure(given)
      child.arrange(Rect(x: widget.bounds.x, y: widget.bounds.y, width: s.width, height: s.height))

method computeSize*(widget: Visibility, c: Constraints): Size =
  if widget.shown or widget.maintainSize: widget.wrapSize(c)
  else: c.constrain(Size())
