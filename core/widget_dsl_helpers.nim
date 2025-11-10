## Widget DSL Helpers - Small, Composable Functions
##
## Refactored in Forth style: obvious, readable, composable
## Each function does ONE thing clearly

import macros

# ============================================================================
# Type Definitions
# ============================================================================

type
  PropDef* = object
    name*: NimNode
    typ*: NimNode
    default*: NimNode

  StateDef* = object
    name*: NimNode
    typ*: NimNode

  ActionDef* = object
    name*: string
    params*: seq[tuple[name: string, typ: NimNode]]
    returnType*: NimNode

  EventDef* = object
    name*: string
    body*: NimNode

# ============================================================================
# AST Helpers - Predicates
# ============================================================================

proc isEmpty*(node: NimNode): bool =
  ## Check if node is empty or just contains discard
  node.isNil or
  node.kind == nnkEmpty or
  (node.kind == nnkStmtList and node.len == 0) or
  (node.kind == nnkStmtList and node.len == 1 and node[0].kind == nnkDiscardStmt)

proc isCallWithArgs*(node: NimNode): bool =
  ## Check if node is a call with arguments
  node.kind == nnkCall and node.len == 2

proc isObjConstr*(node: NimNode): bool =
  ## Check if node is an object constructor (for parameterized actions)
  node.kind == nnkObjConstr

proc isAssignment*(node: NimNode): bool =
  ## Check if node is an assignment (for defaults)
  node.kind == nnkAsgn

# ============================================================================
# Field Extraction - Props
# ============================================================================

proc extractFieldName*(prop: NimNode): NimNode =
  ## Extract field name from property declaration
  if prop.isCallWithArgs:
    prop[0]
  else:
    error("Invalid property syntax", prop)
    ident("error")

proc extractFieldType*(prop: NimNode): NimNode =
  ## Extract field type from property declaration
  if not prop.isCallWithArgs:
    error("Invalid property syntax", prop)
    return ident("error")

  if prop[1].kind == nnkStmtList and prop[1].len > 0:
    let firstChild = prop[1][0]
    if firstChild.isAssignment:
      firstChild[0]  # Type from assignment
    else:
      firstChild     # Just type
  else:
    prop[1]

proc extractDefaultValue*(prop: NimNode): NimNode =
  ## Extract default value from property (or empty)
  if not prop.isCallWithArgs:
    return newEmptyNode()

  if prop[1].kind == nnkStmtList and prop[1].len > 0:
    let firstChild = prop[1][0]
    if firstChild.isAssignment:
      firstChild[1]  # Default value
    else:
      newEmptyNode()
  else:
    newEmptyNode()

proc makePropDef*(prop: NimNode): PropDef =
  ## Create PropDef from AST node
  PropDef(
    name: extractFieldName(prop),
    typ: extractFieldType(prop),
    default: extractDefaultValue(prop)
  )

# ============================================================================
# Field Extraction - State
# ============================================================================

proc makeStateDef*(stateField: NimNode): StateDef =
  ## Create StateDef from AST node
  if not stateField.isCallWithArgs:
    error("Invalid state syntax", stateField)
    return StateDef(name: ident("error"), typ: ident("error"))

  let fieldName = stateField[0]
  let fieldType = if stateField[1].kind == nnkStmtList and stateField[1].len > 0:
                    stateField[1][0]
                  else:
                    stateField[1]

  StateDef(name: fieldName, typ: fieldType)

# ============================================================================
# Field Extraction - Actions
# ============================================================================

proc extractActionParams*(action: NimNode): seq[tuple[name: string, typ: NimNode]] =
  ## Extract parameters from ObjConstr action node
  result = @[]
  if not action.isObjConstr:
    return

  for i in 1 ..< action.len:
    if action[i].kind == nnkExprColonExpr:
      result.add((action[i][0].strVal, action[i][1]))

proc makeActionDef*(action: NimNode): ActionDef =
  ## Create ActionDef from AST node
  var actionName: string
  var params: seq[tuple[name: string, typ: NimNode]] = @[]
  var returnType = ident("void")

  case action.kind
  of nnkCall:
    # No parameters: onClick()
    actionName = action[0].strVal

  of nnkObjConstr:
    # With parameters: onChange(value: string)
    actionName = action[0].strVal
    params = extractActionParams(action)

  of nnkInfix:
    # With return type: onClick() -> bool
    if action[0].strVal == "->":
      let callNode = action[1]
      returnType = action[2]

      if callNode.kind == nnkCall:
        actionName = callNode[0].strVal
      elif callNode.isObjConstr:
        actionName = callNode[0].strVal
        params = extractActionParams(callNode)
      else:
        error("Invalid action syntax", action)
    else:
      error("Invalid action syntax", action)

  else:
    error("Invalid action syntax", action)

  ActionDef(name: actionName, params: params, returnType: returnType)

# ============================================================================
# Code Generation - Fields
# ============================================================================

proc genPropField*(prop: PropDef): NimNode =
  ## Generate exported field definition for prop
  let exportedName = nnkPostfix.newTree(ident("*"), prop.name)
  nnkIdentDefs.newTree(exportedName, prop.typ, prop.default)

proc genStateField*(state: StateDef): NimNode =
  ## Generate Link[T] wrapped field for state
  let linkType = nnkBracketExpr.newTree(ident("Link"), state.typ)
  nnkIdentDefs.newTree(state.name, linkType, newEmptyNode())

