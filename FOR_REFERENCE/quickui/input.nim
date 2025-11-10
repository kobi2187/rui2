# input.nim
import naylib

type
  InputHandler* = object
    activeWidget*: Widget  # Currently focused/active widget
    mousePos*: Point
    lastMousePos*: Point
    dragging*: bool
    dragStart*: Point
    keyModifiers*: set[KeyModifier]  # Ctrl, Shift, Alt

  KeyModifier* = enum
    kmControl, kmShift, kmAlt

proc updateInputState*(handler: var InputHandler) =
  handler.lastMousePos = handler.mousePos
  handler.mousePos = Point(
    x: GetMousePosition().x,
    y: GetMousePosition().y
  )
  
  # Update key modifiers
  handler.keyModifiers = {}
  if IsKeyDown(KeyLeftControl) or IsKeyDown(KeyRightControl):
    handler.keyModifiers.incl(kmControl)
  if IsKeyDown(KeyLeftShift) or IsKeyDown(KeyRightShift):
    handler.keyModifiers.incl(kmShift)
  if IsKeyDown(KeyLeftAlt) or IsKeyDown(KeyRightAlt):
    handler.keyModifiers.incl(kmAlt)

proc processInput*(app: Widget, handler: var InputHandler) =
  # First let raygui handle any active widgets
  if handler.activeWidget != nil:
    case handler.activeWidget.kind
    of wkTextInput:
      var text = TextInput(handler.activeWidget).text
      if GuiTextBox(
        Rectangle(
          x: handler.activeWidget.rect.x,
          y: handler.activeWidget.rect.y,
          width: handler.activeWidget.rect.width,
          height: handler.activeWidget.rect.height
        ),
        text.cstring,
        100,
        handler.activeWidget == app.focused
      ):
        TextInput(handler.activeWidget).text = $text
    of wkSlider:
      # Handle slider input...
    else: discard

  # Then process raw input
  if IsMouseButtonPressed(MouseButtonLeft):
    let target = app.findWidgetAt(handler.mousePos.x, handler.mousePos.y)
    if target != nil:
      app.setFocus(target)
      handler.activeWidget = target
      handler.dragging = true
      handler.dragStart = handler.mousePos
  
  elif IsMouseButtonReleased(MouseButtonLeft):
    handler.dragging = false
    if handler.activeWidget != nil:
      handler.activeWidget.handleClick()
  
  # Handle dragging
  if handler.dragging and handler.activeWidget != nil:
    let delta = Point(
      x: handler.mousePos.x - handler.lastMousePos.x,
      y: handler.mousePos.y - handler.lastMousePos.y
    )
    handler.activeWidget.handleDrag(delta)

  # Handle key input
  let key = GetKeyPressed()
  if key != 0 and app.focused != nil:
    app.focused.handleKeyPress(key, handler.keyModifiers)

  # Handle text input
  let ch = GetCharPressed()
  if ch != 0 and app.focused != nil:
    app.focused.handleTextInput(ch)

  # Handle mouse wheel
  let wheel = GetMouseWheelMove()
  if wheel != 0:
    let target = app.findWidgetAt(handler.mousePos.x, handler.mousePos.y)
    if target != nil:
      target.handleScroll(wheel)