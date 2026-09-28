## Flex growth: handing a stack's leftover space to the children that ask for it
##
## A stack lays its children out at their natural size first. If it has a
## fixed size along its main axis and the children do not fill it, the
## remainder is split between the children with `flexGrow > 0`, in proportion
## to their weights -- the same rule as CSS `flex-grow`. Everything after a
## grown child moves along by what that child took.
##
## Nothing here shrinks: when the children overflow the stack there is no
## leftover and they keep their natural sizes.

import types

type FlexAxis* = enum
  faVertical    ## VStack: grow heights, shift `y`
  faHorizontal  ## HStack: grow widths, shift `x`

proc flexShares*(weights: openArray[float32], leftover: float32): seq[float32] =
  ## How much of `leftover` each weight gets. All zeros when there is nothing
  ## to hand out or nobody wants it.
  result = newSeq[float32](weights.len)
  if leftover <= 0:
    return
  var total = 0.0'f32
  for w in weights:
    total += max(w, 0.0)
  if total <= 0:
    return
  for i, w in weights:
    if w > 0:
      result[i] = leftover * w / total

proc resetFlexChildren*(children: seq[Widget], axis: FlexAxis) =
  ## Zero the main-axis size of every flex child, so the measuring pass sees
  ## its natural size rather than what it grew to last frame.
  for child in children:
    if child.flexGrow > 0:
      if axis == faVertical: child.bounds.height = 0
      else: child.bounds.width = 0

proc growChild(child: Widget, share, offset: float32, axis: FlexAxis) =
  if axis == faVertical:
    child.bounds.y += offset
    child.bounds.height += share
  else:
    child.bounds.x += offset
    child.bounds.width += share

proc applyFlex*(children: seq[Widget], leftover: float32, axis: FlexAxis) =
  ## Grow the flex children into `leftover` and shift their followers. Every
  ## child that moved or grew is laid out again, so its own children follow.
  var weights = newSeq[float32](children.len)
  for i, child in children:
    weights[i] = child.flexGrow
  let shares = flexShares(weights, leftover)
  var offset = 0.0'f32
  for i, child in children:
    if shares[i] <= 0 and offset <= 0:
      continue
    child.growChild(shares[i], offset, axis)
    offset += shares[i]
    child.layout()
