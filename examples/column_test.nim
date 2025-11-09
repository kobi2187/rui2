## Baby-step test: Two buttons in a VStack container
## (Migrated from Column - VStack provides same functionality with consistent naming)
##
## Expected: Buttons should be vertically arranged and NOT overlap

import raylib
import ../core/types
import ../widgets/basic/button_yaml
import ../widgets/containers/vstack

proc main() =
  initWindow(800, 600, "VStack Layout Test")
  defer: closeWindow()
  setTargetFPS(60)

  # Create a VStack container (formerly Column)
  let col = newVStack()
  col.bounds = Rect(x: 100, y: 100, width: 300, height: 400)
  col.spacing = 16.0

  # Create first button
  let btn1 = newButtonYAML()
  btn1.text = "Button 1"
  btn1.bounds.width = 200
  btn1.bounds.height = 50
  btn1.onClick = proc() =
    echo "Button 1 clicked!"

  # Create second button
  let btn2 = newButtonYAML()
  btn2.text = "Button 2"
  btn2.bounds.width = 200
  btn2.bounds.height = 50
  btn2.onClick = proc() =
    echo "Button 2 clicked!"

  # Add buttons to column
  col.addChild(btn1)
  col.addChild(btn2)

  # Initial layout
  col.layout()

  echo "=== Initial Layout ==="
  echo "Button 1 bounds: x=", btn1.bounds.x, " y=", btn1.bounds.y, " w=", btn1.bounds.width, " h=", btn1.bounds.height
  echo "Button 2 bounds: x=", btn2.bounds.x, " y=", btn2.bounds.y, " w=", btn2.bounds.width, " h=", btn2.bounds.height
  echo "Buttons overlap? ", (btn1.bounds.y + btn1.bounds.height > btn2.bounds.y)

  while not windowShouldClose():
    let mousePos = getMousePosition()

    # Update hover states
    btn1.hovered = (
      mousePos.x >= btn1.bounds.x and
      mousePos.x <= btn1.bounds.x + btn1.bounds.width and
      mousePos.y >= btn1.bounds.y and
      mousePos.y <= btn1.bounds.y + btn1.bounds.height
    )

    btn2.hovered = (
      mousePos.x >= btn2.bounds.x and
      mousePos.x <= btn2.bounds.x + btn2.bounds.width and
      mousePos.y >= btn2.bounds.y and
      mousePos.y <= btn2.bounds.y + btn2.bounds.height
    )

    # Handle clicks
    if isMouseButtonReleased(MouseButton.Left):
      let event = GuiEvent(
        kind: evMouseUp,
        priority: epHigh,
        mousePos: Point(x: mousePos.x, y: mousePos.y)
      )
      discard col.handleInput(event)

    # Render
    beginDrawing()
    clearBackground(raylib.Color(r: 40, g: 40, b: 50, a: 255))

    raylib.drawText("VStack Layout Test", 10'i32, 10'i32, 24'i32, WHITE)
    raylib.drawText("Two buttons should be vertically stacked", 10'i32, 40'i32, 16'i32, LIGHTGRAY)

    # Draw vstack bounds (debug)
    drawRectangleLines(
      int32(col.bounds.x),
      int32(col.bounds.y),
      int32(col.bounds.width),
      int32(col.bounds.height),
      YELLOW
    )

    # Render the vstack (which renders its children)
    col.render()

    # Debug info
    let debugY1 = "Btn1 Y: " & $int(btn1.bounds.y)
    let debugY2 = "Btn2 Y: " & $int(btn2.bounds.y)
    raylib.drawText(debugY1, 10'i32, 500'i32, 14'i32, GREEN)
    raylib.drawText(debugY2, 10'i32, 520'i32, 14'i32, GREEN)

    endDrawing()

when isMainModule:
  main()
