## Widget DSL v2
##
## Two macros for defining widgets:
## - definePrimitive: Leaf widgets that draw themselves (may use internal layout)
## - defineWidget: Composite widgets that arrange user-provided children
##
## Design decisions documented in:
## - WIDGET_DSL_STANDARD.md
## - DSL_CLARIFICATIONS.md
## - PRIMITIVE_PURITY_ANALYSIS.md

import macros
import types
import link

export types
export link

# ============================================================================
# Helper: Parse Actions Block
# ============================================================================

proc parseActions(actionsBody: NimNode): seq[tuple[name: string, params: seq[tuple[name: string, typ: NimNode]], returnType: NimNode]] =
  ## Parse actions block and extract action signatures
  ## Format: actionName(param1: Type, param2: Type) -> ReturnType
  ## Or: actionName(param1: Type)  # void return
  result = @[]

  if actionsBody.isNil or actionsBody.kind != nnkStmtList:
    return

  for action in actionsBody:
    case action.kind:
    of nnkCall:
      # actionName() - no parameters
      let actionName = action[0].strVal
      var params: seq[tuple[name: string, typ: NimNode]] = @[]
      var returnType: NimNode = ident("void")
      result.add((actionName, params, returnType))

    of nnkObjConstr:
      # actionName(param: Type, ...) - with parameters
      let actionName = action[0].strVal
      var params: seq[tuple[name: string, typ: NimNode]] = @[]
      var returnType: NimNode = ident("void")

      # Parse parameters (skip first element which is the name)
      for i in 1 ..< action.len:
        if action[i].kind == nnkExprColonExpr:
          params.add((action[i][0].strVal, action[i][1]))

      result.add((actionName, params, returnType))

    of nnkInfix:
      # actionName(...) -> ReturnType
      if action[0].strVal == "->":
        let callNode = action[1]
        let returnType = action[2]

        if callNode.kind == nnkCall:
          # actionName() -> ReturnType
          let actionName = callNode[0].strVal
          var params: seq[tuple[name: string, typ: NimNode]] = @[]
          result.add((actionName, params, returnType))

        elif callNode.kind == nnkObjConstr:
          # actionName(param: Type) -> ReturnType
          let actionName = callNode[0].strVal
          var params: seq[tuple[name: string, typ: NimNode]] = @[]

          # Parse parameters
          for i in 1 ..< callNode.len:
            if callNode[i].kind == nnkExprColonExpr:
              params.add((callNode[i][0].strVal, callNode[i][1]))

          result.add((actionName, params, returnType))

    else:
      # Skip unknown node types
      discard

# ============================================================================
# Macro: definePrimitive
# ============================================================================

