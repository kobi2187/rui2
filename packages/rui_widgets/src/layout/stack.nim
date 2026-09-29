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
    let sized = (widget.bounds.width > 0, widget.bounds.height > 0)
    let expand = widget.fit == StackFit.expand

    # Plain children first: they decide the Stack's size when nothing else did.
    var widest, tallest = 0.0'f32
    for child in widget.children:
      if child of Positioned: continue
      child.bounds.width = if expand and sized[0]: widget.bounds.width - pad.horizontal else: 0.0'f32
      child.bounds.height = if expand and sized[1]: widget.bounds.height - pad.vertical else: 0.0'f32
      child.bounds.x = widget.bounds.x + pad.left
      child.bounds.y = widget.bounds.y + pad.top
      child.layout()
      widest = max(widest, child.bounds.width)
      tallest = max(tallest, child.bounds.height)
    if not sized[0]: widget.bounds.width = widest + pad.horizontal
    if not sized[1]: widget.bounds.height = tallest + pad.vertical
    let inner = (w: widget.bounds.width - pad.horizontal,
                 h: widget.bounds.height - pad.vertical)

    for child in widget.children:
      if child of Positioned:
        let p = Positioned(child)
        p.bounds = Rect()
        p.layout()                      # natural size, from its own child
        let (x, w) = place(p.left, p.right, p.width, p.bounds.width, inner.w)
        let (y, h) = place(p.top, p.bottom, p.height, p.bounds.height, inner.h)
        p.bounds = Rect(x: widget.bounds.x + pad.left + x,
                        y: widget.bounds.y + pad.top + y, width: w, height: h)
        p.layout()
      elif expand and (not sized[0] or not sized[1]):
        # An expanding stack that sized itself: fill now that the size is known.
        child.bounds = Rect(x: widget.bounds.x + pad.left, y: widget.bounds.y + pad.top,
                            width: inner.w, height: inner.h)
        child.layout()
      else:
        let off = alignmentOffset(widget.alignment,
                                  (inner.w - child.bounds.width, inner.h - child.bounds.height))
        if off.x != 0 or off.y != 0:
          child.bounds.x = widget.bounds.x + pad.left + off.x
          child.bounds.y = widget.bounds.y + pad.top + off.y
          child.layout()

proc newZStack*(padding: float32 = 0.0): Stack =
  ## Layers that all fill the stack -- the pre-Flutter name.
  result = newStack(fit = StackFit.expand, padding = EdgeInsets.all(padding))
  result.kindName = "ZStack"

type ZStack* = Stack
