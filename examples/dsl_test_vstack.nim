## Test defineWidget macro with VStack

import ../core/widget_dsl_v2

# Test: Simple VStack container
defineWidget(VStack):
  props:
    spacing: float = 8.0

  layout:
    # Arrange children vertically
    var y = widget.bounds.y
    for child in widget.children:
      child.bounds.x = widget.bounds.x
      child.bounds.y = y
      child.bounds.width = widget.bounds.width
      # Keep child's own height
      y += child.bounds.height + widget.spacing

# Test usage
when isMainModule:
  echo "=== Testing VStack Widget ==="

  # Create a simple mock widget for testing
  type TestWidget = ref object of Widget
    name: string

  proc newTestWidget(name: string, height: float): TestWidget =
    result = TestWidget()
    result.name = name
    result.bounds = Rect(x: 0, y: 0, width: 100, height: height)
    result.children = @[]

  # Create VStack
  let stack = newVStack(spacing = 10.0)
  echo "Created VStack with spacing=", stack.spacing

  # Add mock children
  stack.children.add(newTestWidget("Child1", 30.0))
  stack.children.add(newTestWidget("Child2", 40.0))
  stack.children.add(newTestWidget("Child3", 20.0))

  echo "\nBefore layout:"
  for i, child in stack.children:
    echo "  ", TestWidget(child).name, ": y=", child.bounds.y

  # Set stack bounds and update layout
  stack.bounds = Rect(x: 0, y: 0, width: 200, height: 200)
  stack.layoutDirty = true
  stack.layout()

  echo "\nAfter layout:"
  for i, child in stack.children:
    echo "  ", TestWidget(child).name, ": y=", child.bounds.y, ", height=", child.bounds.height

  # Verify layout
  let expectedY = [0.0, 40.0, 90.0]  # 0, 30+10, 30+10+40+10
  var allCorrect = true
  for i, child in stack.children:
    if child.bounds.y != expectedY[i]:
      echo "ERROR: Expected y=", expectedY[i], ", got y=", child.bounds.y
      allCorrect = false

  if allCorrect:
    echo "\n✓ VStack test passed"
  else:
    echo "\n✗ VStack test failed"
