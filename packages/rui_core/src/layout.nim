## Layout model -- Flutter's, with Flutter's names.
##
## RUI2 lays out the way Flutter does, so a Flutter developer can read and
## write it without a phrasebook: `Row` and `Column` with
## `MainAxisAlignment` / `CrossAxisAlignment` / `MainAxisSize`, `Expanded` and
## `Flexible` sharing out the spare room, `Padding`, `SizedBox`, `Center`,
## `Align(alignment = Alignment.topRight)`, `Stack` + `Positioned`, `Wrap`,
## `Table`, `GridView`, and `EdgeInsets.all(8)`. The widgets are in
## rui_widgets/layout; this module holds the vocabulary they share and the
## arithmetic they are built from.
##
## The enums are pure, so values are written the Flutter way --
## `MainAxisAlignment.spaceBetween`, `CrossAxisAlignment.end` -- and a bare
## `center` still resolves wherever the expected type is known.
##
## History: this is the restored `modules/layout`. Its design (Flutter-style,
## pure calculation helpers, Flex/Grid/Wrap/Dock containers) was right; its
## containers never compiled, and the module was deleted as dead code in
## a4bcc18. The helpers below are its working half, under their original
## names.

import types

type
  Axis* {.pure.} = enum
    horizontal, vertical

  MainAxisAlignment* {.pure.} = enum
    ## How children use the free space along the main axis.
    start, center, `end`, spaceBetween, spaceAround, spaceEvenly

  CrossAxisAlignment* {.pure.} = enum
    ## Where children sit across the main axis.
    start, center, `end`, stretch

  MainAxisSize* {.pure.} = enum
    ## `max` (Flutter's default): take all the room the parent offers along
    ## the main axis. `min`: shrink to the children.
    min, max

  FlexFit* {.pure.} = enum
    ## `tight`: a flex child takes exactly its share (Expanded).
    ## `loose`: at most its share (Flexible).
    tight, loose

  Alignment* = object
    ## A point in a box, from (-1, -1) top-left to (1, 1) bottom-right.
    x*, y*: float32

  BoxConstraints* = Constraints
    ## min/max width and height; a max of 0 means unbounded.

const
  AlignmentTopLeft* = Alignment(x: -1, y: -1)
  AlignmentTopCenter* = Alignment(x: 0, y: -1)
  AlignmentTopRight* = Alignment(x: 1, y: -1)
  AlignmentCenterLeft* = Alignment(x: -1, y: 0)
  AlignmentCenter* = Alignment(x: 0, y: 0)
  AlignmentCenterRight* = Alignment(x: 1, y: 0)
  AlignmentBottomLeft* = Alignment(x: -1, y: 1)
  AlignmentBottomCenter* = Alignment(x: 0, y: 1)
  AlignmentBottomRight* = Alignment(x: 1, y: 1)

# Flutter spells these as statics on the type: Alignment.topRight,
# EdgeInsets.all(8). Procs on the typedesc give the same spelling.

template topLeft*(T: typedesc[Alignment]): Alignment = AlignmentTopLeft
template topCenter*(T: typedesc[Alignment]): Alignment = AlignmentTopCenter
template topRight*(T: typedesc[Alignment]): Alignment = AlignmentTopRight
template centerLeft*(T: typedesc[Alignment]): Alignment = AlignmentCenterLeft
template center*(T: typedesc[Alignment]): Alignment = AlignmentCenter
template centerRight*(T: typedesc[Alignment]): Alignment = AlignmentCenterRight
template bottomLeft*(T: typedesc[Alignment]): Alignment = AlignmentBottomLeft
template bottomCenter*(T: typedesc[Alignment]): Alignment = AlignmentBottomCenter
template bottomRight*(T: typedesc[Alignment]): Alignment = AlignmentBottomRight

proc all*(T: typedesc[EdgeInsets], value: float32): EdgeInsets =
  EdgeInsets(left: value, top: value, right: value, bottom: value)

