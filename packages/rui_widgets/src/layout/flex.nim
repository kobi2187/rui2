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
##    (stretched across, for `CrossAxisAlignment.stretch`).
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
## is how they always behaved.

import rui_core

type FlexPlan = object
  sizes: seq[Size]          # each child's measured size
  own: Size                 # the Flex's own size

proc planFlex[W](widget: W, c: Constraints): FlexPlan =
  ## Flutter's flex rules, by measuring the children (rules 1-3 above):
  ## natural sizes first, then the free main-axis room shared between the
  ## flex children, then the Flex's own size.
  let horizontal = widget.direction == Axis.horizontal
  let pad = widget.padding
  let padMain = if horizontal: pad.horizontal else: pad.vertical
  let padCross = if horizontal: pad.vertical else: pad.horizontal
  template mainOf(s: Size): float32 = (if horizontal: s.width else: s.height)
  template crossOf(s: Size): float32 = (if horizontal: s.height else: s.width)
  let mainFixed = (if horizontal: c.tightWidth else: c.tightHeight)
  let crossFixed = (if horizontal: c.tightHeight else: c.tightWidth)
  let mainAvail = if horizontal: c.minWidth else: c.minHeight
  let crossAvail = if horizontal: c.minHeight else: c.minWidth
  let mainBounded = mainFixed and mainAvail > 0 and
                    widget.mainAxisSize == MainAxisSize.max
  let stretch = widget.crossAxisAlignment == CrossAxisAlignment.stretch

  proc childConstraints(main: float32): Constraints =
    ## `main` < 0: natural size along the axis.
    result = unbounded()
    if stretch and crossFixed and crossAvail > 0:
      result = if horizontal: result.withHeight(crossAvail - padCross)
               else: result.withWidth(crossAvail - padCross)
    if main >= 0:
      result = if horizontal: result.withWidth(main) else: result.withHeight(main)

  var factors, natural: seq[float32]
  var loose: seq[bool]
  var fixedUsed = 0.0'f32
  for child in widget.children:
    let size = child.measure(childConstraints(-1))
    result.sizes.add size
    factors.add child.flexGrow
    loose.add child.flexLoose
    natural.add mainOf(size)
    if child.flexGrow <= 0:
      fixedUsed += mainOf(size)

  let gaps = totalSpacing(widget.children.len, widget.spacing)
  let free = if mainBounded: mainAvail - padMain - fixedUsed - gaps
             else: -1.0'f32
  let shares = flexSizes(factors, loose, natural, free)
  for i, child in widget.children:
    if factors[i] > 0 and shares[i] != natural[i]:
      result.sizes[i] = child.measure(childConstraints(shares[i]))

  var content, crossMax = 0.0'f32
  for size in result.sizes:
    content += mainOf(size)
    crossMax = max(crossMax, crossOf(size))
  content += gaps
  let ownMain = if mainBounded: mainAvail else: content + padMain
  let ownCross = if crossFixed and crossAvail > 0: crossAvail else: crossMax + padCross
  result.own = if horizontal: Size(width: ownMain, height: ownCross)
               else: Size(width: ownCross, height: ownMain)

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
    child.arrange(Rect(x: widget.bounds.x + x, y: widget.bounds.y + y,
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

  typeName:
    if widget.kindName.len > 0: widget.kindName else: "Flex"

  layout:
    # Arrange. A zero side is still "size yourself" for parents that have
    # not moved to measure/arrange.
    let plan = widget.planFlex(constraintsOf(widget.bounds))
    if widget.bounds.width <= 0: widget.bounds.width = plan.own.width
    if widget.bounds.height <= 0: widget.bounds.height = plan.own.height
    if widget.mainAxisSize == MainAxisSize.min:
      # A min-size Flex is its content along the axis, whatever it was given.
      if widget.direction == Axis.horizontal: widget.bounds.width = plan.own.width
      else: widget.bounds.height = plan.own.height
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

proc newVStack*(spacing: float32 = 8.0, padding: float32 = 0.0): Flex =
  ## A Column that stretches its children across -- the pre-Flutter name.
  result = newFlex(Axis.vertical, MainAxisAlignment.start,
                   CrossAxisAlignment.stretch, MainAxisSize.max, spacing,
                   EdgeInsets.all(padding))
  result.kindName = "VStack"

proc newHStack*(spacing: float32 = 8.0, padding: float32 = 0.0): Flex =
  ## A Row that stretches its children across -- the pre-Flutter name.
  result = newFlex(Axis.horizontal, MainAxisAlignment.start,
                   CrossAxisAlignment.stretch, MainAxisSize.max, spacing,
                   EdgeInsets.all(padding))
  result.kindName = "HStack"

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
definePrimitive(Spacer):
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
