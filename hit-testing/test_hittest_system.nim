## Tests for the Hit-Testing System
##
## Tests all spatial query operations with various widget configurations

import hittest_system
import std/[strformat, random, strutils]

# ============================================================================
# Test Helpers
# ============================================================================

var testsPassed = 0
var testsFailed = 0

proc runTest(name: string, testProc: proc()) =
  try:
    testProc()
    inc testsPassed
    echo &"✓ {name}"
  except Exception as e:
    inc testsFailed
    echo &"✗ {name}: {e.msg}"

proc reportResults() =
  echo ""
  echo &"Tests passed: {testsPassed}"
  echo &"Tests failed: {testsFailed}"
  if testsFailed > 0:
    echo "FAILED"
    quit(1)
  else:
    echo "SUCCESS"

proc makeWidget(id: int, x, y, w, h: float32, z: int = 0): Widget =
  Widget(
    id: WidgetId(id),
    bounds: newRect(x, y, w, h),
    zIndex: z
  )

# ============================================================================
# Basic Tests
# ============================================================================

proc testEmptySystem() =
  var system = newHitTestSystem()
  doAssert system.isEmpty()
  doAssert system.len == 0

  let result = system.findWidgetsAt(50, 50)
  doAssert result.len == 0

proc testSingleWidget() =
  var system = newHitTestSystem()
  let widget = makeWidget(1, 0, 0, 100, 100)
  system.insertWidget(widget)

  doAssert system.len == 1
  doAssert not system.isEmpty()

  # Point inside
  let result1 = system.findWidgetsAt(50, 50)
  doAssert result1.len == 1
  doAssert result1[0].id.int == 1

  # Point outside
  let result2 = system.findWidgetsAt(150, 150)
  doAssert result2.len == 0

proc testMultipleWidgets() =
  var system = newHitTestSystem()

  # Create a grid of widgets
  system.insertWidget(makeWidget(1, 0, 0, 100, 100))
  system.insertWidget(makeWidget(2, 100, 0, 100, 100))
  system.insertWidget(makeWidget(3, 0, 100, 100, 100))
  system.insertWidget(makeWidget(4, 100, 100, 100, 100))

  doAssert system.len == 4

  # Test each quadrant
  let result1 = system.findWidgetsAt(50, 50)
  doAssert result1.len == 1 and result1[0].id.int == 1

  let result2 = system.findWidgetsAt(150, 50)
  doAssert result2.len == 1 and result2[0].id.int == 2

  let result3 = system.findWidgetsAt(50, 150)
  doAssert result3.len == 1 and result3[0].id.int == 3

  let result4 = system.findWidgetsAt(150, 150)
  doAssert result4.len == 1 and result4[0].id.int == 4

# ============================================================================
# Overlapping Widgets Tests
# ============================================================================

proc testOverlappingWidgets() =
  var system = newHitTestSystem()

  # Create overlapping widgets with different z-indices
  system.insertWidget(makeWidget(1, 0, 0, 200, 200, z=1))
  system.insertWidget(makeWidget(2, 50, 50, 200, 200, z=3))
  system.insertWidget(makeWidget(3, 100, 100, 200, 200, z=2))

  # Point where all three overlap
  let result = system.findWidgetsAt(150, 150)
  doAssert result.len == 3, &"Expected 3 widgets, got {result.len}"

  # Check z-order (widget 2 should be first with highest z-index)
  doAssert result[0].id.int == 2, "Widget 2 should be on top (z=3)"
  doAssert result[1].id.int == 3, "Widget 3 should be middle (z=2)"
  doAssert result[2].id.int == 1, "Widget 1 should be bottom (z=1)"

proc testFindTopWidget() =
  var system = newHitTestSystem()

  system.insertWidget(makeWidget(1, 0, 0, 200, 200, z=1))
  system.insertWidget(makeWidget(2, 50, 50, 200, 200, z=5))
  system.insertWidget(makeWidget(3, 100, 100, 200, 200, z=3))

  let topWidget = system.findTopWidgetAt(150, 150)
  doAssert topWidget != nil
  doAssert topWidget.id.int == 2, "Widget with highest z-index should be on top"

  # Point with no widgets
  let noWidget = system.findTopWidgetAt(500, 500)
  doAssert noWidget == nil

