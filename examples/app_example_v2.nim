## Example App using DSL v2
##
## Shows how to build an app using the widget macros

import ../core/widget_dsl_v2
import ../widgets/primitives/[label, rectangle, circle]
import ../widgets/containers/[vstack_v2, hstack_v2, zstack_v2]
import ../widgets/basic/button_v2
import raylib

# Define a simple app widget
defineWidget(MyApp):
  state:
    clickCount: int

  layout:
    # Create UI hierarchy
    let root = newVStack(spacing = 20.0, padding = 20.0)
    root.bounds = widget.bounds

    # Title
    let title = newLabel(text = "RUI2 App Example", fontSize = 24.0, color = BLACK)
    title.bounds = Rect(x: 0, y: 0, width: 400, height: 30)
    root.children.add(title)

    # Counter display
    let counter = newLabel(
      text = "Clicks: " & $widget.clickCount.get(),
      fontSize = 16.0,
      color = DARKGRAY
    )
    counter.bounds = Rect(x: 0, y: 0, width: 200, height: 20)
    root.children.add(counter)

    # Button
    let btn = newButton(
      text = "Click Me!",
      bgColor = BLUE,
      onClick = proc() =
        widget.clickCount.set(widget.clickCount.get() + 1)
    )
    btn.bounds = Rect(x: 0, y: 0, width: 150, height = 40)
    root.children.add(btn)

    # Add root to our children
    widget.children.setLen(0)
    widget.children.add(root)

proc main() =
  initWindow(800, 600, "RUI2 DSL v2 Example")
  setTargetFPS(60)

  let app = newMyApp()
  app.bounds = Rect(x: 0, y: 0, width: 800, height: 600)
  app.layoutDirty = true
  app.layout()

  echo "App created. Starting main loop..."

  while not windowShouldClose():
    # Handle input
    if isMouseButtonPressed(MouseButton.Left):
      let mousePos = getMousePosition()
      let event = GuiEvent(
        kind: evMouseDown,
        mousePos: Point(x: mousePos.x, y: mousePos.y)
      )
      discard app.handleInput(event)

    if isMouseButtonReleased(MouseButton.Left):
      let mousePos = getMousePosition()
      let event = GuiEvent(
        kind: evMouseUp,
        mousePos: Point(x: mousePos.x, y: mousePos.y)
      )
      discard app.handleInput(event)

    # Update layout if needed
    if app.layoutDirty or app.isDirty:
      app.layout()

    # Render
    beginDrawing()
    clearBackground(RAYWHITE)
    app.render()
    drawFPS(10, 10)
    endDrawing()

  closeWindow()

when isMainModule:
  main()
