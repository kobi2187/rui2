## Widget Definition DSL
##
## Provides the `defineWidget` macro for creating custom widgets.
## Users can define widgets with properties, rendering, layout, and input handling.
##
## Example:
##   defineWidget(Button):
##     props:
##       text: string
##       onClick: proc()
##
##     init:
##       widget.text = ""
##
##     render:
##       drawRoundedRect(widget.bounds, 4.0, BLUE)
##       drawText(widget.text, ...)
##
##     input:
##       if isMouseButtonPressed(MouseButton.Left):
##         if widget.onClick != nil:
##           widget.onClick()

import macros
import types

export types

macro defineWidget*(name: untyped, body: untyped): untyped =
  ## Define a custom widget with properties, rendering, layout, and input handling.
  ##
  ## Sections (all optional):
  ##   props:      Additional fields for this widget type
  ##   init:       Initialize widget fields (runs in constructor)
  ##   render:     Draw the widget (becomes method render)
  ##   measure:    Calculate preferred size (becomes method measure)
  ##   layout:     Position children (becomes method layout)
  ##   input:      Custom input handling (becomes part of method handleInput)
  ##
  ## YAML-UI style event handlers (automatically integrated into handleInput):
  ##   on_click:   Mouse click handler (evMouseUp within bounds)
  ##   on_change:  Value change handler
  ##   on_select:  Selection handler
  ##   on_focus:   Focus gained handler
  ##   on_blur:    Focus lost handler

  result = newStmtList()

  var
    props = newNimNode(nnkRecList)
    renderBody: NimNode
    measureBody: NimNode
    handleInputBody: NimNode
    initBody: NimNode
    layoutBody: NimNode
    # YAML-UI event handlers
    onClickBody: NimNode
    onChangeBody: NimNode
    onSelectBody: NimNode
    onFocusBody: NimNode
    onBlurBody: NimNode

  # Parse sections from body
  for section in body:
    let sectionName = section[0].strVal
    let sectionBody = section[1]

    case sectionName
    of "props":
      # Add each property to the record list
      # The sectionBody is a StmtList, iterate its children
      # Each prop is a Call node like: Call(Ident "text", StmtList(Ident "string"))
      # We need to convert to IdentDefs: IdentDefs(Postfix(*, Ident "text"), Ident "string", Empty)
      if sectionBody.kind == nnkStmtList:
        for prop in sectionBody:
          if prop.kind == nnkCall and prop.len == 2:
            # prop[0] is the field name (Ident)
            # prop[1] is StmtList containing the type
            let fieldName = prop[0]

            let fieldType = if prop[1].kind == nnkStmtList and prop[1].len > 0:
                             prop[1][0]
                           else:
                             prop[1]

            # Always export properties - wrap field name with postfix *
            let exportedFieldName = nnkPostfix.newTree(ident("*"), fieldName)

            # Create IdentDefs node
            let identDef = nnkIdentDefs.newTree(
              exportedFieldName,  # name with * export marker
              fieldType,  # type
              newEmptyNode()  # default value
            )
            props.add(identDef)
          else:
            # Fallback: add as-is
            props.add(prop)
      else:
        props.add(sectionBody)
    of "render":
      renderBody = sectionBody
    of "measure":
      measureBody = sectionBody
    of "input":
      handleInputBody = sectionBody
    of "init":
      initBody = sectionBody
    of "layout":
      layoutBody = sectionBody
    # YAML-UI style event handlers
    of "on_click":
      onClickBody = sectionBody
    of "on_change":
      onChangeBody = sectionBody
    of "on_select":
      onSelectBody = sectionBody
    of "on_focus":
      onFocusBody = sectionBody
    of "on_blur":
      onBlurBody = sectionBody
    else:
      error("Unknown section: " & sectionName, section)

  let typeName = ident($name)
  let widgetIdent = ident("widget")

  # Generate the widget type definition
  let objConstr = nnkObjectTy.newTree(
    newEmptyNode(),
    nnkOfInherit.newTree(ident("Widget")),
    props
  )

  let typeDef = nnkTypeDef.newTree(
    nnkPostfix.newTree(ident("*"), typeName),
    newEmptyNode(),
    nnkRefTy.newTree(objConstr)
  )

  result.add(nnkTypeSection.newTree(typeDef))

  # Generate constructor (newButton, newLabel, etc.)
  let constructorName = ident("new" & $name)
  var constructorBody = newStmtList()

  # Create the widget instance
  constructorBody.add quote do:
    result = `typeName`()
    result.id = newWidgetId()
    result.visible = true
    result.enabled = true
    result.hovered = false
    result.pressed = false
    result.focused = false
    result.isDirty = true
    result.layoutDirty = true
    result.zIndex = 0
    result.children = @[]
    result.parent = nil
    result.bounds = Rect(x: 0, y: 0, width: 100, height: 30)
    result.previousBounds = result.bounds

  # Add user's init code
  if not initBody.isNil:
    # Inject 'widget' identifier for user's init code
    constructorBody.add quote do:
      let widget {.inject.} = result
    constructorBody.add initBody

  let constructorProc = newProc(
    name = nnkPostfix.newTree(ident("*"), constructorName),
    params = [typeName],
    body = constructorBody
  )
  result.add(constructorProc)

  # Generate render method
  if not renderBody.isNil:
    # Create method with proper signature
    let renderMethod = quote do:
      method render*(`widgetIdent`: `typeName`) =
        if not `widgetIdent`.visible: return
        `renderBody`
        # Render children after parent
        for child in `widgetIdent`.children:
          child.render()

    result.add(renderMethod)

  # Generate measure method
  if not measureBody.isNil:
    let constraintsIdent = ident("constraints")
    let measureMethod = quote do:
      method measure*(`widgetIdent`: `typeName`, `constraintsIdent`: Constraints): Size =
        `measureBody`

    result.add(measureMethod)

  # Generate layout method
  if not layoutBody.isNil:
    let layoutMethod = quote do:
      method layout*(`widgetIdent`: `typeName`) =
        `layoutBody`
        # Layout children
        for child in `widgetIdent`.children:
          child.layout()

    result.add(layoutMethod)

  # Generate handleInput method (combines input: section with YAML-UI event handlers)
  if not handleInputBody.isNil or not onClickBody.isNil or not onChangeBody.isNil or
     not onSelectBody.isNil or not onFocusBody.isNil or not onBlurBody.isNil:
    let eventIdent = ident("event")
    var inputMethodBody = newStmtList()

    # Add visibility/enabled check
    inputMethodBody.add(quote do:
      if not `widgetIdent`.visible or not `widgetIdent`.enabled:
        return false
    )

    # Add user's custom input: section if present
    if not handleInputBody.isNil:
      inputMethodBody.add(handleInputBody)

    # Generate YAML-UI event handlers
    if not onClickBody.isNil:
      inputMethodBody.add(quote do:
        if `eventIdent`.kind == evMouseUp:
          # Check if click is within bounds
          let mouseX = `eventIdent`.mousePos.x
          let mouseY = `eventIdent`.mousePos.y
          if mouseX >= `widgetIdent`.bounds.x and mouseX <= `widgetIdent`.bounds.x + `widgetIdent`.bounds.width and
             mouseY >= `widgetIdent`.bounds.y and mouseY <= `widgetIdent`.bounds.y + `widgetIdent`.bounds.height:
            `onClickBody`
            return true
      )

    if not onChangeBody.isNil:
      inputMethodBody.add(onChangeBody)

    if not onSelectBody.isNil:
      inputMethodBody.add(onSelectBody)

    if not onFocusBody.isNil:
      inputMethodBody.add(onFocusBody)

    if not onBlurBody.isNil:
      inputMethodBody.add(onBlurBody)

    # Add child propagation
    inputMethodBody.add(quote do:
      # Propagate to children (front to back, stop if handled)
      for i in countdown(`widgetIdent`.children.high, 0):
        if `widgetIdent`.children[i].handleInput(`eventIdent`):
          return true

      return false
    )

    let inputMethod = newProc(
      name = nnkPostfix.newTree(ident("*"), ident("handleInput")),
      params = [ident("bool"),
                newIdentDefs(widgetIdent, typeName),
                newIdentDefs(eventIdent, ident("GuiEvent"))],
      body = inputMethodBody,
      procType = nnkMethodDef
    )

    result.add(inputMethod)

# Helper proc for adding children (used by all widgets)
proc addChild*(parent: Widget, child: Widget) =
  ## Add a child widget to a parent
  parent.children.add(child)
  child.parent = parent
  # Children inherit parent's z-index + small offset
  child.zIndex = parent.zIndex + 1
  parent.layoutDirty = true
