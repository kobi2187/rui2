## Test for YAML-UI style Button with on_click: section

import raylib
import ../core/types
import ../widgets/button_yaml

proc main() =
  initWindow(800, 600, "YAML-UI Style Button Test")
  defer: closeWindow()
  setTargetFPS(60)

  # Create button using YAML-UI style with on_click
  let btn = newButtonYAML()
  btn.text = "Click Me (YAML-UI style!)"
  btn.bounds = Rect(x: 300, y: 250, width: 200, height: 60)
  btn.onClick = proc() =
    echo "onClick callback fired!"

  var clickCount = 0

  while not windowShouldClose():
    let mousePos = getMousePosition()

    # Update hover state
    btn.hovered = (
      mousePos.x >= btn.bounds.x and
      mousePos.x <= btn.bounds.x + btn.bounds.width and
      mousePos.y >= btn.bounds.y and
      mousePos.y <= btn.bounds.y + btn.bounds.height
    )

    # Handle mouse up event for on_click
    if isMouseButtonReleased(MouseButton.Left):
      let event = GuiEvent(
        kind: evMouseUp,
        priority: epHigh,
        mousePos: Point(x: mousePos.x, y: mousePos.y)
      )
      if btn.handleInput(event):
        clickCount += 1

    # Render
    beginDrawing()
    clearBackground(Color(r: 40, g: 40, b: 50, a: 255))

    raylib.drawText("YAML-UI Style Button Test", 10'i32, 10'i32, 24'i32, WHITE)
    raylib.drawText("Button uses on_click: section (matches YAML-UI syntax)", 10'i32, 40'i32, 16'i32, LIGHTGRAY)
    let clickText = "Clicks: " & $clickCount
    raylib.drawText(clickText, 10'i32, 60'i32, 16'i32, LIGHTGRAY)

    btn.render()

    endDrawing()

when isMainModule:
  main()
