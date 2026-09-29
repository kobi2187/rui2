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

template placeAligned(widget: untyped, alignment: Alignment) =
  ## The Align rule: the child at its natural size, placed by `alignment` in
  ## the box -- which is the parent's, or the child's own when unsized.
  if widget.children.len > 0:
    let child = widget.children[0]
    child.bounds.width = 0
    child.bounds.height = 0
    child.bounds.x = widget.bounds.x
    child.bounds.y = widget.bounds.y
    child.layout()
    if widget.bounds.width <= 0: widget.bounds.width = child.bounds.width
    if widget.bounds.height <= 0: widget.bounds.height = child.bounds.height
    let off = alignmentOffset(alignment,
      (widget.bounds.width - child.bounds.width,
       widget.bounds.height - child.bounds.height))
    if off.x != 0 or off.y != 0:
      child.bounds.x = widget.bounds.x + off.x
      child.bounds.y = widget.bounds.y + off.y
      child.layout()

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
      # Aligned: size the box first, then place the child inside the insets.
      let child = widget.children[0]
      child.bounds = Rect(x: widget.bounds.x + inset.left,
                          y: widget.bounds.y + inset.top)
      child.layout()
      if widget.bounds.width <= 0:
        widget.bounds.width = child.bounds.width + inset.horizontal
      if widget.bounds.height <= 0:
        widget.bounds.height = child.bounds.height + inset.vertical
      let off = alignmentOffset(widget.alignment.get,
        (widget.bounds.width - inset.horizontal - child.bounds.width,
         widget.bounds.height - inset.vertical - child.bounds.height))
      child.bounds.x = widget.bounds.x + inset.left + off.x
      child.bounds.y = widget.bounds.y + inset.top + off.y
      child.layout()

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
