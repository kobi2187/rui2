## Stack and Positioned.
##
## Children on top of one another, painted in order. A plain child is placed
## by the Stack's `alignment` at its natural size (or fills the Stack, with
## `fit = StackFit.expand`); a `Positioned` child is pinned by any of its
## left/top/right/bottom edges, and one pinned on both sides of an axis
## stretches between them. The Stack, when nothing sized it, is as big as its
## largest plain child.
##
## ```nim
## ui:
##   Stack().frame(width = 300, height = 200):
##     Image(...)
##     Positioned(right = 8, bottom = 8):
##       Label(text = "caption")
## ```
##
## `ZStack` is the pre-Flutter name: a Stack whose children all fill it.

import rui_core
import std/math

type StackFit* {.pure.} = enum
  loose        ## plain children: any size up to the stack's
  expand       ## plain children fill the stack
  passthrough  ## plain children get the stack's own constraints

# A child pinned by its edges. Leave an edge as NaN (the default) to unpin it.
defineWidget(Positioned):
  props:
    left: float32 = NaN
    top: float32 = NaN
    right: float32 = NaN
    bottom: float32 = NaN
    width: float32 = NaN
    height: float32 = NaN

  layout:
    wrapChild(widget)

proc pinnedConstraints(p: Positioned, inner: Size): Constraints =
  ## What a Positioned child may be (Flutter): exactly the span between two
  ## pinned edges, or its width / height; free on an axis with neither.
  result = unbounded()
  if not p.left.isNaN and not p.right.isNaN:
    result = result.withWidth(max(0.0'f32, inner.width - p.left - p.right))
  elif not p.width.isNaN:
    result = result.withWidth(p.width)
  if not p.top.isNaN and not p.bottom.isNaN:
    result = result.withHeight(max(0.0'f32, inner.height - p.top - p.bottom))
  elif not p.height.isNaN:
    result = result.withHeight(p.height)

proc place(pinA, pinB, size, extent, aligned: float32): float32 =
  ## Where a Positioned child starts on one axis: at the pinned edge, or by
  ## the stack's alignment when neither is pinned.
  if not pinA.isNaN: pinA
  elif not pinB.isNaN: extent - pinB - size
  else: aligned

proc plainConstraints(fit: StackFit, c: Constraints): Constraints =
  case fit
  of StackFit.loose: c.loosen()
  of StackFit.expand:
    Constraints(minWidth: (if c.hasBoundedWidth: c.maxWidth else: 0.0'f32), maxWidth: c.maxWidth,
                minHeight: (if c.hasBoundedHeight: c.maxHeight else: 0.0'f32), maxHeight: c.maxHeight)
  of StackFit.passthrough: c

proc stackSize[W](widget: W, c: Constraints): Size =
  ## A Stack's measure (Flutter's RenderStack): as big as its biggest plain
  ## (non-Positioned) child, within its constraints; with no plain child, as
  ## big as allowed.
  let pad = widget.padding
  let inner = c.deflate(pad)
  let childC = plainConstraints(widget.fit, inner)
  var widest, tallest = 0.0'f32
  var plain = false
  for child in widget.children:
    if child of Positioned: continue
    plain = true
    let s = child.measure(childC)
    widest = max(widest, s.width)
    tallest = max(tallest, s.height)
  if not plain:
    widest = if inner.hasBoundedWidth: inner.maxWidth else: inner.minWidth
    tallest = if inner.hasBoundedHeight: inner.maxHeight else: inner.minHeight
  c.constrain(Size(width: widest + pad.horizontal, height: tallest + pad.vertical))

defineWidget(Stack):
  props:
    alignment: Alignment = AlignmentTopLeft
    fit: StackFit = StackFit.loose
    padding: EdgeInsets = EdgeInsets()

  state:
    kindName: string

  typeName:
    if widget.kindName.len > 0: widget.kindName else: "Stack"

  layout:
    let pad = widget.padding
    let given = widget.arrangeConstraints
    let own = given.constrain(widget.measure(given))
    widget.bounds.width = own.width
    widget.bounds.height = own.height
    let inner = Size(width: own.width - pad.horizontal, height: own.height - pad.vertical)
    let childC = plainConstraints(widget.fit, given.deflate(pad))
    for child in widget.children:
      let size = if child of Positioned: child.measure(pinnedConstraints(Positioned(child), inner))
                 else: child.measure(childC)
      let off = alignmentOffset(widget.alignment,
                                (inner.width - size.width, inner.height - size.height))
      var x = off.x
      var y = off.y
      if child of Positioned:
        let p = Positioned(child)
        x = place(p.left, p.right, size.width, inner.width, off.x)
        y = place(p.top, p.bottom, size.height, inner.height, off.y)
      child.arrange(Rect(x: widget.bounds.x + pad.left + x, y: widget.bounds.y + pad.top + y,
                         width: size.width, height: size.height))

method computeSize*(widget: Stack, c: Constraints): Size = widget.stackSize(c)
method computeSize*(widget: Positioned, c: Constraints): Size = widget.wrapSize(c)

proc newZStack*(padding: float32 = 0.0): Stack =
  ## Layers that all fill the stack -- the pre-Flutter name.
  result = newStack(fit = StackFit.expand, padding = EdgeInsets.all(padding))
  result.kindName = "ZStack"

type ZStack* = Stack
