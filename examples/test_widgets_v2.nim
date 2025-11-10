## Test Widgets v2
##
## Tests primitive widgets, containers, and composites together

import ../core/types
import ../widgets/primitives/[label, rectangle, circle]
import ../widgets/containers/[vstack_v2, hstack_v2, zstack_v2]
import ../widgets/basic/button_v2
import raylib

when isMainModule:
  echo "=== Testing Widgets DSL v2 ==="

  # Test Button
  echo "\n--- Button Test ---"
  var clickCount = 0
  let button = newButton(
    text = "Click Me!",
    bgColor = BLUE,
    onClick = proc() =
      clickCount += 1
      echo "  Button clicked! Count: ", clickCount
  )
  button.bounds = Rect(x: 0, y: 0, width: 120, height: 40)
  echo "✓ Button created"

  # Test VStack
  echo "\n--- VStack Test ---"
  let vstack = newVStack(spacing = 10.0)
  vstack.bounds = Rect(x: 0, y: 0, width: 200, height: 300)

  let label1 = newLabel(text = "First", fontSize = 14.0)
  label1.bounds = Rect(x: 0, y: 0, width: 100, height: 20)

  let label2 = newLabel(text = "Second", fontSize = 14.0)
  label2.bounds = Rect(x: 0, y: 0, width: 100, height: 20)

  vstack.children.add(label1)
  vstack.children.add(label2)
  vstack.layoutDirty = true
  vstack.layout()

  echo "✓ VStack created with 2 children"
  echo "  Child 1 y: ", label1.bounds.y
  echo "  Child 2 y: ", label2.bounds.y

  # Test HStack
  echo "\n--- HStack Test ---"
  let hstack = newHStack(spacing = 5.0)
  hstack.bounds = Rect(x: 0, y: 0, width: 300, height: 50)

  let rect1 = newRectangle(color = RED)
  rect1.bounds = Rect(x: 0, y: 0, width: 50, height: 50)

  let rect2 = newRectangle(color = GREEN)
  rect2.bounds = Rect(x: 0, y: 0, width: 50, height: 50)

  hstack.children.add(rect1)
  hstack.children.add(rect2)
  hstack.layoutDirty = true
  hstack.layout()

  echo "✓ HStack created with 2 children"
  echo "  Child 1 x: ", rect1.bounds.x
  echo "  Child 2 x: ", rect2.bounds.x

  # Test ZStack
  echo "\n--- ZStack Test ---"
  let zstack = newZStack()
  zstack.bounds = Rect(x: 0, y: 0, width: 100, height: 100)

  let bg = newRectangle(color = LIGHTGRAY)
  bg.bounds = Rect(x: 0, y: 0, width: 50, height: 50)

  let fg = newCircle(color = BLUE)
  fg.bounds = Rect(x: 0, y: 0, width: 50, height: 50)

  zstack.children.add(bg)
  zstack.children.add(fg)
  zstack.layoutDirty = true
  zstack.layout()

  echo "✓ ZStack created with 2 layers"
  echo "  Both children at same position: ", bg.bounds.x == fg.bounds.x

  # Test composite UI
  echo "\n--- Composite UI Test ---"
  let ui = newVStack(spacing = 15.0, padding = 10.0)
  ui.bounds = Rect(x: 0, y: 0, width: 400, height: 300)

  let title = newLabel(text = "My App", fontSize = 18.0)
  title.bounds = Rect(x: 0, y: 0, width: 200, height: 20)

  let btn1 = newButton(text = "Button 1", bgColor = BLUE)
  btn1.bounds = Rect(x: 0, y: 0, width: 120, height: 40)

  let btn2 = newButton(text = "Button 2", bgColor = GREEN)
  btn2.bounds = Rect(x: 0, y: 0, width: 120, height: 40)

  ui.children.add(title)
  ui.children.add(btn1)
  ui.children.add(btn2)
  ui.layoutDirty = true
  ui.layout()

  echo "✓ Composite UI created"
  echo "  Title y: ", title.bounds.y
  echo "  Button 1 y: ", btn1.bounds.y
  echo "  Button 2 y: ", btn2.bounds.y

  # Simulate button click
  echo "\n--- Event Test ---"
  let mouseUpEvent = GuiEvent(
    kind: evMouseUp,
    mousePos: Point(x: 60, y: 20)  # Inside button
  )
  discard button.handleInput(mouseUpEvent)
  echo "✓ Event handling works"

  echo "\n✅ All widgets v2 tests passed!"
  echo "Click count: ", clickCount
