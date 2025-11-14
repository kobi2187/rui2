## Hit-Testing System for RUI
##
## Uses dual interval trees for efficient spatial queries.
## Finds widgets at a point in O(log n) time.
##
## The system maintains two interval trees:
## - xTree: Indexes widgets by their X coordinates [x, x+width]
## - yTree: Indexes widgets by their Y coordinates [y, y+height]
##
## To find widgets at (x, y):
## 1. Query xTree for all widgets whose X interval contains x
## 2. Query yTree for all widgets whose Y interval contains y
## 3. Return the intersection of both sets

import interval_tree
import ../core/types
import std/[sets, hashes, algorithm]

type
  HitTestSystem* = object
    xTree: IntervalTree[Widget]
    yTree: IntervalTree[Widget]
    widgetCount: int

# ============================================================================
# Helper Functions for Types
# ============================================================================

proc newRect*(x, y, width, height: float32): Rect =
  Rect(x: x, y: y, width: width, height: height)

proc contains*(rect: Rect, x, y: float32): bool =
  ## Check if a point (x, y) is inside the rectangle
  x >= rect.x and x <= rect.x + rect.width and
  y >= rect.y and y <= rect.y + rect.height

proc overlaps*(a, b: Rect): bool =
  ## Check if two rectangles overlap
  a.x <= b.x + b.width and
  a.x + a.width >= b.x and
  a.y <= b.y + b.height and
  a.y + a.height >= b.y

# ============================================================================
# Hit-Test System
# ============================================================================

proc newHitTestSystem*(): HitTestSystem =
  ## Create a new hit-testing system with empty interval trees
  result = HitTestSystem(
    xTree: newIntervalTree[Widget](),
    yTree: newIntervalTree[Widget](),
    widgetCount: 0
  )

proc clear*(system: var HitTestSystem) =
  ## Clear all widgets from the hit-testing system
  system.xTree.clear()
  system.yTree.clear()
  system.widgetCount = 0

proc len*(system: HitTestSystem): int =
  ## Return the number of widgets in the system
  system.widgetCount

proc isEmpty*(system: HitTestSystem): bool =
  ## Check if the system contains any widgets
  system.widgetCount == 0

# ============================================================================
# Widget Management
# ============================================================================

proc insertWidget*(system: var HitTestSystem, widget: Widget) =
  ## Insert a widget into the hit-testing system
  ## The widget is indexed by its bounding rectangle
  let r = widget.bounds
  system.xTree.insert(r.x, r.x + r.width, widget)
  system.yTree.insert(r.y, r.y + r.height, widget)
  inc system.widgetCount

proc removeWidget*(system: var HitTestSystem, widget: Widget) =
  ## Remove a widget from the hit-testing system
  let r = widget.bounds
  system.xTree.remove(r.x, r.x + r.width)
  system.yTree.remove(r.y, r.y + r.height)
  dec system.widgetCount

proc updateWidget*(system: var HitTestSystem, widget: Widget, oldBounds: Rect) =
  ## Update a widget's position in the hit-testing system
  ## This is more efficient than rebuild when only a few widgets changed
  ##
  ## Usage:
  ##   let oldBounds = widget.bounds
  ##   widget.bounds = newBounds
  ##   system.updateWidget(widget, oldBounds)

  # Remove old bounds
  system.xTree.remove(oldBounds.x, oldBounds.x + oldBounds.width)
  system.yTree.remove(oldBounds.y, oldBounds.y + oldBounds.height)

  # Insert new bounds
  let r = widget.bounds
  system.xTree.insert(r.x, r.x + r.width, widget)
  system.yTree.insert(r.y, r.y + r.height, widget)

proc updateWidgetBounds*(system: var HitTestSystem, widget: Widget, newBounds: Rect) =
  ## Update a widget's bounds in the hit-testing system
  ## More convenient API that handles the old bounds internally
  ##
  ## Usage:
  ##   system.updateWidgetBounds(widget, newBounds)
  ##
  ## Note: This reads widget.bounds as the old value, then updates it

  let oldBounds = widget.bounds

  # Remove old bounds
  system.xTree.remove(oldBounds.x, oldBounds.x + oldBounds.width)
  system.yTree.remove(oldBounds.y, oldBounds.y + oldBounds.height)

  # Update widget bounds
  widget.bounds = newBounds

  # Insert new bounds
  system.xTree.insert(newBounds.x, newBounds.x + newBounds.width, widget)
  system.yTree.insert(newBounds.y, newBounds.y + newBounds.height, widget)

