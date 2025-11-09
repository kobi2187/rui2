## Layout Helper Functions
##
## Small, composable functions for layout calculations
## Following Forth philosophy: obvious, readable functions that compose
##
## These helpers eliminate duplication across HStack, VStack, and future layout widgets

import ../core/types
import ../drawing_primitives/layout_containers

export Alignment, Justify

# ============================================================================
# Content Area Calculation
# ============================================================================

proc contentArea*(bounds: Rect, padding: EdgeInsets): tuple[x, y, width, height: float32] =
  ## Calculate available content area inside padding
  ## Returns the inner rectangle with padding applied
  result.x = bounds.x + padding.left
  result.y = bounds.y + padding.top
  result.width = bounds.width - padding.left - padding.right
  result.height = bounds.height - padding.top - padding.bottom

# ============================================================================
# Spacing Distribution (Main Axis)
# ============================================================================

proc calculateDistributedSpacing*(
  justify: Justify,
  totalSpace: float32,
  totalItemsSize: float32,
  itemCount: int,
  defaultSpacing: float32
): tuple[spacing: float32, startOffset: float32] =
  ## Calculate spacing and start offset for justify modes
  ##
  ## This is the core composable function that handles all spacing distribution logic.
  ## Used by both HStack (horizontal) and VStack (vertical).
  ##
  ## Args:
  ##   justify: How to distribute items (Start, Center, End, SpaceBetween, etc.)
  ##   totalSpace: Available space along main axis
  ##   totalItemsSize: Sum of all item sizes along main axis
  ##   itemCount: Number of items to distribute
  ##   defaultSpacing: Default spacing between items (used for Start/Center/End)
  ##
  ## Returns:
  ##   spacing: Distance between items
  ##   startOffset: Where to start placing first item

  if itemCount == 0:
    return (0.0, 0.0)

  case justify
  of Start:
    result.spacing = defaultSpacing
    result.startOffset = 0.0

  of Center:
    let totalContentSize = totalItemsSize + (if itemCount > 1: defaultSpacing * float32(itemCount - 1) else: 0.0)
    result.spacing = defaultSpacing
    result.startOffset = (totalSpace - totalContentSize) / 2.0

  of End:
    let totalContentSize = totalItemsSize + (if itemCount > 1: defaultSpacing * float32(itemCount - 1) else: 0.0)
    result.spacing = defaultSpacing
    result.startOffset = totalSpace - totalContentSize

  of SpaceBetween:
    if itemCount > 1:
      result.spacing = (totalSpace - totalItemsSize) / float32(itemCount - 1)
    else:
      result.spacing = 0.0
    result.startOffset = 0.0

  of SpaceAround:
    if itemCount > 0:
      result.spacing = (totalSpace - totalItemsSize) / float32(itemCount)
      result.startOffset = result.spacing / 2.0
    else:
      result.spacing = 0.0
      result.startOffset = 0.0

  of SpaceEvenly:
    if itemCount > 0:
      result.spacing = (totalSpace - totalItemsSize) / float32(itemCount + 1)
      result.startOffset = result.spacing
    else:
      result.spacing = 0.0
      result.startOffset = 0.0

# ============================================================================
# Alignment (Cross Axis)
# ============================================================================

proc calculateAlignmentOffset*(
  align: Alignment,
  containerSize: float32,
  itemSize: float32
): float32 =
  ## Calculate offset for cross-axis alignment
  ##
  ## Args:
  ##   align: How to align item on cross axis
  ##   containerSize: Size of container along cross axis
  ##   itemSize: Size of item along cross axis
  ##
  ## Returns:
  ##   Offset from container start

  case align
  of Leading, Left:
    0.0
  of Center:
    (containerSize - itemSize) / 2.0
  of Trailing, Right:
    containerSize - itemSize
  of Stretch:
    0.0  # Position at start, caller should set item size to containerSize
  else:
    0.0

# ============================================================================
# Padding Application
# ============================================================================

proc applyPadding*(bounds: Rect, padding: EdgeInsets): Rect =
  ## Returns a new Rect with padding applied (shrinks the rect)
  Rect(
    x: bounds.x + padding.left,
    y: bounds.y + padding.top,
    width: bounds.width - padding.left - padding.right,
    height: bounds.height - padding.top - padding.bottom
  )

proc removePadding*(bounds: Rect, padding: EdgeInsets): Rect =
  ## Returns a new Rect with padding removed (expands the rect)
  Rect(
    x: bounds.x - padding.left,
    y: bounds.y - padding.top,
    width: bounds.width + padding.left + padding.right,
    height: bounds.height + padding.top + padding.bottom
  )

# ============================================================================
# Size Calculation Helpers
# ============================================================================

proc totalChildrenSize*(children: seq[Widget], isHorizontal: bool): float32 =
  ## Calculate total size of children along specified axis
  ##
  ## Args:
  ##   children: List of child widgets
  ##   isHorizontal: true for width sum, false for height sum
  ##
  ## Returns:
  ##   Sum of all child sizes

  result = 0.0
  for child in children:
    result += (if isHorizontal: child.bounds.width else: child.bounds.height)

proc totalSpacing*(itemCount: int, spacing: float32): float32 =
  ## Calculate total spacing between items
  ##
  ## Args:
  ##   itemCount: Number of items
  ##   spacing: Space between each item
  ##
  ## Returns:
  ##   Total space taken by gaps

  if itemCount > 1:
    spacing * float32(itemCount - 1)
  else:
    0.0
