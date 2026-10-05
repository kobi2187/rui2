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
  loose    ## plain children at their natural size
  expand   ## plain children fill the stack

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

proc place(pinA, pinB, fixed, natural, extent: float32): tuple[pos, size: float32] =
  ## One axis of a Positioned child: pinned at both ends it spans between
  ## them; otherwise its fixed or natural size, pinned at whichever end is set.
  let size = if not pinA.isNaN and not pinB.isNaN: max(0.0'f32, extent - pinA - pinB)
             elif not fixed.isNaN: fixed
             else: natural
  let pos = if not pinA.isNaN: pinA
            elif not pinB.isNaN: extent - pinB - size
            else: 0.0'f32
  (pos, size)

proc stackSize[W](widget: W, c: Constraints): Size =
  ## A Stack's measure: a fixed side is kept; a free one fits the widest /
  ## tallest plain (non-Positioned) child. An expanding stack offers its
  ## fixed sides to its children.
  let pad = widget.padding
  let expand = widget.fit == StackFit.expand
  var childC = unbounded()
  if expand and c.tightWidth: childC = childC.withWidth(c.minWidth - pad.horizontal)
  if expand and c.tightHeight: childC = childC.withHeight(c.minHeight - pad.vertical)
  var widest, tallest = 0.0'f32
  for child in widget.children:
    if child of Positioned: continue
    let s = child.measure(childC)
    widest = max(widest, s.width)
    tallest = max(tallest, s.height)
  Size(width: (if c.tightWidth: c.minWidth else: widest + pad.horizontal),
       height: (if c.tightHeight: c.minHeight else: tallest + pad.vertical))

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
    let own = widget.stackSize(constraintsOf(widget.bounds))
    widget.bounds.width = own.width
    widget.bounds.height = own.height
    let inner = Size(width: own.width - pad.horizontal, height: own.height - pad.vertical)
    let expand = widget.fit == StackFit.expand
    for child in widget.children:
      if child of Positioned:
        let p = Positioned(child)
        let natural = p.measure(unbounded())
        let (x, w) = place(p.left, p.right, p.width, natural.width, inner.width)
        let (y, h) = place(p.top, p.bottom, p.height, natural.height, inner.height)
        p.arrange(Rect(x: widget.bounds.x + pad.left + x,
                       y: widget.bounds.y + pad.top + y, width: w, height: h))
      elif expand:
        child.arrange(Rect(x: widget.bounds.x + pad.left, y: widget.bounds.y + pad.top,
                           width: inner.width, height: inner.height))
      else:
        let natural = child.measure(unbounded())
        let off = alignmentOffset(widget.alignment,
                                  (inner.width - natural.width, inner.height - natural.height))
        child.arrange(Rect(x: widget.bounds.x + pad.left + off.x,
                           y: widget.bounds.y + pad.top + off.y,
                           width: natural.width, height: natural.height))

method computeSize*(widget: Stack, c: Constraints): Size = widget.stackSize(c)
method computeSize*(widget: Positioned, c: Constraints): Size = widget.wrapSize(c)

proc newZStack*(padding: float32 = 0.0): Stack =
  ## Layers that all fill the stack -- the pre-Flutter name.
  result = newStack(fit = StackFit.expand, padding = EdgeInsets.all(padding))
  result.kindName = "ZStack"

type ZStack* = Stack
