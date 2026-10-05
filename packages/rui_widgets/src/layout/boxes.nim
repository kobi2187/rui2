## Padding, SizedBox, ConstrainedBox, Align, Center, Container.
##
## Flutter's single-child boxes. Each wraps one child (the first in its block)
## and decides that child's box; none of them draws anything except Container,
## which can paint a decoration behind it.
##
## ```nim
## ui:
##   Padding(padding = EdgeInsets.symmetric(horizontal = 16)):
##     SizedBox(height = 48):
##       Align(alignment = Alignment.centerRight):
##         Button(text = "Save")
## ```

import rui_core
import rui_drawing
import std/options

# Insets around the child.
defineWidget(Padding):
  props:
    padding: EdgeInsets = EdgeInsets()

  layout:
    wrapChild(widget, widget.padding)

# A fixed size; with no child it is an empty gap, the Flutter way to space
# things apart (`SizedBox(height = 12)`). A dimension of 0 is left to the
# child. The request goes through the same sizeRequest a `frame` modifier sets,
# so it wins over a parent's stretch.
defineWidget(SizedBox):
  props:
    width: float32 = 0.0
    height: float32 = 0.0

  init:
    widget.sizeRequest = Size(width: widget.width, height: widget.height)

  layout:
    widget.sizeRequest = Size(width: widget.width, height: widget.height)
    wrapChild(widget)

# Min / max limits on its child's size (BoxConstraints; a max of 0 is
# unbounded).
defineWidget(ConstrainedBox):
  props:
    constraints: BoxConstraints = BoxConstraints()

  init:
    widget.sizeMin = Size(width: widget.constraints.minWidth,
                          height: widget.constraints.minHeight)
    widget.sizeMax = Size(width: widget.constraints.maxWidth,
                          height: widget.constraints.maxHeight)

  layout:
    wrapChild(widget)

proc alignedSize(widget: Widget, c: Constraints): Size =
  ## Align's measure: a fixed side is kept, a free one is the child's.
  var natural = Size()
  if widget.children.len > 0:
    natural = widget.children[0].measure(unbounded())
  Size(width: (if c.tightWidth: c.minWidth else: natural.width),
       height: (if c.tightHeight: c.minHeight else: natural.height))

proc placeAligned(widget: Widget, alignment: Alignment) =
  ## The Align rule: the child at its natural size, placed by `alignment` in
  ## the box -- which is the parent's, or the child's own when unsized.
  let own = widget.alignedSize(constraintsOf(widget.bounds))
  widget.bounds.width = own.width
  widget.bounds.height = own.height
  if widget.children.len > 0:
    let child = widget.children[0]
    let natural = child.measure(unbounded())
    let off = alignmentOffset(alignment,
      (own.width - natural.width, own.height - natural.height))
    child.arrange(Rect(x: widget.bounds.x + off.x, y: widget.bounds.y + off.y,
                       width: natural.width, height: natural.height))

# Places its child inside its own box.
defineWidget(Align):
  props:
    alignment: Alignment = AlignmentCenter

  layout:
    placeAligned(widget, widget.alignment)

# Centres its child.
defineWidget(Center):
  layout:
    placeAligned(widget, AlignmentCenter)

# ----------------------------------------------------------------------------
# Container
# ----------------------------------------------------------------------------

type
  BorderSide* = object
    width*: float32
    color*: Color

  BoxDecoration* = object
    ## What a Container paints behind its child. Transparent colour and zero
    ## border width paint nothing.
    color*: Color
    border*: BorderSide
    borderRadius*: float32

proc all*(T: typedesc[BorderSide], width: float32, color: Color): BorderSide =
  BorderSide(width: width, color: color)

# Flutter's all-rounder: padding, a decoration, an optional fixed size and an
# alignment for its child, and margin outside all of it.
defineWidget(Container):
  props:
    width: float32 = 0.0
    height: float32 = 0.0
    padding: EdgeInsets = EdgeInsets()
    margin: EdgeInsets = EdgeInsets()
    color: Color = Color()                # shorthand for decoration.color
    decoration: BoxDecoration = BoxDecoration()
    alignment: Option[Alignment] = none(Alignment)

  init:
    widget.sizeRequest = Size(
      width: (if widget.width > 0: widget.width + widget.margin.horizontal else: 0.0'f32),
      height: (if widget.height > 0: widget.height + widget.margin.vertical else: 0.0'f32))

  layout:
    let inset = EdgeInsets(left: widget.margin.left + widget.padding.left,
                           top: widget.margin.top + widget.padding.top,
                           right: widget.margin.right + widget.padding.right,
                           bottom: widget.margin.bottom + widget.padding.bottom)
    if widget.alignment.isNone or widget.children.len == 0:
      wrapChild(widget, inset)
    else:
      # Aligned: the child at its natural size, placed inside the insets.
      let child = widget.children[0]
      let natural = child.measure(unbounded())
      if widget.bounds.width <= 0:
        widget.bounds.width = natural.width + inset.horizontal
      if widget.bounds.height <= 0:
        widget.bounds.height = natural.height + inset.vertical
      let off = alignmentOffset(widget.alignment.get,
        (widget.bounds.width - inset.horizontal - natural.width,
         widget.bounds.height - inset.vertical - natural.height))
      child.arrange(Rect(x: widget.bounds.x + inset.left + off.x,
                         y: widget.bounds.y + inset.top + off.y,
                         width: natural.width, height: natural.height))

  render:
    let d = widget.decoration
    let fill = if widget.color.a > 0: widget.color else: d.color
    let box = Rect(x: widget.bounds.x + widget.margin.left,
                   y: widget.bounds.y + widget.margin.top,
                   width: widget.bounds.width - widget.margin.horizontal,
                   height: widget.bounds.height - widget.margin.vertical)
    if fill.a > 0:
      if d.borderRadius > 0: drawRoundedRect(box, d.borderRadius, fill)
      else: drawRect(box, fill)
    if d.border.width > 0 and d.border.color.a > 0:
      drawRoundedRectLines(box, d.borderRadius, d.border.width, d.border.color)

# Measuring without laying out (see `measure`).
method computeSize*(widget: Padding, c: Constraints): Size = widget.wrapSize(c, widget.padding)
method computeSize*(widget: SizedBox, c: Constraints): Size = widget.wrapSize(c)
method computeSize*(widget: ConstrainedBox, c: Constraints): Size = widget.wrapSize(c)
method computeSize*(widget: Align, c: Constraints): Size = widget.alignedSize(c)
method computeSize*(widget: Center, c: Constraints): Size = widget.alignedSize(c)