macro definePrimitive*(name: untyped, body: untyped): untyped =
  ## Define a primitive widget (leaf widget that draws itself)
  ##
  ## Blocks:
  ##   props:    Public properties (immutable after construction)
  ##   state:    Internal reactive state (Link[T])
  ##   actions:  Callback signatures
  ##   events:   Event handlers (on_mouse_up, on_key_down, etc.)
  ##   layout:   Internal layout (optional, for complex primitives)
  ##   render:   Drawing code (optional, if no layout)
  ##
  ## Example:
  ##   definePrimitive(Button):
  ##     props:
  ##       text: string
  ##       disabled: bool = false
  ##
  ##     state:
  ##       pressed: bool
  ##       hovered: bool
  ##
  ##     actions:
  ##       onClick()
  ##
  ##     events:
  ##       on_mouse_up:
  ##         if not widget.disabled and widget.onClick.isSome:
  ##           widget.onClick.get()()
  ##
  ##     render:
  ##       let theme = getTheme()
  ##       drawRoundedRect(widget.bounds, theme.primary)

  result = newStmtList()

  var
    propsFields = newNimNode(nnkRecList)
    stateFields = newNimNode(nnkRecList)
    actionFields = newNimNode(nnkRecList)
    renderBody: NimNode
    layoutBody: NimNode
    initBody: NimNode
    eventHandlers = newStmtList()

  # Parse sections
  for section in body:
    let sectionName = section[0].strVal
    let sectionBody = section[1]

    case sectionName
    of "props":
      # Parse props into record fields
      if sectionBody.kind == nnkStmtList:
        for prop in sectionBody:
          # Debug: echo prop.treeRepr
          if prop.kind == nnkCall and prop.len == 2:
            # Case 1: name(type) or name(type = default)
            let fieldName = prop[0]
            var fieldType: NimNode
            var defaultValue: NimNode = newEmptyNode()

            if prop[1].kind == nnkStmtList and prop[1].len > 0:
              let firstChild = prop[1][0]
              if firstChild.kind == nnkAsgn:
                # name: type = default
                fieldType = firstChild[0]
                defaultValue = firstChild[1]
              else:
                # name: type
                fieldType = firstChild
            else:
              fieldType = prop[1]

            # Export field
            let exportedName = nnkPostfix.newTree(ident("*"), fieldName)
            propsFields.add(nnkIdentDefs.newTree(
              exportedName,
              fieldType,
              defaultValue
            ))
          elif prop.kind == nnkAsgn:
            # Property with default: name = value (shouldn't happen with colon syntax)
            error("Use 'name: Type = value' syntax for props with defaults", prop)

    of "state":
      # Parse state fields - will be wrapped in Link[T]
      if sectionBody.kind == nnkStmtList:
        for stateField in sectionBody:
          if stateField.kind == nnkCall and stateField.len == 2:
            let fieldName = stateField[0]
            let fieldType = if stateField[1].kind == nnkStmtList and stateField[1].len > 0:
                             stateField[1][0]
                           else:
                             stateField[1]

            # Wrap in Link[T]
            let linkType = nnkBracketExpr.newTree(ident("Link"), fieldType)
            stateFields.add(nnkIdentDefs.newTree(
              fieldName,
              linkType,
              newEmptyNode()
            ))

    of "actions":
      # Parse action signatures
      let actions = parseActions(sectionBody)
      for action in actions:
        let actionName = ident(action.name)

        # Build proc type
        var procType: NimNode
        if action.params.len == 0 and action.returnType.strVal == "void":
          # proc()
          procType = nnkProcTy.newTree(
            nnkFormalParams.newTree(newEmptyNode()),
            newEmptyNode()
          )
        else:
          # proc(params): ReturnType
          var formalParams = nnkFormalParams.newTree(action.returnType)
          for param in action.params:
            formalParams.add(nnkIdentDefs.newTree(
              ident(param.name),
              param.typ,
              newEmptyNode()
            ))

          procType = nnkProcTy.newTree(formalParams, newEmptyNode())

        # Wrap in Option[proc(...)]
        let optionType = nnkBracketExpr.newTree(ident("Option"), procType)
        let exportedName = nnkPostfix.newTree(ident("*"), actionName)
        actionFields.add(nnkIdentDefs.newTree(
          exportedName,
          optionType,
          newEmptyNode()
        ))

    of "events":
      # Parse event handlers - we'll generate handleInput method
      eventHandlers = sectionBody

    of "render":
      renderBody = sectionBody

    of "layout":
      layoutBody = sectionBody

    of "init":
      initBody = sectionBody

    else:
      error("Unknown section in definePrimitive: " & sectionName, section)

  let typeName = ident($name)
  let widgetIdent = ident("widget")

  # Generate type definition
  var allFields = newNimNode(nnkRecList)
  for field in propsFields:
    allFields.add(field)
  for field in stateFields:
    allFields.add(field)
  for field in actionFields:
    allFields.add(field)

  # Build type manually (can't splice RecList into quote)
  let typeDef = nnkTypeSection.newTree(
    nnkTypeDef.newTree(
      nnkPostfix.newTree(ident("*"), typeName),
      newEmptyNode(),
      nnkRefTy.newTree(
        nnkObjectTy.newTree(
          newEmptyNode(),
          nnkOfInherit.newTree(ident("Widget")),
          allFields
        )
      )
    )
  )

  result.add(typeDef)

  # Generate constructor
  let constructorName = ident("new" & $name)
  var constructorParams = @[typeName]  # Return type
  var constructorBody = newStmtList()

  # Build parameter list from props
  var propAssignments = newStmtList()
  for field in propsFields:
    if field.kind == nnkIdentDefs:
      let fieldName =
        if field[0].kind == nnkPostfix:
          field[0][1]  # Extract name from Postfix(*, name)
        else:
          field[0]
      let fieldType = field[1]
      let defaultVal = field[2]

      # Add to constructor parameters
      if defaultVal.kind == nnkEmpty:
        # Required parameter (no default)
        constructorParams.add(newIdentDefs(fieldName, fieldType))
      else:
        # Optional parameter (has default)
        constructorParams.add(newIdentDefs(fieldName, fieldType, defaultVal))

      # Add assignment in constructor body
      propAssignments.add(quote do:
        result.`fieldName` = `fieldName`
      )

  # Build parameter list from actions
  var actionAssignments = newStmtList()
  for field in actionFields:
    if field.kind == nnkIdentDefs:
      let actionName =
        if field[0].kind == nnkPostfix:
          field[0][1]
        else:
          field[0]
      let actionType = field[1]  # Option[proc(...)]

      # Extract proc type from Option[T]
      let procType =
        if actionType.kind == nnkBracketExpr and actionType[0].strVal == "Option":
          actionType[1]
        else:
          actionType

      # Add to constructor as optional parameter with nil default
      constructorParams.add(newIdentDefs(actionName, procType, newNilLit()))

      # Add assignment in constructor body: result.action = if action != nil: some(action) else: none(proc)
      actionAssignments.add(quote do:
        result.`actionName` = if `actionName` != nil: some(`actionName`) else: none(`procType`)
      )

  # Constructor body
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

  # Add prop assignments
  constructorBody.add(propAssignments)

  # Initialize state fields with Link
  for field in stateFields:
    if field.kind == nnkIdentDefs:
      let fieldName = field[0]
      let linkType = field[1]  # Link[T]

      # Extract T from Link[T]
      let innerType =
        if linkType.kind == nnkBracketExpr and linkType[0].strVal == "Link":
          linkType[1]
        else:
          linkType

      # Get default value based on type
      var defaultValue: NimNode
      case innerType.strVal
      of "bool": defaultValue = ident("false")
      of "int": defaultValue = newLit(0)
      of "float", "float32", "float64": defaultValue = newLit(0.0)
      of "string": defaultValue = newLit("")
      else:
        # For complex types, use default constructor
        defaultValue = newCall(innerType)

      constructorBody.add(quote do:
        result.`fieldName` = newLink(`defaultValue`)
      )

  # Add action assignments
  constructorBody.add(actionAssignments)

  # Add user's init code
  if not initBody.isNil:
    constructorBody.add quote do:
      let `widgetIdent` {.inject.} = result
    constructorBody.add(initBody)

  let constructorProc = newProc(
    name = nnkPostfix.newTree(ident("*"), constructorName),
    params = constructorParams,
    body = constructorBody
  )
  result.add(constructorProc)

  # Generate render method
  if not renderBody.isNil:
    let renderMethod = quote do:
      method render*(`widgetIdent`: `typeName`) =
        if not `widgetIdent`.visible: return
        `renderBody`
        # Render children after (if using layout internally)
        for child in `widgetIdent`.children:
          child.render()

    result.add(renderMethod)

  # Generate handleInput method from events block
  if eventHandlers.len > 0:
    let eventIdent = ident("event")
    var inputMethodBody = newStmtList()

    # Add visibility/enabled check
    inputMethodBody.add(quote do:
      if not `widgetIdent`.visible or not `widgetIdent`.enabled:
        return false
    )

    # Map event handler names to EventKind
    # on_mouse_down -> evMouseDown
    # on_mouse_up -> evMouseUp
    # on_mouse_move -> evMouseMove
    # etc.
    proc eventNameToKind(name: string): string =
      case name
      of "on_mouse_down": "evMouseDown"
      of "on_mouse_up": "evMouseUp"
      of "on_mouse_move": "evMouseMove"
      of "on_mouse_hover": "evMouseHover"
      of "on_key_down": "evKeyDown"
      of "on_key_up": "evKeyUp"
      of "on_char": "evChar"
      else: ""

    # Build case statement for event routing
    var caseStmt = nnkCaseStmt.newTree(
      nnkDotExpr.newTree(eventIdent, ident("kind"))
    )

    # Parse event handlers
    for handler in eventHandlers:
      if handler.kind == nnkCall and handler.len == 2:
        let handlerName = handler[0].strVal
        let handlerBody = handler[1]
        let eventKind = eventNameToKind(handlerName)

        if eventKind != "":
          # Add case branch
          var branch = nnkOfBranch.newTree(
            ident(eventKind),
            handlerBody
          )
          caseStmt.add(branch)

    # Add else branch (event not handled)
    caseStmt.add(nnkElse.newTree(
      quote do:
        discard
    ))

    inputMethodBody.add(caseStmt)

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

  # If has layout block, generate layout setup
  if not layoutBody.isNil:
    # TODO: Process layout DSL
    discard

  # Debug: Print generated code
  # echo result.repr

