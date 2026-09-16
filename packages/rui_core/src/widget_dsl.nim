## Widget DSL v3 - Refactored with Forth-Style Functions
##
## Clean, readable, composable macro implementation
## Each function does ONE thing clearly

import macros
import std/strutils
export strutils  # generated code uses toLowerAscii / cmpIgnoreStyle
import types
import link
import widget_dsl_helpers
import script_bridge

export types
export link
export script_bridge  # generated descriptors name ScriptDescriptor / scriptField

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

proc seedingPropFor(stateName: string, propNames: seq[string]): string =
  ## The prop that seeds a state field, under the convention the whole widget
  ## library follows: a prop named `initialFoo` seeds the state field `foo`
  ## (Checkbox's `initialChecked` -> `checked`, ProgressBar's `initialValue` ->
  ## `value`). "" when the widget declares no such prop.
  ##
  ## Compared with cmpIgnoreStyle, so `initialchecked` and `initial_checked`
  ## work as well as `initialChecked`.
  let seedName = "initial" & stateName[0..0].toUpperAscii() & stateName[1..^1]
  for pn in propNames:
    if cmpIgnoreStyle(pn, seedName) == 0:
      return pn
  ""

proc stateInitNode(state: StateDef, propNames: seq[string]): NimNode =
  ## `result.foo = initialFoo`, or `result.foo = default(T)` when nothing
  ## seeds it. Before the seeding lookup existed every state field was
  ## unconditionally set to default(T), so the initialX props were silently
  ## ignored and a checkbox built with initialChecked = true still rendered
  ## unchecked.
  let stateName = state.name.strVal
  let lhs = newDotExpr(ident("result"), ident(stateName))
  let seedProp = seedingPropFor(stateName, propNames)
  if seedProp.len > 0:
    return nnkAsgn.newTree(lhs, ident(seedProp))
  let stateType = if state.typ.kind == nnkIdent: ident(state.typ.strVal)
                  else: state.typ
  nnkAsgn.newTree(lhs, newCall(ident("default"), stateType))

proc initSectionNode(initBody: NimNode): NimNode =
  ## The `init:` section, wrapped so its `widget` means the object under
  ## construction.
  ##
  ## This was parsed into WidgetSections.initBody and then used by nothing, so
  ## every init block in the library was dead code. MenuBar's set
  ## activeMenuIndex and hoverIndex to -1 and hasOverlay to true; without it
  ## running they stayed at 0 and false, so a fresh MenuBar believed menu 0 was
  ## open and its dropdowns did not sort above their siblings.
  ##
  ## Built by hand rather than with `quote do`, because quote gensyms its
  ## locals: a quoted `let widget = result` binds to a fresh symbol and the
  ## user's `widget` in the init body would not see it.
  nnkBlockStmt.newTree(
    newEmptyNode(),
    newStmtList(
      nnkLetSection.newTree(
        newIdentDefs(ident("widget"), newEmptyNode(), ident("result"))),
      initBody))

proc buildConstructorBody(name: NimNode, sections: WidgetSections): NimNode =
  ## Build constructor body: allocate, then props, state, actions, init --
  ## in that order, so `init:` can correct or extend anything the seeding
  ## convention has set.
  result = newStmtList()
  let typeName = makeWidgetTypeName(name)

  result.add nnkAsgn.newTree(ident("result"), newCall(typeName))
  result.add newCall(ident("initWidgetBase"), ident("result"))

  var propNames: seq[string] = @[]
  for prop in sections.props:
    let propName = prop.name.strVal
    propNames.add(propName)
    result.add nnkAsgn.newTree(
      newDotExpr(ident("result"), ident(propName)), ident(propName))

  for state in sections.state:
    result.add stateInitNode(state, propNames)

  for action in sections.actions:
    result.add nnkAsgn.newTree(
      newDotExpr(ident("result"), ident(action.name)), ident(action.name))

  if not sections.initBody.isEmpty:
    result.add initSectionNode(sections.initBody)

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

proc buildEventHandler(name: NimNode, sections: WidgetSections): NimNode =
  ## Generate handleInput method with event routing
  if sections.events.len == 0:
    return newEmptyNode()

  let typeName = makeWidgetTypeName(name)
  var caseStmt = nnkCaseStmt.newTree(nnkDotExpr.newTree(ident("event"), ident("kind")))

  for event in sections.events:
    caseStmt.add(genEventCase(event))

  # Add else branch
  caseStmt.add nnkElse.newTree(quote do: return false)

  # Build method manually to have proper widget type
  let widgetParam = newIdentDefs(ident("widget"), typeName)
  let eventParam = newIdentDefs(ident("event"), ident("GuiEvent"))
  let formalParams = nnkFormalParams.newTree(ident("bool"), widgetParam, eventParam)

  nnkMethodDef.newTree(
    nnkPostfix.newTree(ident("*"), ident("handleInput")),
    newEmptyNode(),
    newEmptyNode(),
    formalParams,
    newEmptyNode(),
    newEmptyNode(),
    caseStmt
  )

