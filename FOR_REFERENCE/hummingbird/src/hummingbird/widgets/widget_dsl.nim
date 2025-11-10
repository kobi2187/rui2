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
