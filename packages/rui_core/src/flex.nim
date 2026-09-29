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

type
  FlexAxis* = enum
    faVertical    ## VStack: grow heights, shift `y`
    faHorizontal  ## HStack: grow widths, shift `x`

  MainAxisAlignment* = enum
    ## How spare room along the main axis is used when nothing flexes into it.
    MainStart        ## Children packed at the start
    MainCenter       ## Packed in the middle
    MainEnd          ## Packed at the end
    SpaceBetween     ## Spare room between children, none at the ends
    SpaceAround      ## Half a share at each end, a full share between
    SpaceEvenly      ## Equal shares at the ends and between

  CrossAxisAlignment* = enum
    ## Where children sit across a container's main axis -- horizontally in a
    ## VStack or Column, vertically in an HStack.
    CrossStart       ## Left / top
    CrossCenter
    CrossEnd         ## Right / bottom
    CrossStretch     ## Fill the container's cross size, when it has one

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

proc mainOffsets*(align: MainAxisAlignment, leftover: float32,
                  count: int): tuple[start, between: float32] =
  ## Where the first child starts, and how much extra goes between each pair,
  ## to spend `leftover` main-axis room on `count` children.
  if leftover <= 0 or count == 0:
    return (0.0'f32, 0.0'f32)
  let n = float32(count)
  case align
  of MainStart: (0.0'f32, 0.0'f32)
  of MainCenter: (leftover / 2, 0.0'f32)
  of MainEnd: (leftover, 0.0'f32)
  of SpaceBetween:
    if count == 1: (0.0'f32, 0.0'f32) else: (0.0'f32, leftover / (n - 1))
  of SpaceAround: (leftover / n / 2, leftover / n)
  of SpaceEvenly: (leftover / (n + 1), leftover / (n + 1))

proc justify*(children: seq[Widget], axis: FlexAxis,
              align: MainAxisAlignment, leftover: float32) =
  ## Shift children along the main axis to spend `leftover` as `align` says,
  ## laying out again any that moved.
  let (start, between) = mainOffsets(align, leftover, children.len)
  for i, child in children:
    let offset = start + between * float32(i)
    if offset == 0:
      continue
    if axis == faVertical: child.bounds.y += offset
    else: child.bounds.x += offset
    child.layout()

proc crossOffset*(align: CrossAxisAlignment, crossSize, childSize: float32): float32 =
  ## How far along the cross axis a child of `childSize` sits in `crossSize`.
  case align
  of CrossStart, CrossStretch: 0.0'f32
  of CrossCenter: (crossSize - childSize) / 2
  of CrossEnd: crossSize - childSize

proc alignCross*(children: seq[Widget], axis: FlexAxis,
                 align: CrossAxisAlignment, crossSize: float32) =
  ## Shift each child across the main axis to its aligned place, laying out
  ## again any that moved so their own children follow. `axis` is the main
  ## axis: a vertical stack aligns x.
  for child in children:
    let size = if axis == faVertical: child.bounds.width else: child.bounds.height
    let offset = crossOffset(align, crossSize, size)
    if offset == 0:
      continue
    if axis == faVertical: child.bounds.x += offset
    else: child.bounds.y += offset
    child.layout()

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