proc buildGetTypeNameMethod(name: NimNode): NimNode =
  ## Generate getTypeName method that returns the widget type name
  let typeName = makeWidgetTypeName(name)
  let typeNameStr = $name  # Convert widget name to string

  quote do:
    method getTypeName*(widget: `typeName`): string =
      `typeNameStr`

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
  ## Generate the `layout` method for composite widgets.
  ## NOTE: this used to emit a method named `updateLayout`, which nothing ever
  ## called -- main_loop.layoutPass() dispatches on `layout`. The result was
  ## that no container ever positioned its children.
  if sections.layoutBody.isEmpty:
    return newEmptyNode()

  # Build method manually to avoid premature symbol resolution
  let typeName = makeWidgetTypeName(name)
  let widgetParam = newIdentDefs(ident("widget"), typeName)
  let formalParams = nnkFormalParams.newTree(newEmptyNode(), widgetParam)

  nnkMethodDef.newTree(
    nnkPostfix.newTree(ident("*"), ident("layout")),
    newEmptyNode(),
    newEmptyNode(),
    formalParams,
    newEmptyNode(),  # No pragma needed
    newEmptyNode(),
    sections.layoutBody
  )

# ============================================================================
# Scripting Method Generation
#
# Every widget defined through the DSL gets a generic scripting bridge for
# free, so the file-based script protocol can read and drive any widget
# without per-widget boilerplate. Previously only Button and TextInput had
# hand-written implementations and everything else answered
# "Action not supported".
# ============================================================================

proc buildScriptStateMethod(name: NimNode, sections: WidgetSections): NimNode =
  ## Generate getScriptableState: base widget fields plus every prop and state
  ## field that json can represent.
  let typeName = makeWidgetTypeName(name)
  let typeNameStr = $name

  # Built with newCall, not `quote do`: quote gensyms the `result` it sees, so
  # a quoted `result[key] = ...` would assign into a fresh local rather than
  # the method's own result. The `when compiles` guards live in reportField for
  # the same reason they left buildScriptActionMethod -- a `when` inside a
  # quote still counts as a branch of the macro that quotes it.
  var body = newStmtList()
  body.add nnkAsgn.newTree(
    ident("result"),
    newCall(ident("baseScriptableState"), ident("widget"), newLit(typeNameStr)))

  var fieldNames: seq[string] = @[]
  for prop in sections.props:
    fieldNames.add(prop.name.strVal)
  for st in sections.state:
    fieldNames.add(st.name.strVal)

  for fname in fieldNames:
    body.add newCall(ident("reportField"), ident("result"), ident("widget"),
                     newLit(fname),
                     newDotExpr(ident("widget"), ident(fname)))

  let widgetParam = newIdentDefs(ident("widget"), typeName)
  let formalParams = nnkFormalParams.newTree(ident("JsonNode"), widgetParam)
  nnkMethodDef.newTree(
    nnkPostfix.newTree(ident("*"), ident("getScriptableState")),
    newEmptyNode(), newEmptyNode(), formalParams,
    newEmptyNode(), newEmptyNode(), body
  )

proc scriptFieldNode(typeName: NimNode, fieldName: string): NimNode =
  ## `scriptField("foo", proc(w, v) = assignField(T(w).foo, v))`, as AST.
  let fIdent = ident(fieldName)
  quote do:
    scriptField(`fieldName`, proc (w: Widget, v: JsonNode): bool {.closure.} =
      assignField(`typeName`(w).`fIdent`, v))

proc actionAliases(actionName: string): NimNode =
  ## The names a script may call an action by: its own, lowercased, plus the
  ## same with a leading `on` removed -- which is why `click` reaches `onClick`.
  result = nnkBracket.newTree(newLit(actionName.toLowerAscii()))
  if actionName.len > 2 and actionName[0..1] == "on":
    result.add(newLit(actionName[2..^1].toLowerAscii()))

proc scriptActionNode(typeName: NimNode, action: ActionDef,
                      firstState: string): NimNode =
  ## An action takes either nothing or the widget's own first state field --
  ## which a preceding `write` has usually just set.
  let aliases = actionAliases(action.name)
  let aIdent = ident(action.name)
  if action.params.len == 0:
    quote do:
      scriptAction(@`aliases`, proc (w: Widget): bool {.closure.} =
        fireAction(`typeName`(w).`aIdent`))
  else:
    let sIdent = ident(firstState)
    quote do:
      scriptAction(@`aliases`, proc (w: Widget): bool {.closure.} =
        fireAction(`typeName`(w).`aIdent`, `typeName`(w).`sIdent`))