proc symmetric*(T: typedesc[EdgeInsets], horizontal = 0.0'f32,
                vertical = 0.0'f32): EdgeInsets =
  EdgeInsets(left: horizontal, right: horizontal, top: vertical, bottom: vertical)

proc only*(T: typedesc[EdgeInsets], left = 0.0'f32, top = 0.0'f32,
           right = 0.0'f32, bottom = 0.0'f32): EdgeInsets =
  EdgeInsets(left: left, top: top, right: right, bottom: bottom)

proc fromLTRB*(T: typedesc[EdgeInsets], left, top, right, bottom: float32): EdgeInsets =
  EdgeInsets(left: left, top: top, right: right, bottom: bottom)

proc zero*(T: typedesc[EdgeInsets]): EdgeInsets = EdgeInsets()

proc horizontal*(e: EdgeInsets): float32 = e.left + e.right
proc vertical*(e: EdgeInsets): float32 = e.top + e.bottom

proc tight*(T: typedesc[BoxConstraints], width, height: float32): BoxConstraints =
  BoxConstraints(minWidth: width, maxWidth: width, minHeight: height, maxHeight: height)

proc tightFor*(T: typedesc[BoxConstraints], width = 0.0'f32,
               height = 0.0'f32): BoxConstraints =
  ## Tight in the dimensions given (non-zero), unconstrained in the others.
  BoxConstraints(minWidth: width, maxWidth: width, minHeight: height, maxHeight: height)

# ============================================================================
# The restored helpers (modules/layout/layout_helpers.nim)
# ============================================================================

proc contentArea*(bounds: Rect, padding: EdgeInsets): tuple[x, y, width, height: float32] =
  ## The area inside `padding`.
  (bounds.x + padding.left, bounds.y + padding.top,
   bounds.width - padding.left - padding.right,
   bounds.height - padding.top - padding.bottom)

proc applyPadding*(bounds: Rect, padding: EdgeInsets): Rect =
  ## `bounds` shrunk by `padding`.
  Rect(x: bounds.x + padding.left, y: bounds.y + padding.top,
       width: bounds.width - padding.left - padding.right,
       height: bounds.height - padding.top - padding.bottom)

proc removePadding*(bounds: Rect, padding: EdgeInsets): Rect =
  ## `bounds` grown by `padding`: the inverse of applyPadding.
  Rect(x: bounds.x - padding.left, y: bounds.y - padding.top,
       width: bounds.width + padding.left + padding.right,
       height: bounds.height + padding.top + padding.bottom)

proc totalSpacing*(itemCount: int, spacing: float32): float32 =
  ## The gaps between `itemCount` items.
  if itemCount > 1: spacing * float32(itemCount - 1) else: 0.0'f32

proc totalChildrenSize*(children: openArray[Widget], axis: Axis): float32 =
  ## The children's sizes summed along `axis`.
  for child in children:
    result += (if axis == Axis.horizontal: child.bounds.width else: child.bounds.height)

proc calculateDistributedSpacing*(justify: MainAxisAlignment, totalSpace,
                                  totalItemsSize: float32, itemCount: int,
                                  defaultSpacing: float32):
                                  tuple[spacing, startOffset: float32] =
  ## The gap between items and the offset of the first, so that `itemCount`
  ## items totalling `totalItemsSize` fill `totalSpace` as `justify` says.
  ## The space-* modes add their share on top of `defaultSpacing` (Flutter's
  ## `spacing`), so a Row with spacing 8 and spaceBetween never packs tighter
  ## than 8. With no room to spare everything packs at the start.
  if itemCount == 0:
    return (defaultSpacing, 0.0'f32)
  let gaps = totalSpacing(itemCount, defaultSpacing)
  let free = max(0.0'f32, totalSpace - totalItemsSize - gaps)
  let n = float32(itemCount)
  case justify
  of MainAxisAlignment.start: (defaultSpacing, 0.0'f32)
  of MainAxisAlignment.center: (defaultSpacing, free / 2)
  of MainAxisAlignment.`end`: (defaultSpacing, free)
  of MainAxisAlignment.spaceBetween:
    if itemCount > 1: (defaultSpacing + free / (n - 1), 0.0'f32)
    else: (defaultSpacing, 0.0'f32)
  of MainAxisAlignment.spaceAround:
    (defaultSpacing + free / n, free / n / 2)
  of MainAxisAlignment.spaceEvenly:
    (defaultSpacing + free / (n + 1), free / (n + 1))

proc calculateAlignmentOffset*(align: CrossAxisAlignment,
                               containerSize, itemSize: float32): float32 =
  ## Where an item sits across the main axis. Stretch sits at the start; the
  ## caller sizes the item to the container.
  case align
  of CrossAxisAlignment.start, CrossAxisAlignment.stretch: 0.0'f32
  of CrossAxisAlignment.center: (containerSize - itemSize) / 2
  of CrossAxisAlignment.`end`: containerSize - itemSize

proc alignmentOffset*(alignment: Alignment, free: tuple[x, y: float32]):
                     tuple[x, y: float32] =
  ## Where a child sits in a box with `free` room to spare: Alignment's -1..1
  ## mapped onto 0..free.
  (free.x * (alignment.x + 1) / 2, free.y * (alignment.y + 1) / 2)

proc wrapChild*(widget: Widget, padding = EdgeInsets()) =
  ## The single-child wrapper's layout (Padding, Expanded, SizedBox, ...): the
  ## child fills the wrapper's box inside `padding`; a wrapper with no box of
  ## its own takes the child's natural size plus the padding.
  let w = widget.bounds.width
  let h = widget.bounds.height
  if widget.children.len == 0:
    if w <= 0: widget.bounds.width = padding.horizontal
    if h <= 0: widget.bounds.height = padding.vertical
    return
  let child = widget.children[0]
  child.bounds = Rect(x: widget.bounds.x + padding.left,
                      y: widget.bounds.y + padding.top,
                      width: (if w > 0: max(0.0'f32, w - padding.horizontal) else: 0.0'f32),
                      height: (if h > 0: max(0.0'f32, h - padding.vertical) else: 0.0'f32))
  child.layout()
  if w <= 0: widget.bounds.width = child.bounds.width + padding.horizontal
  if h <= 0: widget.bounds.height = child.bounds.height + padding.vertical
