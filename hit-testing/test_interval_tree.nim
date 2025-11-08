## Comprehensive tests for the interval tree implementation
##
## Tests all operations: insert, remove, query, findOverlaps
## Verifies AVL balancing is maintained

import interval_tree
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

# ============================================================================
# Basic Operations Tests
# ============================================================================

proc testBasicInsertQuery() =
  var tree = newIntervalTree[int]()
  tree.insert(0, 10, 1)
  tree.insert(5, 15, 2)
  tree.insert(20, 30, 3)

  # Query points
  let result1 = tree.query(7.0)
  doAssert result1.len == 2, &"Expected 2 intervals at 7.0, got {result1.len}"
  doAssert 1 in result1 and 2 in result1

  let result2 = tree.query(25.0)
  doAssert result2.len == 1, &"Expected 1 interval at 25.0, got {result2.len}"
  doAssert 3 in result2

  let result3 = tree.query(18.0)
  doAssert result3.len == 0, &"Expected 0 intervals at 18.0, got {result3.len}"

proc testEmptyTree() =
  var tree = newIntervalTree[string]()
  let result = tree.query(5.0)
  doAssert result.len == 0
  doAssert tree.isEmpty()
  doAssert tree.len == 0

proc testSingleInterval() =
  var tree = newIntervalTree[string]()
  tree.insert(10, 20, "test")

  doAssert tree.len == 1
  doAssert not tree.isEmpty()

  let result1 = tree.query(15.0)
  doAssert result1.len == 1 and result1[0] == "test"

  let result2 = tree.query(5.0)
  doAssert result2.len == 0

  let result3 = tree.query(25.0)
  doAssert result3.len == 0

proc testRemoveBasic() =
  var tree = newIntervalTree[int]()
  tree.insert(0, 10, 1)
  tree.insert(5, 15, 2)
  tree.insert(20, 30, 3)

  doAssert tree.len == 3

  tree.remove(5, 15)
  doAssert tree.len == 2

  let result = tree.query(7.0)
  doAssert result.len == 1
  doAssert 1 in result
  doAssert 2 notin result

# ============================================================================
# Overlap Tests
# ============================================================================

proc testFindOverlaps() =
  var tree = newIntervalTree[int]()
  tree.insert(0, 10, 1)
  tree.insert(5, 15, 2)
  tree.insert(10, 20, 3)
  tree.insert(25, 35, 4)

  # Query [8, 12] should overlap with 1, 2, 3
  let result1 = tree.findOverlaps(8, 12)
  doAssert result1.len == 3, &"Expected 3 overlaps, got {result1.len}"
  doAssert 1 in result1 and 2 in result1 and 3 in result1

  # Query [22, 28] should overlap only with 4
  let result2 = tree.findOverlaps(22, 28)
  doAssert result2.len == 1, &"Expected 1 overlap, got {result2.len}"
  doAssert 4 in result2

  # Query [40, 50] should have no overlaps
  let result3 = tree.findOverlaps(40, 50)
  doAssert result3.len == 0

# ============================================================================
# AVL Balance Tests
# ============================================================================

proc testAVLBalance() =
  var tree = newIntervalTree[int]()

  # Insert in order (worst case for unbalanced BST)
  for i in 1..10:
    tree.insert(float32(i * 10), float32(i * 10 + 5), i)

  doAssert tree.isBalanced(), "Tree is not balanced after sequential inserts"

  # Remove some and check balance
  tree.remove(30, 35)
  tree.remove(70, 75)
  doAssert tree.isBalanced(), "Tree is not balanced after removals"

proc testLargeTree() =
  var tree = newIntervalTree[int]()
  randomize(42)  # Fixed seed for reproducibility

  # Insert 1000 random intervals
  for i in 1..1000:
    let start = float32(rand(10000))
    let fin = start + float32(rand(100) + 1)
    tree.insert(start, fin, i)

  doAssert tree.len == 1000
  doAssert tree.isBalanced(), "Large tree is not balanced"

  # Query some random points
  for i in 1..100:
    let point = float32(rand(10000))
    discard tree.query(point)  # Should not crash

# ============================================================================
# Edge Cases
# ============================================================================

proc testPointIntervals() =
  var tree = newIntervalTree[string]()
  tree.insert(5, 5, "point")

  let result1 = tree.query(5.0)
  doAssert result1.len == 1 and result1[0] == "point"

  let result2 = tree.query(5.1)
  doAssert result2.len == 0

proc testOverlappingIntervals() =
  var tree = newIntervalTree[int]()

  # All intervals overlap at [5, 10]
  tree.insert(0, 15, 1)
  tree.insert(5, 10, 2)
  tree.insert(3, 12, 3)
  tree.insert(7, 20, 4)

  let result = tree.query(8.0)
  doAssert result.len == 4, &"Expected all 4 intervals, got {result.len}"

proc testClearTree() =
  var tree = newIntervalTree[int]()
  for i in 1..10:
    tree.insert(float32(i * 10), float32(i * 10 + 5), i)

  doAssert tree.len == 10
  tree.clear()
  doAssert tree.len == 0
  doAssert tree.isEmpty()

  # Should be able to use after clear
  tree.insert(0, 10, 99)
  doAssert tree.len == 1

proc testBoundaryConditions() =
  var tree = newIntervalTree[string]()
  tree.insert(10, 20, "A")

  # Test exact boundaries
  let resultStart = tree.query(10.0)
  doAssert resultStart.len == 1, "Should include start point"

  let resultEnd = tree.query(20.0)
  doAssert resultEnd.len == 1, "Should include end point"

  let resultBefore = tree.query(9.999)
  doAssert resultBefore.len == 0, "Should not include point before start"

  let resultAfter = tree.query(20.001)
  doAssert resultAfter.len == 0, "Should not include point after end"

# ============================================================================
# Complex Widget-like Test
# ============================================================================

type
  MockWidget = ref object
    id: int
    name: string

proc testWithWidgets() =
  var tree = newIntervalTree[MockWidget]()

  let w1 = MockWidget(id: 1, name: "Button")
  let w2 = MockWidget(id: 2, name: "Label")
  let w3 = MockWidget(id: 3, name: "TextBox")

  tree.insert(0, 100, w1)
  tree.insert(50, 150, w2)
  tree.insert(120, 200, w3)

  let result = tree.query(75.0)
  doAssert result.len == 2
  doAssert result[0].name == "Button" or result[0].name == "Label"
  doAssert result[1].name == "Button" or result[1].name == "Label"

# ============================================================================
# Run All Tests
# ============================================================================

proc main() =
  echo "Running Interval Tree Tests"
  echo "=" .repeat(50)

  runTest("Empty tree queries", testEmptyTree)
  runTest("Single interval", testSingleInterval)
  runTest("Basic insert and query", testBasicInsertQuery)
  runTest("Basic remove", testRemoveBasic)
  runTest("Find overlapping intervals", testFindOverlaps)
  runTest("AVL tree remains balanced", testAVLBalance)
  runTest("Point intervals (start == fin)", testPointIntervals)
  runTest("Many overlapping intervals", testOverlappingIntervals)
  runTest("Clear tree", testClearTree)
  runTest("Boundary conditions", testBoundaryConditions)
  runTest("Using with widget-like objects", testWithWidgets)
  runTest("Large tree maintains balance", testLargeTree)

  reportResults()

when isMainModule:
  main()
