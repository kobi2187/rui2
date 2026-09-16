## `ui:` -- build a widget tree by writing its shape.
##
## ```nim
## let root = ui:
##   VStack(spacing = 10.0):
##     Label(text = "Hello")
##     Button(text = "Click")
## ```
##
## instead of
##
## ```nim
## let root = newVStack(spacing = 10.0)
## root.addChild(newLabel(text = "Hello"))
## root.addChild(newButton(text = "Click"))
## ```
##
## ## What it is, and what it deliberately is not
##
## One macro, about forty lines, for every container that exists or ever will.
## The alternative -- a template per container -- would mean the DSL generating
## a second surface alongside the constructors it already generates, and a new
## widget would not get the sugar until someone remembered to add it.
##
## It is *only* sugar. `Label(text = "x")` becomes `newLabel(text = "x")`, a
## nested body becomes `addChild` calls, and nothing else happens. Every tree
## written this way can be written with the plain constructors, which is the
## point: the macro is a convenience you can stop using in the middle of a tree
## without rewriting the rest.
##
## ## The rules, all four of them
##
## - A call whose name starts with a capital is a widget: `Foo(args)` becomes
##   `newFoo(args)`, and is added to the enclosing widget.
## - A widget call followed by an indented block takes that block as its
##   children.
## - `let name = Foo(...)` both names the widget and adds it, so a later widget
##   in the same tree can refer to it. `ui:` is an expression, so that name does
##   not escape the tree -- to reach a widget from outside, declare the variable
##   first and use `name = Foo(...)`, which also names and adds.
## - Anything else -- `for`, `if`, `while`, a bare statement -- is emitted as
##   written, with widget calls inside it added to the same enclosing widget.
##   So a loop that builds rows works, and so does an `if` that includes a
##   control conditionally.

import macros
import types

proc isWidgetCall(node: NimNode): bool =
  ## A call whose callee is a capitalised identifier. The capital is the whole
  ## test: it is the convention every widget type in the library already
  ## follows, and it keeps `echo x` or `inc count` from being mistaken for one.
  if node.kind notin {nnkCall, nnkCommand}:
    return false
  let callee = node[0]
  callee.kind == nnkIdent and callee.strVal.len > 0 and
    callee.strVal[0] in {'A' .. 'Z'}

proc constructorName(callee: NimNode): NimNode =
  ## `Label` -> `newLabel`, matching what definePrimitive generates.
  ident("new" & callee.strVal)

proc buildWidget(node: NimNode): NimNode

proc addChildrenTo(parent: NimNode, body: NimNode, dest: NimNode)
proc rewriteControlFlow(parent, stmt: NimNode): NimNode

proc buildCall(node: NimNode, body: NimNode): NimNode =
  ## `Foo(a, b)` with an optional child block, as an expression.
  let widgetSym = genSym(nskLet, "w")
  var call = newCall(constructorName(node[0]))
  for i in 1 ..< node.len:
    if node[i].kind != nnkStmtList:
      call.add(node[i])

  var stmts = newStmtList(nnkLetSection.newTree(
    newIdentDefs(widgetSym, newEmptyNode(), call)))
  if body != nil:
    addChildrenTo(widgetSym, body, stmts)
  stmts.add(widgetSym)
  nnkBlockStmt.newTree(newEmptyNode(), stmts)

proc buildWidget(node: NimNode): NimNode =
  ## The expression that creates one widget, children and all.
  var body: NimNode = nil
  if node.len > 1 and node[^1].kind == nnkStmtList:
    body = node[^1]
  buildCall(node, body)

const ControlFlow = {nnkForStmt, nnkIfStmt, nnkElifBranch, nnkElse,
                     nnkWhileStmt, nnkBlockStmt, nnkWhenStmt, nnkCaseStmt,
                     nnkOfBranch, nnkStmtList}
  ## Node kinds whose bodies are still widget context: widgets built inside a
  ## loop or a conditional belong to the same parent as the loop itself.

proc singleDefinition(stmt: NimNode): bool =
  ## `let x = ...` / `var x = ...` with exactly one binding and a value.
  stmt.kind in {nnkLetSection, nnkVarSection} and stmt.len == 1 and
    stmt[0].len == 3

proc namedWidget(stmt: NimNode): tuple[name, call: NimNode] =
  ## `let name = Foo(...)` or `name = Foo(...)`, or (nil, nil) for anything
  ## else. Both name a widget *and* add it -- the name is the reason to write
  ## it this way, not a reason to leave it out of the tree.
  if stmt.singleDefinition and stmt[0][2].isWidgetCall:
    return (stmt[0][0], stmt[0][2])
  if stmt.kind == nnkAsgn and stmt[1].isWidgetCall:
    return (stmt[0], stmt[1])
  (nil, nil)

proc addNamed(parent, stmt: NimNode, named: tuple[name, call: NimNode],
              dest: NimNode) =
  if stmt.kind == nnkAsgn:
    dest.add(nnkAsgn.newTree(named.name, buildWidget(named.call)))
  else:
    var section = copyNimTree(stmt)
    section[0][2] = buildWidget(named.call)
    dest.add(section)
  dest.add(newCall(ident("addChild"), parent, named.name))

proc addStatement(parent: NimNode, stmt: NimNode, dest: NimNode)

proc rewriteControlFlow(parent, stmt: NimNode): NimNode =
  ## Copy a control-flow node, replacing each of its bodies with the same
  ## statements in widget context.
  result = copyNimNode(stmt)
  for child in stmt:
    if child.kind == nnkStmtList:
      var inner = newStmtList()
      addChildrenTo(parent, child, inner)
      result.add(inner)
    elif child.kind in {nnkElifBranch, nnkElse, nnkOfBranch}:
      result.add(rewriteControlFlow(parent, child))
    else:
      result.add(child)

proc addStatement(parent: NimNode, stmt: NimNode, dest: NimNode) =
  ## One statement inside a widget's child block.
  if stmt.isWidgetCall:
    dest.add(newCall(ident("addChild"), parent, buildWidget(stmt)))
    return

  let named = namedWidget(stmt)
  if named.name != nil:
    addNamed(parent, stmt, named, dest)
    return

  if stmt.kind in ControlFlow:
    dest.add(rewriteControlFlow(parent, stmt))
    return

  dest.add(stmt)

proc addChildrenTo(parent: NimNode, body: NimNode, dest: NimNode) =
  for stmt in body:
    addStatement(parent, stmt, dest)

macro ui*(body: untyped): untyped =
  ## Build a widget tree. See the module comment for the four rules.
  ##
  ## The body is one widget, which may have children. Several top-level widgets
  ## would have no parent to be added to and nothing to return, so that is a
  ## compile error rather than a silent choice of the first.
  var stmts = if body.kind == nnkStmtList: body else: newStmtList(body)
  if stmts.len != 1:
    error("ui: expects exactly one root widget, got " & $stmts.len, body)
  if not stmts[0].isWidgetCall:
    error("ui: expects a widget call like VStack(spacing = 10.0), got " &
          $stmts[0].kind, stmts[0])
  buildWidget(stmts[0])
