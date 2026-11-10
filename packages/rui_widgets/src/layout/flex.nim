## Flex, Row, Column -- and Expanded, Flexible, Spacer.
##
## Flutter's linear layout. A `Row` lays its children out horizontally, a
## `Column` vertically; both are a `Flex` with a direction.
##
## ```nim
## ui:
##   Column(crossAxisAlignment = CrossAxisAlignment.stretch, spacing = 8.0):
##     Text(...)
##     Row(mainAxisAlignment = MainAxisAlignment.spaceBetween):
##       Button(text = "Back")
##       Button(text = "Next")
##     Expanded():
##       TextArea()
## ```
##
## The Flutter rules, in order:
##
## 1. Children without a flex factor are laid out at their natural size
##    along the axis; across it they get up to the Flex's room (exactly that
##    room for `CrossAxisAlignment.stretch` -- which beats a child's own
##    size, as in Flutter: wrap it in `Align` to keep its size).
## 2. The main-axis room left over is shared between `Expanded` / `Flexible` /
##    `Spacer` children by their `flex` factors (rui_core/flex.nim).
## 3. With `MainAxisSize.max` (the default) the Flex takes all the main-axis
##    room its parent gives it; with `min`, just what its children need.
## 4. Free room left after that is spent by `mainAxisAlignment`; each child is
##    placed across the axis by `crossAxisAlignment` (default: center).
##
## Beyond Flutter: `spacing` (Flutter 3.27's), and `padding` so the common
## "Column inside a Padding" needs no extra widget.
##
## `VStack` / `HStack` are the pre-Flutter names, kept as constructors: a
## Column / Row that stretches its children across and has 8 px spacing, which
## is how they always behaved -- and that stretches the CSS way: a child with
## its own width (`frame(width = ...)`, a SizedBox) or limits keeps them, and
## is stretched only within them. Row and Column stretch the Flutter way:
## the stretch wins (wrap a child in Align to keep its size).

import rui_core
import ../layout_motion

type FlexPlan = object
  sizes: seq[Size]          # each child's measured size
  own: Size                 # the Flex's own size

