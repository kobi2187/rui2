type
  InputState = object
    lastMousePos: Point
    lastKeyMods: set[Modifier]
    # Track what raygui is currently handling
    activeWidget: Widget  

proc processInput(app: Widget, inputState: var InputState) =
  # Let raygui handle its active widgets first
  if inputState.activeWidget != nil and 
     raygui.handleWidgetInput(inputState.activeWidget):
    return

  # Then process raw input from raylib
  if IsMouseButtonPressed(MouseButtonLeft):
    let pos = GetMousePosition()
    let target = app.findWidgetAt(pos.x, pos.y)
    if target != nil:
      target.handleClick()