# ============================================================================
# Macro: defineWidget
# ============================================================================

macro defineWidget*(name: untyped, body: untyped): untyped =
  ## Define a composite widget (container with user-provided children)
  ##
  ## Blocks:
  ##   props:    Public properties
  ##   state:    Internal reactive state
  ##   actions:  Callback signatures
  ##   events:   Event handlers
  ##   layout:   Child arrangement (REQUIRED for composites)
  ##
  ## Example:
  ##   defineWidget(VStack):
  ##     props:
  ##       spacing: float = 8.0
  ##       alignment: Alignment = Leading
  ##
  ##     layout:
  ##       var y = widget.bounds.y
  ##       for child in widget.children:
  ##         child.bounds.y = y
  ##         y += child.bounds.height + widget.spacing

  result = newStmtList()

  var
    propsFields = newNimNode(nnkRecList)
    stateFields = newNimNode(nnkRecList)
    actionFields = newNimNode(nnkRecList)
    renderBody: NimNode
    layoutBody: NimNode
    initBody: NimNode
    eventHandlers = newStmtList()

  # Parse sections (same as definePrimitive)
  for section in body:
    let sectionName = section[0].strVal
    let sectionBody = section[1]

    case sectionName
    of "props":
      # Parse props into record fields
      if sectionBody.kind == nnkStmtList:
        for prop in sectionBody:
          if prop.kind == nnkCall and prop.len == 2:
            let fieldName = prop[0]
            var fieldType: NimNode
            var defaultValue: NimNode = newEmptyNode()

            if prop[1].kind == nnkStmtList and prop[1].len > 0:
              let firstChild = prop[1][0]
              if firstChild.kind == nnkAsgn:
                fieldType = firstChild[0]
                defaultValue = firstChild[1]
              else:
                fieldType = firstChild
            else:
              fieldType = prop[1]

            let exportedName = nnkPostfix.newTree(ident("*"), fieldName)
            propsFields.add(nnkIdentDefs.newTree(
              exportedName,
              fieldType,
              defaultValue
            ))
          elif prop.kind == nnkAsgn:
            error("Use 'name: Type = value' syntax for props with defaults", prop)

    of "state":
      # Parse state fields - will be wrapped in Link[T]
      if sectionBody.kind == nnkStmtList:
        for stateField in sectionBody:
          if stateField.kind == nnkCall and stateField.len == 2:
            let fieldName = stateField[0]
            let fieldType = if stateField[1].kind == nnkStmtList and stateField[1].len > 0:
                             stateField[1][0]
                           else:
                             stateField[1]

            let linkType = nnkBracketExpr.newTree(ident("Link"), fieldType)
            stateFields.add(nnkIdentDefs.newTree(
              fieldName,
              linkType,
              newEmptyNode()
            ))

    of "actions":
      # Parse action signatures
      let actions = parseActions(sectionBody)
      for action in actions:
        let actionName = ident(action.name)

        var procType: NimNode
        if action.params.len == 0 and action.returnType.strVal == "void":
          procType = nnkProcTy.newTree(
            nnkFormalParams.newTree(newEmptyNode()),
            newEmptyNode()
          )
        else:
          var formalParams = nnkFormalParams.newTree(action.returnType)
          for param in action.params:
            formalParams.add(nnkIdentDefs.newTree(
              ident(param.name),
              param.typ,
              newEmptyNode()
            ))
          procType = nnkProcTy.newTree(formalParams, newEmptyNode())

        let optionType = nnkBracketExpr.newTree(ident("Option"), procType)
        let exportedName = nnkPostfix.newTree(ident("*"), actionName)
        actionFields.add(nnkIdentDefs.newTree(
          exportedName,
          optionType,
          newEmptyNode()
        ))

    of "events":
      eventHandlers = sectionBody

    of "render":
      renderBody = sectionBody

    of "layout":
      layoutBody = sectionBody

    of "init":
      initBody = sectionBody

    else:
      error("Unknown section in defineWidget: " & sectionName, section)

  # Composite widgets REQUIRE layout block
  if layoutBody.isNil:
    error("defineWidget requires a 'layout:' block", body)

  let typeName = ident($name)
  let widgetIdent = ident("widget")

  # Generate type definition (same as definePrimitive)
  var allFields = newNimNode(nnkRecList)
  for field in propsFields:
    allFields.add(field)
  for field in stateFields:
    allFields.add(field)
  for field in actionFields:
    allFields.add(field)

  let typeDef = nnkTypeSection.newTree(
    nnkTypeDef.newTree(
      nnkPostfix.newTree(ident("*"), typeName),
      newEmptyNode(),
      nnkRefTy.newTree(
        nnkObjectTy.newTree(
          newEmptyNode(),
          nnkOfInherit.newTree(ident("Widget")),
          allFields
        )
      )
    )
  )

  result.add(typeDef)

  # Generate constructor (same logic as definePrimitive)
  let constructorName = ident("new" & $name)
  var constructorParams = @[typeName]
  var constructorBody = newStmtList()

  var propAssignments = newStmtList()
  for field in propsFields:
    if field.kind == nnkIdentDefs:
      let fieldName =
        if field[0].kind == nnkPostfix:
          field[0][1]
        else:
          field[0]
      let fieldType = field[1]
      let defaultVal = field[2]

      if defaultVal.kind == nnkEmpty:
        constructorParams.add(newIdentDefs(fieldName, fieldType))
      else:
        constructorParams.add(newIdentDefs(fieldName, fieldType, defaultVal))

      propAssignments.add(quote do:
        result.`fieldName` = `fieldName`
      )

  var actionAssignments = newStmtList()
  for field in actionFields:
    if field.kind == nnkIdentDefs:
      let actionName =
        if field[0].kind == nnkPostfix:
          field[0][1]
        else:
          field[0]
      let actionType = field[1]

      let procType =
        if actionType.kind == nnkBracketExpr and actionType[0].strVal == "Option":
          actionType[1]
        else:
          actionType

      constructorParams.add(newIdentDefs(actionName, procType, newNilLit()))

      actionAssignments.add(quote do:
        result.`actionName` = if `actionName` != nil: some(`actionName`) else: none(`procType`)
      )

  # Constructor body
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

  constructorBody.add(propAssignments)

  # Initialize state fields
  for field in stateFields:
    if field.kind == nnkIdentDefs:
      let fieldName = field[0]
      let linkType = field[1]

      let innerType =
        if linkType.kind == nnkBracketExpr and linkType[0].strVal == "Link":
          linkType[1]
        else:
          linkType

      var defaultValue: NimNode
      case innerType.strVal
      of "bool": defaultValue = ident("false")
      of "int": defaultValue = newLit(0)
      of "float", "float32", "float64": defaultValue = newLit(0.0)
      of "string": defaultValue = newLit("")
      else:
        defaultValue = newCall(innerType)

      constructorBody.add(quote do:
        result.`fieldName` = newLink(`defaultValue`)
      )

  constructorBody.add(actionAssignments)

  if not initBody.isNil:
    constructorBody.add quote do:
      let `widgetIdent` {.inject.} = result
    constructorBody.add(initBody)

  let constructorProc = newProc(
    name = nnkPostfix.newTree(ident("*"), constructorName),
    params = constructorParams,
    body = constructorBody
  )
  result.add(constructorProc)

  # Generate layout method (override base Widget.layout)
  let layoutMethod = quote do:
    method layout*(`widgetIdent`: `typeName`) =
      if not `widgetIdent`.layoutDirty: return

      `layoutBody`

      `widgetIdent`.layoutDirty = false

  result.add(layoutMethod)

  # Generate render method (optional, for decorations)
  if not renderBody.isNil:
    let renderMethod = quote do:
      method render*(`widgetIdent`: `typeName`) =
        if not `widgetIdent`.visible: return
        `renderBody`
        for child in `widgetIdent`.children:
          child.render()

    result.add(renderMethod)
  else:
    # Default render: just render children
    let renderMethod = quote do:
      method render*(`widgetIdent`: `typeName`) =
        if not `widgetIdent`.visible: return
        for child in `widgetIdent`.children:
          child.render()

    result.add(renderMethod)

  # Generate handleInput (same as definePrimitive if events defined)
  if eventHandlers.len > 0:
    let eventIdent = ident("event")
    var inputMethodBody = newStmtList()

    inputMethodBody.add(quote do:
      if not `widgetIdent`.visible or not `widgetIdent`.enabled:
        return false
    )

    proc eventNameToKind(name: string): string =
      case name
      of "on_mouse_down": "evMouseDown"
      of "on_mouse_up": "evMouseUp"
      of "on_mouse_move": "evMouseMove"
      of "on_mouse_hover": "evMouseHover"
      of "on_key_down": "evKeyDown"
      of "on_key_up": "evKeyUp"
      of "on_char": "evChar"
      else: ""

    var caseStmt = nnkCaseStmt.newTree(
      nnkDotExpr.newTree(eventIdent, ident("kind"))
    )

    for handler in eventHandlers:
      if handler.kind == nnkCall and handler.len == 2:
        let handlerName = handler[0].strVal
        let handlerBody = handler[1]
        let eventKind = eventNameToKind(handlerName)

        if eventKind != "":
          var branch = nnkOfBranch.newTree(
            ident(eventKind),
            handlerBody
          )
          caseStmt.add(branch)

    caseStmt.add(nnkElse.newTree(
      quote do:
        discard
    ))

    inputMethodBody.add(caseStmt)

    inputMethodBody.add(quote do:
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

# ============================================================================
# Helper Functions
# ============================================================================

proc newWidgetId*(): WidgetId =
  ## Generate unique widget ID
  # TODO: Implement proper ID generation
  result = WidgetId(0)

proc addChild*(parent: Widget, child: Widget) =
  ## Add child to parent widget
  parent.children.add(child)
  child.parent = parent
  child.zIndex = parent.zIndex + 1
  parent.layoutDirty = true