# ============================================================================
# Rectangle Query Tests
# ============================================================================

proc testFindWidgetsInRect() =
  var system = newHitTestSystem()

  # Create widgets
  system.insertWidget(makeWidget(1, 0, 0, 100, 100))
  system.insertWidget(makeWidget(2, 150, 0, 100, 100))
  system.insertWidget(makeWidget(3, 0, 150, 100, 100))
  system.insertWidget(makeWidget(4, 150, 150, 100, 100))
  system.insertWidget(makeWidget(5, 50, 50, 100, 100))  # Overlaps with 1

  # Query a rectangle that overlaps widgets 1 and 5
  let rect1 = newRect(0, 0, 120, 120)
  let result1 = system.findWidgetsInRect(rect1)
  doAssert result1.len == 2, &"Expected 2 widgets, got {result1.len}"

  # Query a rectangle that overlaps all widgets
  let rect2 = newRect(0, 0, 300, 300)
  let result2 = system.findWidgetsInRect(rect2)
  doAssert result2.len == 5, &"Expected all 5 widgets, got {result2.len}"

  # Query a rectangle that overlaps no widgets
  let rect3 = newRect(500, 500, 100, 100)
  let result3 = system.findWidgetsInRect(rect3)
  doAssert result3.len == 0

# ============================================================================
# Widget Management Tests
# ============================================================================

proc testRemoveWidget() =
  var system = newHitTestSystem()

  let widget1 = makeWidget(1, 0, 0, 100, 100)
  let widget2 = makeWidget(2, 100, 100, 100, 100)

  system.insertWidget(widget1)
  system.insertWidget(widget2)
  doAssert system.len == 2

  system.removeWidget(widget1)
  doAssert system.len == 1

  let result = system.findWidgetsAt(50, 50)
  doAssert result.len == 0, "Removed widget should not be found"

  let result2 = system.findWidgetsAt(150, 150)
  doAssert result2.len == 1, "Other widget should still be found"

proc testUpdateWidget() =
  var system = newHitTestSystem()

  let widget = makeWidget(1, 0, 0, 100, 100)
  system.insertWidget(widget)

  # Widget should be at original position
  let result1 = system.findWidgetsAt(50, 50)
  doAssert result1.len == 1

  # Update position
  let oldBounds = widget.bounds
  widget.bounds = newRect(200, 200, 100, 100)
  system.updateWidget(widget, oldBounds)

  # Should not be at old position
  let result2 = system.findWidgetsAt(50, 50)
  doAssert result2.len == 0

  # Should be at new position
  let result3 = system.findWidgetsAt(250, 250)
  doAssert result3.len == 1
  doAssert result3[0].id.int == 1

proc testRebuildSystem() =
  var system = newHitTestSystem()

  # Insert some widgets
  system.insertWidget(makeWidget(1, 0, 0, 100, 100))
  system.insertWidget(makeWidget(2, 100, 100, 100, 100))

  # Create new widget list
  let widgets = @[
    makeWidget(3, 50, 50, 100, 100),
    makeWidget(4, 150, 150, 100, 100)
  ]

  # Rebuild
  system.rebuildFromWidgets(widgets)

  doAssert system.len == 2

  # Old widgets should not be found
  let result1 = system.findWidgetsAt(10, 10)
  doAssert result1.len == 0

  # New widgets should be found
  let result2 = system.findWidgetsAt(100, 100)
  doAssert result2.len == 1
  doAssert result2[0].id.int == 3 or result2[0].id.int == 4

proc testClearSystem() =
  var system = newHitTestSystem()

  system.insertWidget(makeWidget(1, 0, 0, 100, 100))
  system.insertWidget(makeWidget(2, 100, 100, 100, 100))
  doAssert system.len == 2

  system.clear()
  doAssert system.len == 0
  doAssert system.isEmpty()

  let result = system.findWidgetsAt(50, 50)
  doAssert result.len == 0