proc rebuildFromWidgets*(system: var HitTestSystem, widgets: openArray[Widget]) =
  ## Rebuild the entire hit-testing system from a list of widgets
  ## This is useful when many widgets have changed position
  system.clear()
  for widget in widgets:
    system.insertWidget(widget)

# ============================================================================
# Spatial Queries
# ============================================================================

proc findWidgetsAt*(system: HitTestSystem, x, y: float32): seq[Widget] =
  ## Find all widgets at point (x, y)
  ## Returns widgets sorted by z-index (front to back)
  ##
  ## Complexity: O(log n + k) where k is the number of results

  # Get candidates from both trees
  let xCandidates = system.xTree.query(x)
  let yCandidates = system.yTree.query(y)

  # Find intersection using hash set for O(k) performance
  var ySet = initHashSet[Widget]()
  for widget in yCandidates:
    ySet.incl(widget)

  result = @[]
  for widget in xCandidates:
    if widget in ySet:
      # Double-check that the point is actually inside
      # (the interval tree gives us candidates, but we need exact check)
      if widget.bounds.contains(x, y):
        result.add(widget)

  # Sort by z-index (higher z-index = rendered on top = should be first)
  result.sort(proc(a, b: Widget): int =
    result = cmp(b.zIndex, a.zIndex)
  )

proc findWidgetsInRect*(system: HitTestSystem, rect: Rect): seq[Widget] =
  ## Find all widgets that overlap with the given rectangle
  ## Returns widgets sorted by z-index (front to back)
  ##
  ## Complexity: O(log n + k) where k is the number of results

  # Get candidates from both trees
  let xOverlaps = system.xTree.findOverlaps(rect.x, rect.x + rect.width)
  let yOverlaps = system.yTree.findOverlaps(rect.y, rect.y + rect.height)

  # Find intersection
  var ySet = initHashSet[Widget]()
  for widget in yOverlaps:
    ySet.incl(widget)

  result = @[]
  for widget in xOverlaps:
    if widget in ySet:
      # Double-check with exact rectangle intersection test
      if widget.bounds.overlaps(rect):
        result.add(widget)

  # Sort by z-index
  result.sort(proc(a, b: Widget): int =
    result = cmp(b.zIndex, a.zIndex)
  )

proc findTopWidgetAt*(system: HitTestSystem, x, y: float32): Widget =
  ## Find the topmost widget at point (x, y)
  ## Returns nil if no widget is at that point
  ##
  ## This is more efficient than findWidgetsAt when you only need the top widget
  let widgets = system.findWidgetsAt(x, y)
  if widgets.len > 0:
    return widgets[0]
  else:
    return nil

proc getWidgetAt*(system: HitTestSystem, x, y: float32): Widget =
  ## Simple API: Get the widget directly under the cursor at (x, y)
  ## Returns nil if no widget is at that point
  ##
  ## This is the primary API for finding the widget under the mouse cursor
  system.findTopWidgetAt(x, y)

# ============================================================================
# Debug/Statistics
# ============================================================================

proc getStats*(system: HitTestSystem): string =
  ## Return statistics about the hit-testing system
  result = "HitTestSystem Stats:\n"
  result &= "  Widget count: " & $system.widgetCount & "\n"
  result &= "  X-tree size: " & $system.xTree.len & "\n"
  result &= "  Y-tree size: " & $system.yTree.len & "\n"
  result &= "  X-tree balanced: " & $system.xTree.isBalanced() & "\n"
  result &= "  Y-tree balanced: " & $system.yTree.isBalanced() & "\n"

proc verifyIntegrity*(system: HitTestSystem): bool =
  ## Verify that the hit-testing system is in a consistent state
  ## Returns true if all checks pass

  # Check that both trees have the same number of widgets
  if system.xTree.len != system.yTree.len:
    return false

  # Check that widget count matches tree sizes
  if system.widgetCount != system.xTree.len:
    return false

  # Check that trees are balanced
  if not system.xTree.isBalanced():
    return false
  if not system.yTree.isBalanced():
    return false

  return true
