## Widget DSL Helpers - Small, Composable Functions
##
## Refactored in Forth style: obvious, readable, composable
## Each function does ONE thing clearly

import macros
import strutils

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

proc isDiscardOnly(node: NimNode): bool =
  ## `discard` as the sole statement, which is how an empty DSL section is
  ## written when Nim needs a body at all.
  node.kind == nnkStmtList and node.len == 1 and node[0].kind == nnkDiscardStmt

proc isEmpty*(node: NimNode): bool =
  ## Nothing to parse: absent, an empty node, an empty list, or just `discard`.
  if node.isNil or node.kind == nnkEmpty:
    return true
  if node.kind != nnkStmtList:
    return false
  node.len == 0 or node.isDiscardOnly

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
  # DON'T use the captured ident node - create a completely fresh one
  # This prevents any symbol binding from the calling scope
  let fieldName = newIdentNode(prop.name.strVal)
  let exportedName = nnkPostfix.newTree(ident("*"), fieldName)

  # For type, also create fresh ident
  let typeNode = if prop.typ.kind == nnkIdent:
    newIdentNode(prop.typ.strVal)
  else:
    prop.typ

  nnkIdentDefs.newTree(exportedName, typeNode, prop.default)

proc genStateField*(state: StateDef): NimNode =
  ## Generate plain type field for state.
  ## Exported, like props: state is read by app code and by the scripting
  ## bridge, both of which live outside the widget's defining module.
  let fieldName = newIdentNode(state.name.strVal)
  nnkIdentDefs.newTree(
    nnkPostfix.newTree(ident("*"), fieldName),
    state.typ,
    newEmptyNode()
  )

proc actionProcType*(action: ActionDef): NimNode =
  ## `proc(x: T, y: U): R {.closure.}` for one declared action.
  ##
  ## Always closure, never nimcall: a handler that cannot capture the variable
  ## it is reporting to is not much of a handler.
  if action.params.len == 0 and action.returnType.strVal == "void":
    return nnkProcTy.newTree(
      nnkFormalParams.newTree(newEmptyNode()),
      nnkPragma.newTree(ident("closure")))

  var formalParams = nnkFormalParams.newTree(action.returnType)
  for param in action.params:
    formalParams.add(
      nnkIdentDefs.newTree(ident(param.name), param.typ, newEmptyNode()))
  nnkProcTy.newTree(formalParams, nnkPragma.newTree(ident("closure")))

proc genActionField*(action: ActionDef): NimNode =
  ## Generate the handler field for an action: a plain, nilable closure.
  ##
  ## This used to be `Option[proc(...)]`, which made every caller write
  ## `btn.onClick = some(proc() {.closure.} = ...)` -- an Option wrapper around
  ## a type that is already nilable, plus a pragma the compiler could have
  ## inferred if the Option had not been in the way. `nil` is the only "no
  ## handler" a proc needs, and with the wrapper gone a bare lambda assigns
  ## directly:
  ##
  ## ```nim
  ## btn.onClick = proc() = report("clicked")
  ## ```
  ##
  ## Exported: callers attach handlers from outside the widget's module.
  nnkIdentDefs.newTree(
    nnkPostfix.newTree(ident("*"), ident(action.name)),
    actionProcType(action),
    newEmptyNode()
  )

# ============================================================================
# Code Generation - Constructor Parameters
# ============================================================================

proc genPropParam*(prop: PropDef): NimNode =
  ## Generate constructor parameter for prop
  # Use fresh ident for parameter name to ensure hygiene
  let paramName = ident(prop.name.strVal)
  let paramType = if prop.typ.kind == nnkIdent:
    ident(prop.typ.strVal)
  else:
    prop.typ

  if prop.default.kind != nnkEmpty:
    nnkIdentDefs.newTree(paramName, paramType, prop.default)
  else:
    nnkIdentDefs.newTree(paramName, paramType, newEmptyNode())

proc genStateInit*(state: StateDef): NimNode =
  ## Generate state initialization: fieldName: default(Type)
  let initValue = quote do:
    default(`state.typ`)
  nnkExprColonExpr.newTree(state.name, initValue)

proc genActionParam*(action: ActionDef): NimNode =
  ## Constructor parameter for an action, defaulting to nil -- so
  ## `newButton(text = "Go")` compiles without naming every handler.
  nnkIdentDefs.newTree(ident(action.name), actionProcType(action), newNilLit())

proc genActionInit*(action: ActionDef): NimNode =
  ## Generate action initialization in constructor.
  ##
  ## Unused: buildConstructorBody assigns the parameter straight to the field,
  ## which is all a nilable proc needs. Kept because it is exported.
  let actionIdent = ident(action.name)
  quote do:
    `actionIdent`

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
  of "on_mouse_wheel": "evMouseWheel"
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

proc sectionEntries(body: NimNode): seq[NimNode] =
  ## The statements of a DSL section worth looking at: nothing for an absent or
  ## `discard`-only section, and `discard` lines skipped inside a real one.
  ##
  ## Every parse* below asked these three questions for itself, which is most of
  ## what put them over the complexity gate for logic that is the same in all
  ## four.
  if body.isEmpty or body.kind != nnkStmtList:
    return
  for entry in body:
    if entry.kind != nnkDiscardStmt:
      result.add(entry)

proc parseProps*(propsBody: NimNode): seq[PropDef] =
  ## Parse props section into PropDef sequence
  for prop in sectionEntries(propsBody):
    if prop.isCallWithArgs:
      result.add(makePropDef(prop))

proc parseState*(stateBody: NimNode): seq[StateDef] =
  ## Parse state section into StateDef sequence
  for stateField in sectionEntries(stateBody):
    if stateField.isCallWithArgs:
      result.add(makeStateDef(stateField))

proc parseActions*(actionsBody: NimNode): seq[ActionDef] =
  ## Parse actions section into ActionDef sequence
  for action in sectionEntries(actionsBody):
    result.add(makeActionDef(action))

proc parseEvents*(eventsBody: NimNode): seq[EventDef] =
  ## Parse events section into EventDef sequence.
  ## An `on_something:` line is a call of the handler name with its body.
  for event in sectionEntries(eventsBody):
    if event.isCallWithArgs:
      result.add(EventDef(name: event[0].strVal, body: event[1]))

# ============================================================================
# Utilities
# ============================================================================

proc makeWidgetTypeName*(name: NimNode): NimNode =
  ## Generate widget type name (e.g., Button -> Button)
  name

proc makeConstructorName*(name: NimNode): NimNode =
  ## Generate constructor name (e.g., Button -> newButton)
  ident("new" & name.strVal)

proc checkInternalFile*(name: NimNode): NimNode =
  ## Generate import statement for {name}_internal.nim if it exists
  ## Returns empty node if file doesn't exist
  let internalName = name.strVal.toLowerAscii() & "_internal"
  # Note: In real implementation, we'd check fileExists
  # For now, just generate the import - it will fail at compile time if missing
  # which is acceptable
  newEmptyNode()