# ============================================================================
# Edge Cases
# ============================================================================

proc testBoundaryPoints() =
  var system = newHitTestSystem()
  let widget = makeWidget(1, 0, 0, 100, 100)
  system.insertWidget(widget)

  # Test corners
  doAssert system.findWidgetsAt(0, 0).len == 1, "Top-left corner"
  doAssert system.findWidgetsAt(100, 0).len == 1, "Top-right corner"
  doAssert system.findWidgetsAt(0, 100).len == 1, "Bottom-left corner"
  doAssert system.findWidgetsAt(100, 100).len == 1, "Bottom-right corner"

  # Just outside
  doAssert system.findWidgetsAt(-0.1, 50).len == 0, "Just left"
  doAssert system.findWidgetsAt(100.1, 50).len == 0, "Just right"
  doAssert system.findWidgetsAt(50, -0.1).len == 0, "Just above"
  doAssert system.findWidgetsAt(50, 100.1).len == 0, "Just below"

proc testZeroSizeWidgets() =
  var system = newHitTestSystem()

  # Point widget (zero width and height)
  let widget = makeWidget(1, 50, 50, 0, 0)
  system.insertWidget(widget)

  # Should be found only at exact point
  let result1 = system.findWidgetsAt(50, 50)
  doAssert result1.len == 1

  let result2 = system.findWidgetsAt(50.1, 50)
  doAssert result2.len == 0

proc testLargeNumberOfWidgets() =
  var system = newHitTestSystem()
  randomize(42)

  # Insert 1000 random widgets
  for i in 1..1000:
    let x = float32(rand(10000))
    let y = float32(rand(10000))
    let w = float32(rand(100) + 1)
    let h = float32(rand(100) + 1)
    system.insertWidget(makeWidget(i, x, y, w, h))

  doAssert system.len == 1000
  doAssert system.verifyIntegrity()

  # Query random points (should not crash)
  for i in 1..100:
    let x = float32(rand(10000))
    let y = float32(rand(10000))
    discard system.findWidgetsAt(x, y)

# ============================================================================
# System Integrity Tests
# ============================================================================

proc testSystemIntegrity() =
  var system = newHitTestSystem()

  system.insertWidget(makeWidget(1, 0, 0, 100, 100))
  system.insertWidget(makeWidget(2, 100, 100, 100, 100))
  system.insertWidget(makeWidget(3, 200, 200, 100, 100))

  doAssert system.verifyIntegrity(), "System integrity check failed"

proc testStats() =
  var system = newHitTestSystem()

  system.insertWidget(makeWidget(1, 0, 0, 100, 100))
  system.insertWidget(makeWidget(2, 100, 100, 100, 100))

  let stats = system.getStats()
  doAssert "Widget count: 2" in stats
  doAssert "balanced: true" in stats

# ============================================================================
# Run All Tests
# ============================================================================

proc main() =
  echo "Running Hit-Testing System Tests"
  echo "=" .repeat(50)

  runTest("Empty system", testEmptySystem)
  runTest("Single widget", testSingleWidget)
  runTest("Multiple widgets", testMultipleWidgets)
  runTest("Overlapping widgets with z-index", testOverlappingWidgets)
  runTest("Find top widget", testFindTopWidget)
  runTest("Find widgets in rectangle", testFindWidgetsInRect)
  runTest("Remove widget", testRemoveWidget)
  runTest("Update widget position", testUpdateWidget)
  runTest("Rebuild system", testRebuildSystem)
  runTest("Clear system", testClearSystem)
  runTest("Boundary points", testBoundaryPoints)
  runTest("Zero-size widgets", testZeroSizeWidgets)
  runTest("Large number of widgets", testLargeNumberOfWidgets)
  runTest("System integrity", testSystemIntegrity)
  runTest("Stats output", testStats)

  reportResults()

when isMainModule:
  main()