proc genActionField*(action: ActionDef): NimNode =
  ## Generate Option[proc(...)] field for action
  var procType: NimNode

  if action.params.len == 0 and action.returnType.strVal == "void":
    # Simple: proc()
    procType = nnkProcTy.newTree(
      nnkFormalParams.newTree(newEmptyNode()),
      newEmptyNode()
    )
  else:
    # With params/return: proc(x: T, y: U): R
    var formalParams = nnkFormalParams.newTree(action.returnType)
    for param in action.params:
      formalParams.add(
        nnkIdentDefs.newTree(ident(param.name), param.typ, newEmptyNode())
      )
    procType = nnkProcTy.newTree(formalParams, newEmptyNode())

  let optionType = nnkBracketExpr.newTree(ident("Option"), procType)
  nnkIdentDefs.newTree(ident(action.name), optionType, newEmptyNode())

# ============================================================================
# Code Generation - Constructor Parameters
# ============================================================================

proc genPropParam*(prop: PropDef): NimNode =
  ## Generate constructor parameter for prop
  if prop.default.kind != nnkEmpty:
    nnkIdentDefs.newTree(prop.name, prop.typ, prop.default)
  else:
    nnkIdentDefs.newTree(prop.name, prop.typ, newEmptyNode())

proc genStateInit*(state: StateDef): NimNode =
  ## Generate state initialization: fieldName: newLink(default)
  let initValue = quote do:
    newLink(default(`state.typ`))
  nnkExprColonExpr.newTree(state.name, initValue)

proc genActionParam*(action: ActionDef): NimNode =
  ## Generate constructor parameter for action with nil default
  let actionIdent = ident(action.name)
  var procType: NimNode

  if action.params.len == 0 and action.returnType.strVal == "void":
    procType = nnkProcTy.newTree(
      nnkFormalParams.newTree(newEmptyNode()),
      newEmptyNode()
    )
  else:
    var formalParams = nnkFormalParams.newTree(action.returnType)
    for param in action.params:
      formalParams.add(
        nnkIdentDefs.newTree(ident(param.name), param.typ, newEmptyNode())
      )
    procType = nnkProcTy.newTree(formalParams, newEmptyNode())

  let optionType = nnkBracketExpr.newTree(ident("Option"), procType)
  nnkIdentDefs.newTree(actionIdent, optionType, ident("none"))

proc genActionInit*(action: ActionDef): NimNode =
  ## Generate action initialization in constructor
  quote do:
    if `ident(action.name)`.isSome:
      some(`ident(action.name)`.get())
    else:
      none(type(`ident(action.name)`.get()))

# ============================================================================
# Event Handling
# ============================================================================

proc eventNameToKind*(eventName: string): string =
  ## Map event name to EventKind enum
  case eventName
  of "on_mouse_down": "evMouseDown"
  of "on_mouse_up": "evMouseUp"
  of "on_mouse_move": "evMouseMove"
  of "on_mouse_hover": "evMouseHover"
  of "on_key_down": "evKeyDown"
  of "on_key_up": "evKeyUp"
  of "on_char": "evChar"
  else: ""

proc genEventCase*(event: EventDef): NimNode =
  ## Generate case branch for event handler
  let eventKind = eventNameToKind(event.name)
  if eventKind.len == 0:
    error("Unknown event: " & event.name)
    return newEmptyNode()

  nnkOfBranch.newTree(
    ident(eventKind),
    event.body
  )

# ============================================================================
# Parsing - Collect Definitions
# ============================================================================

proc parseProps*(propsBody: NimNode): seq[PropDef] =
  ## Parse props section into PropDef sequence
  result = @[]
  if propsBody.isEmpty:
    return

  if propsBody.kind != nnkStmtList:
    return

  for prop in propsBody:
    if prop.kind == nnkDiscardStmt:
      continue
    if prop.isCallWithArgs:
      result.add(makePropDef(prop))

proc parseState*(stateBody: NimNode): seq[StateDef] =
  ## Parse state section into StateDef sequence
  result = @[]
  if stateBody.isEmpty:
    return

  if stateBody.kind != nnkStmtList:
    return

  for stateField in stateBody:
    if stateField.kind == nnkDiscardStmt:
      continue
    if stateField.isCallWithArgs:
      result.add(makeStateDef(stateField))

proc parseActions*(actionsBody: NimNode): seq[ActionDef] =
  ## Parse actions section into ActionDef sequence
  result = @[]
  if actionsBody.isEmpty:
    return

  if actionsBody.kind != nnkStmtList:
    return

  for action in actionsBody:
    if action.kind == nnkDiscardStmt:
      continue
    result.add(makeActionDef(action))

proc parseEvents*(eventsBody: NimNode): seq[EventDef] =
  ## Parse events section into EventDef sequence
  result = @[]
  if eventsBody.isEmpty:
    return

  if eventsBody.kind != nnkStmtList:
    return

  var i = 0
  while i < eventsBody.len:
    let event = eventsBody[i]
    if event.kind == nnkDiscardStmt:
      inc i
      continue

    if event.kind == nnkCall and event.len == 2:
      let eventName = event[0].strVal
      let eventBody = event[1]
      result.add(EventDef(name: eventName, body: eventBody))
    inc i

# ============================================================================
# Utilities
# ============================================================================

proc makeWidgetTypeName*(name: untyped): NimNode =
  ## Generate widget type name (e.g., Button -> Button)
  name

proc makeConstructorName*(name: untyped): NimNode =
  ## Generate constructor name (e.g., Button -> newButton)
  ident("new" & name.strVal)

proc checkInternalFile*(name: untyped): NimNode =
  ## Generate import statement for {name}_internal.nim if it exists
  ## Returns empty node if file doesn't exist
  let internalName = name.strVal.toLowerAscii() & "_internal"
  # Note: In real implementation, we'd check fileExists
  # For now, just generate the import - it will fail at compile time if missing
  # which is acceptable
  newEmptyNode()
