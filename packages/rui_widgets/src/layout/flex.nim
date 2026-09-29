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
    let horizontal = widget.direction == Axis.horizontal
    let pad = widget.padding
    let padMain = if horizontal: pad.horizontal else: pad.vertical
    let padCross = if horizontal: pad.vertical else: pad.horizontal
    template mainOf(r: Rect): float32 = (if horizontal: r.width else: r.height)
    template crossOf(r: Rect): float32 = (if horizontal: r.height else: r.width)
    template setMain(w: Widget, v: float32) =
      (if horizontal: w.bounds.width = v else: w.bounds.height = v)
    template setCross(w: Widget, v: float32) =
      (if horizontal: w.bounds.height = v else: w.bounds.width = v)

    let mainBounded = mainOf(widget.bounds) > 0 and
                      widget.mainAxisSize == MainAxisSize.max
    let crossBounded = crossOf(widget.bounds) > 0
    let innerCross = crossOf(widget.bounds) - padCross
    let stretch = widget.crossAxisAlignment == CrossAxisAlignment.stretch

    proc measure(child: Widget, main: float32) =
      child.setMain(main)
      child.setCross(if stretch and crossBounded: innerCross else: 0.0'f32)
      child.layout()

    # 1. Natural sizes, for everything (flex children too: Flexible needs it,
    #    and an unbounded axis gives them nothing else).
    var factors, natural: seq[float32]
    var loose: seq[bool]
    var fixedUsed = 0.0'f32
    for child in widget.children:
      measure(child, 0)
      factors.add child.flexGrow
      loose.add child.flexLoose
      natural.add mainOf(child.bounds)
      if child.flexGrow <= 0:
        fixedUsed += mainOf(child.bounds)

    # 2. Share out what is left between the flex children.
    let gaps = totalSpacing(widget.children.len, widget.spacing)
    let free = if mainBounded:
                 mainOf(widget.bounds) - padMain - fixedUsed - gaps
               else: -1.0'f32
    let sizes = flexSizes(factors, loose, natural, free)
    for i, child in widget.children:
      if factors[i] > 0 and sizes[i] != natural[i]:
        measure(child, sizes[i])

    # 3. Own size.
    var content, crossMax = 0.0'f32
    for child in widget.children:
      content += mainOf(child.bounds)
      crossMax = max(crossMax, crossOf(child.bounds))
    content += gaps
    if not mainBounded:
      widget.setMain(content + padMain)
    if not crossBounded:
      widget.setCross(crossMax + padCross)

    # 4. Place: mainAxisAlignment along, crossAxisAlignment across.
    let crossExtent = crossOf(widget.bounds) - padCross
    let (gap, startOffset) = calculateDistributedSpacing(
      widget.mainAxisAlignment, mainOf(widget.bounds) - padMain,
      content - gaps, widget.children.len, widget.spacing)
    var pos = startOffset
    for child in widget.children:
      let across = calculateAlignmentOffset(widget.crossAxisAlignment,
                                            crossExtent, crossOf(child.bounds))
      let x = if horizontal: pad.left + pos else: pad.left + across
      let y = if horizontal: pad.top + across else: pad.top + pos
      if child.bounds.x != widget.bounds.x + x or child.bounds.y != widget.bounds.y + y:
        child.bounds.x = widget.bounds.x + x
        child.bounds.y = widget.bounds.y + y
        child.layout()          # so its own children follow it
      pos += mainOf(child.bounds) + gap

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
