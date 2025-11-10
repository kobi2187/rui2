## Visual Test - Widgets v2
##
## Renders widgets to a window so we can see them!

import ../core/types
import ../core/main_loop
import ../widgets/primitives/[label, rectangle, circle]
import ../widgets/containers/[vstack_v2, hstack_v2, zstack_v2]
import ../widgets/basic/button_v2
import raylib

proc main() =
  # Initialize window
  initWindow(800, 600, "RUI2 Widgets Test")
  setTargetFPS(60)

  echo "=== RUI2 Visual Test ==="

  # Create UI
  let root = newVStack(spacing = 20.0, padding = 20.0)
  root.bounds = Rect(x: 0, y: 0, width: 800, height: 600)

  # Title
  let title = newLabel(text = "RUI2 Widgets (DSL v2)", fontSize = 24.0, color = BLACK)
  title.bounds = Rect(x: 0, y: 0, width: 400, height: 30)
  root.children.add(title)

  # Buttons
  var clickCount = 0
  let button1 = newButton(
    text = "Click Me!",
    bgColor = BLUE,
    onClick = proc() =
      clickCount += 1
      echo "Button 1 clicked! Count: ", clickCount
  )
  button1.bounds = Rect(x: 0, y: 0, width: 150, height: 40)
  root.children.add(button1)

  let button2 = newButton(
    text = "Another Button",
    bgColor = GREEN,
    onClick = proc() = echo "Button 2 clicked!"
  )
  button2.bounds = Rect(x: 0, y: 0, width: 180, height: 40)
  root.children.add(button2)

  # Horizontal stack of colored rectangles
  let hstack = newHStack(spacing = 10.0)
  hstack.bounds = Rect(x: 0, y: 0, width: 400, height: 60)

  let redRect = newRectangle(color = RED, cornerRadius = 8.0)
  redRect.bounds = Rect(x: 0, y: 0, width: 80, height: 60)

  let greenRect = newRectangle(color = GREEN, cornerRadius = 8.0)
  greenRect.bounds = Rect(x: 0, y: 0, width: 80, height: 60)

  let blueRect = newRectangle(color = BLUE, cornerRadius = 8.0)
  blueRect.bounds = Rect(x: 0, y: 0, width: 80, height: 60)

  hstack.children.add(redRect)
  hstack.children.add(greenRect)
  hstack.children.add(blueRect)
  root.children.add(hstack)

  # ZStack example (circle on rectangle)
  let zstack = newZStack()
  zstack.bounds = Rect(x: 0, y: 0, width: 100, height: 100)

  let bg = newRectangle(color = LIGHTGRAY, cornerRadius = 10.0)
  bg.bounds = Rect(x: 0, y: 0, width: 100, height: 100)

  let fg = newCircle(color = ORANGE, filled = true)
  fg.bounds = Rect(x: 25, y: 25, width: 50, height: 50)

  zstack.children.add(bg)
  zstack.children.add(fg)
  root.children.add(zstack)

  # Info label
  let info = newLabel(
    text = "Click the buttons above!",
    fontSize = 14.0,
    color = DARKGRAY
  )
  info.bounds = Rect(x: 0, y: 0, width: 300, height: 20)
  root.children.add(info)

  # Initial layout
  root.layoutDirty = true
  root.layout()

  echo "UI created. Starting main loop..."

  # Main loop
  while not windowShouldClose():
    # Handle input
    if isMouseButtonPressed(MouseButton.Left):
      let mousePos = getMousePosition()
      let event = GuiEvent(
        kind: evMouseDown,
        mousePos: Point(x: mousePos.x, y: mousePos.y)
      )
      discard root.handleInput(event)

    if isMouseButtonReleased(MouseButton.Left):
      let mousePos = getMousePosition()
      let event = GuiEvent(
        kind: evMouseUp,
        mousePos: Point(x: mousePos.x, y: mousePos.y)
      )
      discard root.handleInput(event)

    # Update layout if needed
    if root.layoutDirty:
      root.layout()

    # Render
    beginDrawing()
    clearBackground(RAYWHITE)

    # Render widget tree
    root.render()

    # Draw FPS
    drawFPS(10, 10)

    endDrawing()

  closeWindow()
  echo "Test complete!"

when isMainModule:
  main()
