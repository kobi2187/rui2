## Button Test - Visual test for the Button widget
##
## What this tests: Button widget with defineWidget macro
## Expected behavior: Button renders, responds to hover and clicks
## How to verify: Hover over button (color changes), click it (console message)
##
## Status: ✅ Testing

import raylib
import ../core/[types, widget_dsl]
import ../widgets/button

proc main() =
  # Setup window
  initWindow(800, 600, "Button Test")
  defer: closeWindow()
  setTargetFPS(60)

  # Create buttons
  let btn1 = newButton()
  btn1.text = "Click Me!"
  btn1.bounds = Rect(x: 300, y: 200, width: 200, height: 60)
  btn1.onClick = proc() =
    echo "Button 1 clicked!"

  let btn2 = newButton()
  btn2.text = "Another Button"
  btn2.bounds = Rect(x: 300, y: 280, width: 200, height: 60)
  btn2.onClick = proc() =
    echo "Button 2 clicked!"

  # Disabled button
  let btn3 = newButton()
  btn3.text = "Disabled"
  btn3.bounds = Rect(x: 300, y: 360, width: 200, height: 60)
  btn3.enabled = false
  btn3.backgroundColor = Color(r: 150, g: 150, b: 150, a: 255)

  var buttons = @[btn1, btn2, btn3]

  # Main loop
  while not windowShouldClose():
    let mousePos = getMousePosition()

    # Update hover state for all buttons
    for btn in buttons:
      btn.hovered = (
        mousePos.x >= btn.bounds.x and
        mousePos.x <= btn.bounds.x + btn.bounds.width and
        mousePos.y >= btn.bounds.y and
        mousePos.y <= btn.bounds.y + btn.bounds.height
      )

    # Handle mouse events
    if isMouseButtonPressed(MouseButton.Left):
      let event = GuiEvent(
        kind: evMouseDown,
        priority: epHigh,
        mousePos: Point(x: mousePos.x, y: mousePos.y)
      )
      for btn in buttons:
        if btn.handleInput(event):
          break

    if isMouseButtonReleased(MouseButton.Left):
      let event = GuiEvent(
        kind: evMouseUp,
        priority: epHigh,
        mousePos: Point(x: mousePos.x, y: mousePos.y)
      )
      for btn in buttons:
        if btn.handleInput(event):
          break

    # Render
    beginDrawing()
    clearBackground(Color(r: 40, g: 40, b: 50, a: 255))  # Dark background

    # Draw title
    raylib.drawText("Button Widget Test", 10'i32, 10'i32, 24'i32, WHITE)
    raylib.drawText("Hover over buttons and click them", 10'i32, 40'i32, 16'i32, LIGHTGRAY)
    raylib.drawText("Check console for click messages", 10'i32, 60'i32, 16'i32, LIGHTGRAY)

    # Render buttons
    for btn in buttons:
      btn.render()

    # Draw mouse position for debugging
    let mouseText = "Mouse: " & $int(mousePos.x) & ", " & $int(mousePos.y)
    raylib.drawText(mouseText, 10'i32, 550'i32, 14'i32, LIGHTGRAY)

    endDrawing()

when isMainModule:
  main()