proc planFlexAt[W](widget: W, c: Constraints, crossRoom: float32): FlexPlan =
  ## Flutter's flex rules, by measuring the children (rules 1-3 above).
  ## Across the axis each child gets "up to the Flex's room" (loose), or
  ## exactly that room when stretched; along it, non-flex children get
  ## unbounded room and keep their natural size, then the room left over is
  ## shared out -- exactly (Expanded) or at most (Flexible) -- and the Flex
  ## is all of its bounded main axis (`mainAxisSize.max`) or its content.
  let horizontal = widget.direction == Axis.horizontal
  let pad = widget.padding
  let padMain = if horizontal: pad.horizontal else: pad.vertical
  let padCross = if horizontal: pad.vertical else: pad.horizontal
  template mainOf(s: Size): float32 = (if horizontal: s.width else: s.height)
  template crossOf(s: Size): float32 = (if horizontal: s.height else: s.width)
  let maxMain = if horizontal: c.maxWidth else: c.maxHeight
  let maxCross = if horizontal: c.maxHeight else: c.maxWidth
  let canFlex = maxMain < Inf
  let stretch = widget.crossAxisAlignment == CrossAxisAlignment.stretch

  proc childConstraints(child: Widget, main: float32, loose = false): Constraints =
    ## `main` < 0: unbounded along the axis; else that share, exactly or
    ## (`loose`) at most.
    var crossLo = if stretch and crossRoom < Inf: crossRoom else: 0.0'f32
    var crossHi = crossRoom
    if stretch and crossRoom < Inf and widget.cssStretch:
      # CSS's stretch (VStack / HStack): the child's own size and limits win,
      # and stretching fills only what it left open.
      let own = child.ownConstraints
      crossLo = (if horizontal: clamp(crossRoom, own.minHeight, own.maxHeight)
                 else: clamp(crossRoom, own.minWidth, own.maxWidth))
      crossHi = crossLo
    let mainLo = if main < 0 or loose: 0.0'f32 else: main
    let mainHi = if main < 0: Inf.float32 else: main
    if horizontal:
      Constraints(minWidth: mainLo, maxWidth: mainHi, minHeight: crossLo, maxHeight: crossHi)
    else:
      Constraints(minWidth: crossLo, maxWidth: crossHi, minHeight: mainLo, maxHeight: mainHi)

  var factors: seq[float32]
  var fixedUsed = 0.0'f32
  var totalFlex = 0.0'f32
  for child in widget.children:
    factors.add child.flexGrow
    if child.flexGrow > 0:
      totalFlex += child.flexGrow
      result.sizes.add Size()
    else:
      let size = child.measure(childConstraints(child, -1))
      result.sizes.add size
      fixedUsed += mainOf(size)

  let gaps = totalSpacing(widget.children.len, widget.spacing)
  let free = max(0.0'f32, maxMain - padMain - fixedUsed - gaps)
  for i, child in widget.children:
    if factors[i] > 0:
      # Unbounded main axis: nothing to share (Flutter reports an error);
      # the child keeps its natural size.
      result.sizes[i] =
        if canFlex: child.measure(childConstraints(child, free * factors[i] / totalFlex,
                                                   loose = child.flexLoose))
        else: child.measure(childConstraints(child, -1))

  var content, crossMax = 0.0'f32
  for size in result.sizes:
    content += mainOf(size)
    crossMax = max(crossMax, crossOf(size))
  content += gaps + padMain
  let ownMain = if canFlex and widget.mainAxisSize == MainAxisSize.max: maxMain
                else: content
  let ownCross = if stretch and crossRoom < Inf: crossRoom + padCross else: crossMax + padCross
  result.own = c.constrain(if horizontal: Size(width: ownMain, height: ownCross)
                           else: Size(width: ownCross, height: ownMain))

proc planFlex[W](widget: W, c: Constraints): FlexPlan =
  ## The plan for `c`. A stretching Flex with no limit across (a Column in a
  ## Row, say) stretches its children to the widest of them -- CSS's
  ## shrink-to-fit, and what Flutter needs an IntrinsicWidth for (it reports
  ## an error instead).
  let horizontal = widget.direction == Axis.horizontal
  let maxCross = if horizontal: c.maxHeight else: c.maxWidth
  let padCross = if horizontal: widget.padding.vertical else: widget.padding.horizontal
  let crossRoom = max(0.0'f32, maxCross - padCross)     # Inf stays Inf
  result = widget.planFlexAt(c, crossRoom)
  if widget.crossAxisAlignment == CrossAxisAlignment.stretch and crossRoom == Inf and
     widget.children.len > 0:
    let widest = (if horizontal: result.own.height else: result.own.width) - padCross
    result = widget.planFlexAt(c, widest)

proc placeFlex[W](widget: W, plan: FlexPlan) =
  ## Rule 4: spend the free room by mainAxisAlignment, place each child
  ## across by crossAxisAlignment, and give each its rect.
  let horizontal = widget.direction == Axis.horizontal
  let pad = widget.padding
  let padMain = if horizontal: pad.horizontal else: pad.vertical
  let padCross = if horizontal: pad.vertical else: pad.horizontal
  template mainOf(s: Size): float32 = (if horizontal: s.width else: s.height)
  template crossOf(s: Size): float32 = (if horizontal: s.height else: s.width)
  let gaps = totalSpacing(widget.children.len, widget.spacing)
  var content = gaps
  for size in plan.sizes: content += mainOf(size)
  let ownMain = if horizontal: widget.bounds.width else: widget.bounds.height
  let crossExtent = (if horizontal: widget.bounds.height else: widget.bounds.width) - padCross
  let (gap, startOffset) = calculateDistributedSpacing(
    widget.mainAxisAlignment, ownMain - padMain, content - gaps,
    widget.children.len, widget.spacing)
  var pos = startOffset
  for i, child in widget.children:
    let size = plan.sizes[i]
    let across = calculateAlignmentOffset(widget.crossAxisAlignment,
                                          crossExtent, crossOf(size))
    let x = if horizontal: pad.left + pos else: pad.left + across
    let y = if horizontal: pad.top + across else: pad.top + pos
    arrangeMoving(widget, child, Rect(x: widget.bounds.x + x, y: widget.bounds.y + y,
                                      width: size.width, height: size.height))
    pos += mainOf(size) + gap

defineWidget(Flex):
  props:
    direction: Axis = Axis.horizontal
    mainAxisAlignment: MainAxisAlignment = MainAxisAlignment.start
    crossAxisAlignment: CrossAxisAlignment = CrossAxisAlignment.center
    mainAxisSize: MainAxisSize = MainAxisSize.max
    spacing: float32 = 0.0
    padding: EdgeInsets = EdgeInsets()

  state:
    kindName: string             # what getTypeName reports: Row, Column, VStack...
    cssStretch: bool             # stretch the CSS way: a child's own size wins (VStack, HStack)

  typeName:
    if widget.kindName.len > 0: widget.kindName else: "Flex"

  layout:
    # Arrange. A zero side is still "size yourself" for parents that have
    # not moved to measure/arrange.
    let plan = widget.planFlex(widget.arrangeConstraints)
    if widget.bounds.width <= 0: widget.bounds.width = plan.own.width
    if widget.bounds.height <= 0: widget.bounds.height = plan.own.height
    widget.placeFlex(plan)

method computeSize*(widget: Flex, c: Constraints): Size =
  widget.planFlex(c).own

proc newRow*(mainAxisAlignment = MainAxisAlignment.start,
             crossAxisAlignment = CrossAxisAlignment.center,
             mainAxisSize = MainAxisSize.max, spacing = 0.0'f32,
             padding = EdgeInsets()): Flex =
  ## Children left to right.
  result = newFlex(Axis.horizontal, mainAxisAlignment, crossAxisAlignment,
                   mainAxisSize, spacing, padding)
  result.kindName = "Row"

proc newColumn*(mainAxisAlignment = MainAxisAlignment.start,
                crossAxisAlignment = CrossAxisAlignment.center,
                mainAxisSize = MainAxisSize.max, spacing = 0.0'f32,
                padding = EdgeInsets()): Flex =
  ## Children top to bottom.
  result = newFlex(Axis.vertical, mainAxisAlignment, crossAxisAlignment,
                   mainAxisSize, spacing, padding)
  result.kindName = "Column"

registerVariant("Row", "Flex", proc (): Widget = Widget(newRow()))
registerVariant("Column", "Flex", proc (): Widget = Widget(newColumn()))

proc newVStack*(spacing: float32 = 8.0, padding: float32 = 0.0): Flex =
  ## A Column that stretches its children across -- the pre-Flutter name.
  result = newFlex(Axis.vertical, MainAxisAlignment.start,
                   CrossAxisAlignment.stretch, MainAxisSize.max, spacing,
                   EdgeInsets.all(padding))
  result.kindName = "VStack"
  result.cssStretch = true

proc newHStack*(spacing: float32 = 8.0, padding: float32 = 0.0): Flex =
  ## A Row that stretches its children across -- the pre-Flutter name.
  result = newFlex(Axis.horizontal, MainAxisAlignment.start,
                   CrossAxisAlignment.stretch, MainAxisSize.max, spacing,
                   EdgeInsets.all(padding))
  result.kindName = "HStack"
  result.cssStretch = true

type
  Row* = Flex
  Column* = Flex
  VStack* = Flex
  HStack* = Flex

# ----------------------------------------------------------------------------
# Flex children
# ----------------------------------------------------------------------------

# Fills its share of a Row / Column's spare room, exactly.
defineWidget(Expanded):
  props:
    flex: int = 1

  init:
    widget.flexGrow = float32(widget.flex)

  layout:
    widget.flexGrow = float32(widget.flex)
    widget.flexLoose = false
    wrapChild(widget)

# Takes at most its share of the spare room -- less if its child is smaller.
defineWidget(Flexible):
  props:
    flex: int = 1
    fit: FlexFit = FlexFit.loose

  init:
    widget.flexGrow = float32(widget.flex)
    widget.flexLoose = widget.fit == FlexFit.loose

  layout:
    widget.flexGrow = float32(widget.flex)
    widget.flexLoose = widget.fit == FlexFit.loose
    wrapChild(widget)

# Empty flex space: pushes its neighbours apart in a Row or Column.
defineWidget(Spacer):
  props:
    flex: int = 1
    minWidth: float32 = 0.0
    minHeight: float32 = 0.0

  init:
    widget.flexGrow = float32(widget.flex)

  layout:
    widget.flexGrow = float32(widget.flex)
    if widget.bounds.width <= 0: widget.bounds.width = widget.minWidth
    if widget.bounds.height <= 0: widget.bounds.height = widget.minHeight

method computeSize*(widget: Expanded, c: Constraints): Size = widget.wrapSize(c)
method computeSize*(widget: Flexible, c: Constraints): Size = widget.wrapSize(c)
