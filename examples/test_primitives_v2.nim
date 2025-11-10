## Test Primitive Widgets (DSL v2)
##
## Tests Label, Rectangle, Circle primitives

import ../widgets/primitives/[label, rectangle, circle]
import raylib

when isMainModule:
  echo "=== Testing Primitive Widgets (DSL v2) ==="

  # Test Label
  let myLabel = newLabel(
    text = "Hello RUI2!",
    fontSize = 16.0,
    color = BLACK
  )
  echo "✓ Label created: '", myLabel.text, "', fontSize=", myLabel.fontSize

  # Test Rectangle
  let rect = newRectangle(
    color = BLUE,
    cornerRadius = 8.0
  )
  echo "✓ Rectangle created: cornerRadius=", rect.cornerRadius

  # Test Circle
  let myCircle = newCircle(
    color = RED,
    filled = true
  )
  echo "✓ Circle created: filled=", myCircle.filled

  echo "\n✓ All primitive widgets compiled successfully!"
