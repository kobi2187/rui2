## Widget DSL v3 - Refactored with Forth-Style Functions
##
## Clean, readable, composable macro implementation
## Each function does ONE thing clearly

import macros
import types
import link
import widget_dsl_helpers

export types
export link

# ============================================================================
# Section Parsing - Collect All Definitions
# ============================================================================

type WidgetSections = object
  props: seq[PropDef]
  state: seq[StateDef]
  actions: seq[ActionDef]
  events: seq[EventDef]
  renderBody: NimNode
  layoutBody: NimNode
  initBody: NimNode

proc findSection(body: NimNode, name: string): NimNode =
  ## Find section by name in body
  for section in body:
    if section.kind == nnkCall and section[0].strVal == name:
      return section[1]
  newEmptyNode()

proc parseSections(body: NimNode): WidgetSections =
  ## Parse all sections from widget body
  result.props = parseProps(body.findSection("props"))
  result.state = parseState(body.findSection("state"))
  result.actions = parseActions(body.findSection("actions"))
  result.events = parseEvents(body.findSection("events"))
  result.renderBody = body.findSection("render")
  result.layoutBody = body.findSection("layout")
  result.initBody = body.findSection("init")

# ============================================================================
# Type Generation - Build Widget Type
# ============================================================================

proc buildPropsRecList(props: seq[PropDef]): NimNode =
  ## Build record list for props
  result = newNimNode(nnkRecList)
  for prop in props:
    result.add(genPropField(prop))

proc buildStateRecList(states: seq[StateDef]): NimNode =
  ## Build record list for state
  result = newNimNode(nnkRecList)
  for state in states:
    result.add(genStateField(state))

proc buildActionsRecList(actions: seq[ActionDef]): NimNode =
  ## Build record list for actions
  result = newNimNode(nnkRecList)
  for action in actions:
    result.add(genActionField(action))

proc buildWidgetType(name: NimNode, sections: WidgetSections): NimNode =
  ## Generate widget type definition
  let typeName = makeWidgetTypeName(name)
  let propsRec = buildPropsRecList(sections.props)
  let stateRec = buildStateRecList(sections.state)
  let actionsRec = buildActionsRecList(sections.actions)

  # Combine all fields
  var allFields = newNimNode(nnkRecList)
  for field in propsRec:
    allFields.add(field)
  for field in stateRec:
    allFields.add(field)
  for field in actionsRec:
    allFields.add(field)

  # Generate type definition manually (can't splice RecList in quote)
  let exportedTypeName = nnkPostfix.newTree(ident("*"), typeName)
  let objTy = nnkObjectTy.newTree(
    newEmptyNode(),
    nnkOfInherit.newTree(ident("Widget")),
    allFields
  )
  let refTy = nnkRefTy.newTree(objTy)

  result = nnkTypeSection.newTree(
    nnkTypeDef.newTree(exportedTypeName, newEmptyNode(), refTy)
  )

# ============================================================================
# Constructor Generation - Build newWidget() Proc
# ============================================================================

proc buildConstructorParams(sections: WidgetSections): seq[NimNode] =
  ## Build parameter list for constructor
  result = @[]

  # Add prop parameters
  for prop in sections.props:
    result.add(genPropParam(prop))

  # Add action parameters (with none defaults)
  for action in sections.actions:
    result.add(genActionParam(action))

proc buildConstructorBody(name: NimNode, sections: WidgetSections): NimNode =
  ## Build constructor body - initialize all fields
  result = newStmtList()

  let typeName = makeWidgetTypeName(name)

  # Create object
  result.add quote do:
    result = `typeName`()

  # Initialize props (direct assignment from parameters)
  for prop in sections.props:
    # Create fresh idents from string values to avoid symbol binding issues
    let propNameIdent = ident(prop.name.strVal)
    let assignStmt = nnkAsgn.newTree(
      nnkDotExpr.newTree(ident("result"), propNameIdent),
      propNameIdent
    )
    result.add(assignStmt)

  # Initialize state (plain types, Link only for explicit store bindings)
  for state in sections.state:
    # Create fresh idents from string values
    let stateNameIdent = ident(state.name.strVal)
    let stateTypeIdent = if state.typ.kind == nnkIdent:
      ident(state.typ.strVal)
    else:
      state.typ
    result.add quote do:
      result.`stateNameIdent` = default(`stateTypeIdent`)

  # Initialize actions (wrap in Option)
  for action in sections.actions:
    let actionName = ident(action.name)
    result.add quote do:
      result.`actionName` = if `actionName`.isSome: `actionName` else: none(type(`actionName`))

