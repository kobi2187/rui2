# widget_dsl.nim
macro defineWidget*(name: untyped, body: untyped): untyped =
  ## Enhanced widget definition macro
  result = newStmtList()
  
  var 
    props = newNimNode(nnkRecList)
    renderBody: NimNode
    handleInputBody: NimNode
    stateBody: NimNode
  
  for section in body:
    case section[0].strVal
    of "props":
      for prop in section[1]:
        props.add(prop)
    of "render":
      renderBody = section[1]
    of "input":
      handleInputBody = section[1]
    of "state":
      stateBody = section[1]
  
  # Generate the widget type
  let typeName = ident($name)
  result.add quote do:
    type `typeName` = ref object of Widget
      `props`

  # Generate render method that uses raygui
  let renderProc = newProc(
    name = ident("draw"),
    params = [newEmptyNode(), newIdentDefs(ident("widget"), typeName)],
    body = renderBody
  )
  result.add renderProc

# Example usage with raygui:
defineWidget Button:
  props:
    text: string
    onClick: proc()
    isPressed: bool
    
  render:
    if GuiButton(Rectangle(
      x: widget.rect.x,
      y: widget.rect.y,
      width: widget.rect.width,
      height: widget.rect.height
    ), widget.text):
      if widget.enabled and widget.onClick != nil:
        widget.onClick()

  input:
    if event.kind == ieMousePress and widget.enabled:
      widget.isPressed = true
      true
    elif event.kind == ieMouseRelease and widget.isPressed:
      widget.isPressed = false
      if widget.containsPoint(event.mousePos):
        widget.onClick()
      true
    else:
      false

  state:
    fields:
      text: string
      enabled: bool
      pressed: bool