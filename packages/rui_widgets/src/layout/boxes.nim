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
import std/[options, math]

# Insets around the child.
defineWidget(Padding):
  props:
    padding: EdgeInsets = EdgeInsets()

  layout:
    wrapChild(widget, widget.padding)

# A fixed size; with no child it is an empty gap, the Flutter way to space
# things apart (`SizedBox(height = 12)`). As in Flutter: a dimension left out
# (NaN, the default) is the child's, 0 is zero, `Inf` is as big as the parent
# allows (SizedBox.expand) -- and the size is a wish within the parent's
# constraints, so a stretch or a smaller parent wins.
defineWidget(SizedBox):
  props:
    width: float32 = NaN
    height: float32 = NaN

  layout:
    let own = widget.applySizing(constraintsOf(widget.bounds))
    let size = own.constrain(widget.wrapSize(own))
    widget.bounds.width = size.width
    widget.bounds.height = size.height
    wrapChild(widget)

method ownConstraints*(widget: SizedBox): Constraints =
  result = procCall ownConstraints(Widget(widget))
  if not widget.width.isNaN: result = result.withWidth(max(0.0'f32, widget.width))
  if not widget.height.isNaN: result = result.withHeight(max(0.0'f32, widget.height))

proc expand*(T: typedesc[SizedBox]): SizedBox =
  ## As big as the parent allows.
  newSizedBox(width = Inf, height = Inf)

proc shrink*(T: typedesc[SizedBox]): SizedBox =
  ## Zero by zero.
  newSizedBox(width = 0, height = 0)

# Min / max limits on its child's size (BoxConstraints; a max of 0 is
# unbounded), within the parent's constraints: the parent wins.
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

# ----------------------------------------------------------------------------
# Spacing modifiers
#
# `Button(text = "Save").margin(8)` is `Padding(padding = ...): Button(...)`
# without the nesting. They return the Padding they put around the widget, so
# later modifiers in a chain (`.flex`, `.frame`) apply to the whole padded box.
# For an undecorated widget `margin` and `padding` are the same thing; to pad
# inside a painted background use Container's own `padding` and `color`.
# ----------------------------------------------------------------------------

proc wrapped(widget: Widget, insets: EdgeInsets): Padding =
  result = newPadding(padding = insets)
  result.addChild widget

proc margin*(widget: Widget, insets: EdgeInsets): Padding = widget.wrapped(insets)
proc margin*(widget: Widget, all: float32): Padding = widget.wrapped(EdgeInsets.all(all))
proc margin*(widget: Widget, css: string): Padding =
  ## CSS shorthand as in yui: "16px", "8px 16px", "1px 2px 3px 4px".
  let insets = parseCssInsets(css)
  if insets.isNone:
    raise newException(ValueError, "not a padding value: '" & css & "'")
  widget.wrapped(insets.get)

proc padding*(widget: Widget, insets: EdgeInsets): Padding = widget.wrapped(insets)
proc padding*(widget: Widget, all: float32): Padding = widget.wrapped(EdgeInsets.all(all))
proc padding*(widget: Widget, css: string): Padding = widget.margin(css)

proc alignedSize(widget: Widget, c: Constraints, widthFactor, heightFactor: float32): Size =
  ## Align's measure (Flutter's RenderPositionedBox): as big as the parent
  ## allows on a bounded axis, or the child's size (times the factor) on an
  ## unbounded one or where a factor is given. The child gets "up to that".
  var natural = Size()
  if widget.children.len > 0:
    natural = widget.children[0].measure(c.loosen())
  let shrinkW = not widthFactor.isNaN or not c.hasBoundedWidth
  let shrinkH = not heightFactor.isNaN or not c.hasBoundedHeight
  c.constrain(Size(
    width: (if shrinkW: natural.width * (if widthFactor.isNaN: 1.0'f32 else: widthFactor)
            else: c.maxWidth),
    height: (if shrinkH: natural.height * (if heightFactor.isNaN: 1.0'f32 else: heightFactor)
             else: c.maxHeight)))

proc placeAligned(widget: Widget, alignment: Alignment) =
  ## The Align rule: the child at its size within the box, placed by
  ## `alignment` -- in the parent's box, or the child's own when unsized.
  let given = widget.arrangeConstraints
  let own = given.constrain(widget.measure(given))
  widget.bounds.width = own.width
  widget.bounds.height = own.height
  if widget.children.len > 0:
    let child = widget.children[0]
    let natural = child.measure(given.loosen())
    let off = alignmentOffset(alignment,
      (own.width - natural.width, own.height - natural.height))
    child.arrange(Rect(x: widget.bounds.x + off.x, y: widget.bounds.y + off.y,
                       width: natural.width, height: natural.height))

# Places its child inside its own box: all the room there is (bounded axes),
# or the child's size times `widthFactor` / `heightFactor`.
defineWidget(Align):
  props:
    alignment: Alignment = AlignmentCenter
    widthFactor: float32 = NaN
    heightFactor: float32 = NaN

  layout:
    placeAligned(widget, widget.alignment)

# Centres its child.
defineWidget(Center):
  props:
    widthFactor: float32 = NaN
    heightFactor: float32 = NaN

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
# alignment for its child, and margin outside all of it. As in Flutter: with
# no child it is as big as the parent allows (nothing on an unbounded axis);
# with an alignment it fills the room and aligns its child in it; otherwise it
# is its child plus padding. `width` / `height` / `constraints` are wishes
# within the parent's constraints.
defineWidget(Container):
  props:
    width: float32 = 0.0
    height: float32 = 0.0
    padding: EdgeInsets = EdgeInsets()
    margin: EdgeInsets = EdgeInsets()
    color: Color = Color()                # shorthand for decoration.color
    decoration: BoxDecoration = BoxDecoration()
    alignment: Option[Alignment] = none(Alignment)
    constraints: BoxConstraints = BoxConstraints()   ## inside the margin; a max of 0 is unbounded

  init:
    widget.sizeRequest = Size(
      width: (if widget.width > 0: widget.width + widget.margin.horizontal else: 0.0'f32),
      height: (if widget.height > 0: widget.height + widget.margin.vertical else: 0.0'f32))

  layout:
    let own = widget.measure(constraintsOf(widget.bounds))
    widget.bounds.width = own.width
    widget.bounds.height = own.height
    let inset = EdgeInsets(left: widget.margin.left + widget.padding.left,
                           top: widget.margin.top + widget.padding.top,
                           right: widget.margin.right + widget.padding.right,
                           bottom: widget.margin.bottom + widget.padding.bottom)
    if widget.children.len > 0:
      let child = widget.children[0]
      let inner = Size(width: max(0.0'f32, own.width - inset.horizontal),
                       height: max(0.0'f32, own.height - inset.vertical))
      if widget.alignment.isSome:
        let natural = child.measure(loose(inner.width, inner.height))
        let off = alignmentOffset(widget.alignment.get,
          (inner.width - natural.width, inner.height - natural.height))
        child.arrange(Rect(x: widget.bounds.x + inset.left + off.x,
                           y: widget.bounds.y + inset.top + off.y,
                           width: natural.width, height: natural.height))
      else:
        child.arrange(Rect(x: widget.bounds.x + inset.left, y: widget.bounds.y + inset.top,
                           width: inner.width, height: inner.height))

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
method computeSize*(widget: Align, c: Constraints): Size =
  widget.alignedSize(c, widget.widthFactor, widget.heightFactor)
method computeSize*(widget: Center, c: Constraints): Size =
  widget.alignedSize(c, widget.widthFactor, widget.heightFactor)

proc limits(b: BoxConstraints): Constraints =
  ## A BoxConstraints prop, where a max of 0 means unbounded.
  Constraints(minWidth: b.minWidth, maxWidth: (if b.maxWidth > 0: b.maxWidth else: Inf),
              minHeight: b.minHeight, maxHeight: (if b.maxHeight > 0: b.maxHeight else: Inf))

method computeSize*(widget: Container, c: Constraints): Size =
  ## Flutter's Container is margin > constraints > padding > align > child;
  ## measured in that order.
  let box = widget.constraints.limits.enforce(c.deflate(widget.margin))
  let inner = box.deflate(widget.padding)
  var content: Size
  if widget.children.len == 0:
    # Flutter: LimitedBox(0, 0) around an expanding box -- the room there is,
    # nothing on an unbounded axis.
    content = Size(width: (if inner.hasBoundedWidth: inner.maxWidth else: 0.0'f32),
                   height: (if inner.hasBoundedHeight: inner.maxHeight else: 0.0'f32))
  elif widget.alignment.isSome:
    let natural = widget.children[0].measure(inner.loosen())
    content = Size(width: (if inner.hasBoundedWidth: inner.maxWidth else: natural.width),
                   height: (if inner.hasBoundedHeight: inner.maxHeight else: natural.height))
  else:
    content = widget.children[0].measure(inner)
  let sized = box.constrain(Size(width: content.width + widget.padding.horizontal,
                                 height: content.height + widget.padding.vertical))
  c.constrain(Size(width: sized.width + widget.margin.horizontal,
                   height: sized.height + widget.margin.vertical))