proc buildConstructor(name: NimNode, sections: WidgetSections): NimNode =
  ## Generate constructor procedure
  let constructorName = makeConstructorName(name)
  let typeName = makeWidgetTypeName(name)
  let params = buildConstructorParams(sections)
  let body = buildConstructorBody(name, sections)

  # Build parameter list
  var formalParams = nnkFormalParams.newTree(typeName)
  for param in params:
    formalParams.add(param)

  # Generate proc
  nnkProcDef.newTree(
    nnkPostfix.newTree(ident("*"), constructorName),
    newEmptyNode(),
    newEmptyNode(),
    formalParams,
    newEmptyNode(),
    newEmptyNode(),
    body
  )

# ============================================================================
# Event Handler Generation
# ============================================================================

proc buildEventHandler(sections: WidgetSections): NimNode =
  ## Generate handleInput method with event routing
  if sections.events.len == 0:
    return newEmptyNode()

  var caseStmt = nnkCaseStmt.newTree(nnkDotExpr.newTree(ident("event"), ident("kind")))

  for event in sections.events:
    caseStmt.add(genEventCase(event))

  # Add else branch
  caseStmt.add nnkElse.newTree(quote do: return false)

  quote do:
    method handleInput*(widget: Widget, event: GuiEvent): bool {.base.} =
      `caseStmt`

# ============================================================================
# Render Method Generation
# ============================================================================

proc buildRenderMethod(name: NimNode, sections: WidgetSections): NimNode =
  ## Generate render method
  if sections.renderBody.isEmpty:
    return newEmptyNode()

  # Build method manually to avoid premature symbol resolution in quote
  let typeName = makeWidgetTypeName(name)
  let widgetParam = newIdentDefs(ident("widget"), typeName)
  let formalParams = nnkFormalParams.newTree(newEmptyNode(), widgetParam)

  nnkMethodDef.newTree(
    nnkPostfix.newTree(ident("*"), ident("render")),
    newEmptyNode(),  # term rewriting macros
    newEmptyNode(),  # generic params
    formalParams,
    newEmptyNode(),  # No pragma needed
    newEmptyNode(),  # reserved
    sections.renderBody
  )

proc buildUpdateLayoutMethod(name: NimNode, sections: WidgetSections): NimNode =
  ## Generate updateLayout method for composite widgets
  if sections.layoutBody.isEmpty:
    return newEmptyNode()

  # Build method manually to avoid premature symbol resolution
  let typeName = makeWidgetTypeName(name)
  let widgetParam = newIdentDefs(ident("widget"), typeName)
  let formalParams = nnkFormalParams.newTree(newEmptyNode(), widgetParam)

  nnkMethodDef.newTree(
    nnkPostfix.newTree(ident("*"), ident("updateLayout")),
    newEmptyNode(),
    newEmptyNode(),
    formalParams,
    newEmptyNode(),  # No pragma needed
    newEmptyNode(),
    sections.layoutBody
  )

# ============================================================================
# Main Macro - definePrimitive
# ============================================================================

macro definePrimitive*(name: untyped, body: untyped): untyped =
  ## Define a primitive widget - clean, composable implementation
  result = newStmtList()

  # Parse all sections
  let sections = parseSections(body)

  # Generate type
  result.add(buildWidgetType(name, sections))

  # Generate constructor
  result.add(buildConstructor(name, sections))

  # Generate methods
  result.add(buildRenderMethod(name, sections))
  result.add(buildEventHandler(sections))

# ============================================================================
# Main Macro - defineWidget
# ============================================================================

macro defineWidget*(name: untyped, body: untyped): untyped =
  ## Define a composite widget - clean, composable implementation
  result = newStmtList()

  # Parse all sections
  let sections = parseSections(body)

  # Generate type
  result.add(buildWidgetType(name, sections))

  # Generate constructor
  result.add(buildConstructor(name, sections))

  # Generate methods
  result.add(buildUpdateLayoutMethod(name, sections))  # Layout required for composites
  result.add(buildRenderMethod(name, sections))        # Render optional
  result.add(buildEventHandler(sections))

# ============================================================================
# Utilities
# ============================================================================

var widgetIdCounter {.compileTime.} = 0

proc newWidgetId*(): WidgetId =
  ## Generate unique widget ID
  result = WidgetId(widgetIdCounter)
  inc widgetIdCounter

proc addChild*(parent: Widget, child: Widget) =
  ## Add child widget to parent
  parent.children.add(child)
  child.parent = parent