proc writableFieldNames(sections: WidgetSections):
    tuple[writable: seq[string], default, firstState: string] =
  ## Which fields a script may write, which one a bare `write <value>` means,
  ## and which one a one-argument action is fired against.
  ##
  ## Every state field is writable. A `text` prop is writable too, and when it
  ## exists it is the default target: `write hello` on a TextInput should mean
  ## its text, not whichever state field happens to be declared first.
  for st in sections.state:
    if result.firstState.len == 0:
      result.firstState = st.name.strVal
    result.writable.add(st.name.strVal)
  result.default = result.firstState

  for prop in sections.props:
    if prop.name.strVal == "text":
      result.writable.add("text")
      result.default = "text"
      break

proc buildScriptActionMethod(name: NimNode, sections: WidgetSections): NimNode =
  ## Emit a ScriptDescriptor for this widget, plus a one-line
  ## handleScriptAction that hands it to the runtime dispatcher.
  ##
  ## This used to generate the whole verb interpreter -- read, gettext, write,
  ## invoke, toggle, per-action aliases, disabled checks and every error shape
  ## -- into each of the 47 widget types: 203 lines of `quote do` at cc=43,
  ## against a repo whose next-worst routine was 16. The behaviour is
  ## identical and now lives once, as ordinary code, in script_bridge.nim.
  ##
  ## What is emitted here is data: field names paired with setters, action
  ## names paired with invokers. A hand-written widget builds the same value
  ## by hand and gets the same scripting support, with no macro involved.
  let typeName = makeWidgetTypeName(name)
  let names = writableFieldNames(sections)

  var fields = nnkBracket.newTree()
  for fname in names.writable:
    fields.add(scriptFieldNode(typeName, fname))

  var actions = nnkBracket.newTree()
  for a in sections.actions:
    actions.add(scriptActionNode(typeName, a, names.firstState))

  let defaultField = names.default

  let descName = ident($name & "ScriptDescriptor")
  let typeLit = newLit($name)
  let defaultLit = newLit(defaultField)
  result = newStmtList()
  result.add quote do:
    let `descName`* = ScriptDescriptor(
      typeName: `typeLit`,
      fields: @`fields`,
      actions: @`actions`,
      defaultField: `defaultLit`,
      getText: (proc (w: Widget): string {.closure.} = textOrEmpty(`typeName`(w))),
      toggle: (proc (w: Widget): Option[bool] {.closure.} =
                 flipIfCheckable(`typeName`(w))))

  # Built with newCall rather than `quote do`, because `params` and `body` are
  # names in std/macros: inside a quote they bind to the NimNode accessors
  # rather than to this method's own parameters.
  let formalParams = nnkFormalParams.newTree(
    ident("JsonNode"),
    newIdentDefs(ident("widget"), typeName),
    newIdentDefs(ident("action"), ident("string")),
    newIdentDefs(ident("params"), ident("JsonNode")))
  let methodBody = newStmtList(
    newCall(ident("dispatchScriptAction"),
            ident("widget"), descName, ident("action"), ident("params")))
  result.add nnkMethodDef.newTree(
    nnkPostfix.newTree(ident("*"), ident("handleScriptAction")),
    newEmptyNode(), newEmptyNode(), formalParams,
    newEmptyNode(), newEmptyNode(), methodBody)


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
  # Primitives may also declare a `layout:` section -- a leaf still needs to be
  # able to size itself to its content (a Label measuring its own text, say).
  # buildUpdateLayoutMethod returns an empty node when there is no such section.
  result.add(buildUpdateLayoutMethod(name, sections))
  result.add(buildRenderMethod(name, sections))
  result.add(buildEventHandler(name, sections))
  result.add(buildGetTypeNameMethod(name))  # Auto-generate type name
  result.add(buildScriptStateMethod(name, sections))   # Scripting bridge
  result.add(buildScriptActionMethod(name, sections))  # Scripting bridge

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
  result.add(buildEventHandler(name, sections))
  result.add(buildGetTypeNameMethod(name))              # Auto-generate type name
  result.add(buildScriptStateMethod(name, sections))    # Scripting bridge
  result.add(buildScriptActionMethod(name, sections))   # Scripting bridge

# ============================================================================
# Utilities
# ============================================================================

proc addChild*(parent: Widget, child: Widget) =
  ## Add child widget to parent.
  ##
  ## Bumps the tree's structure version so anything caching a walk of the tree
  ## -- the focus chain -- knows to rebuild. Without it a widget added after the
  ## first Tab press was unreachable by keyboard forever.
  parent.children.add(child)
  child.parent = parent
  noteStructureChanged()

  # A new child has no bounds yet, so the parent needs laying out. This also
  # keeps the frame's post-layout work reachable: the hit-test rebuild and the
  # stringId re-registration are gated on layout having run, so a widget added
  # without this would be invisible to clicks and to scripting selectors.
  parent.layoutDirty = true
  parent.isDirty = true
