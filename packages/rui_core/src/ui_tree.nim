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
## ## The rules, all five of them
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
## - A widget call may carry modifiers -- `Canvas().frame(height = 260)`,
##   `TextArea().flex` -- which are applied to the widget after it is built.
##   A child block after the chain belongs to the widget at its bottom:
##   `VStack(spacing = 4.0).frame(width = 200):` then the children.

## ## Spacing, size and binding sugar (the yui vocabulary)
##
## - `.margin(8)`, `.margin("8px 16px")`, `.padding(...)` put the widget in a
##   Padding and return that, so `Button().margin(8).flex` flexes the padded box.
## - `.size(120, 40)` is `.frame(width = 120, height = 40)`.
## - A property that reads `link.value` follows it: `Label(text = "Count: " &
##   $count.value)`. The widget is registered as a dependent of `count` (the Link's
##   `dependentWidgets` set), and re-evaluates the expression when `count` is set.
##   To write a widget's value back, give it a handler: `TextInput(text = name.value,
##   onChange = name.setter)`. Handlers are closures; they are not watched.
##   `items = -> source` / `rows = -> source` are the one arrow left: a LinkSeq or
##   RowSource followed edit by edit.

import macros, std/strutils
import types

proc isPlainWidgetCall(node: NimNode): bool =
  ## A call whose callee is a capitalised identifier. The capital is the whole
  ## test: it is the convention every widget type in the library already
  ## follows, and it keeps `echo x` or `inc count` from being mistaken for one.
  if node.kind notin {nnkCall, nnkCommand}:
    return false
  let callee = node[0]
  callee.kind == nnkIdent and callee.strVal.len > 0 and
    callee.strVal[0] in {'A' .. 'Z'}

proc isWidgetCall(node: NimNode): bool =
  ## A widget call, or a modifier chained onto one:
  ## `Canvas().frame(height = 260)`, `TextArea().flex`.
  if node.isPlainWidgetCall:
    return true
  if node.kind in {nnkCall, nnkCommand} and node[0].kind == nnkDotExpr:
    return node[0][0].isWidgetCall
  node.kind == nnkDotExpr and node[0].isWidgetCall

proc splitChain(node: NimNode): tuple[base: NimNode, mods: seq[NimNode]] =
  ## The plain widget call at the bottom of a modifier chain, and the
  ## modifiers applied to it, innermost first. Each modifier is kept as a call
  ## whose first argument is a placeholder, filled in by `buildWidget`.
  var n = node
  var outerFirst: seq[NimNode]
  while not n.isPlainWidgetCall:
    if n.kind == nnkDotExpr:
      outerFirst.add newCall(n[1])
      n = n[0]
    else:
      var m = newCall(n[0][1])
      for i in 1 ..< n.len:
        if n[i].kind != nnkStmtList:
          m.add n[i]
      outerFirst.add m
      n = n[0][0]
  result.base = n
  for i in countdown(outerFirst.high, 0):
    result.mods.add outerFirst[i]

proc constructorName(callee: NimNode): NimNode =
  ## `Label` -> `newLabel`, matching what definePrimitive generates.
  ident("new" & callee.strVal)

proc buildWidget(node: NimNode): NimNode

proc addChildrenTo(parent: NimNode, body: NimNode, dest: NimNode)
proc rewriteControlFlow(parent, stmt: NimNode): NimNode


# ---------------------------------------------------------------------------
# Binding: a property that reads `link.value`
# ---------------------------------------------------------------------------
#
# `Label(text = "Count: " & $count.value)` is an ordinary Nim expression. The
# macro looks for `x.value` reads in it (not inside a closure), and after the
# widget is built it
#   1. registers the widget as a dependent of each such Link
#      (`dependsOn`, which is `link.dependentWidgets.incl(widget)`), and
#   2. gives the widget a refresh step that re-evaluates the expression and
#      assigns the property (`refreshWith`).
# Setting a Link marks its dependent widgets dirty; their next layout runs the
# refresh. That is the whole mechanism. Handlers (`onClick = proc () = ...`) are
# closures and are left alone: they read and write Links when they run.
#
# `->` remains for one thing: `ListView(items -> source)` style list sources
# (`items = -> source`, `rows = -> source`), which follow a LinkSeq or RowSource
# edit by edit instead of re-copying a seq.

proc isClosure(n: NimNode): bool =
  n.kind in {nnkLambda, nnkProcDef, nnkFuncDef, nnkDo}

proc valueReads(n: NimNode, reads: var seq[NimNode]) =
  ## Every `x.value` in `n`, outside closures.
  if n.isClosure: return
  if n.kind == nnkDotExpr and n.len == 2 and n[1].kind == nnkIdent and
     n[1].strVal == "value":
    var seen = false
    for r in reads:
      if r.repr == n[0].repr: seen = true
    if not seen: reads.add n[0]
  for child in n: valueReads(child, reads)

proc isHandlerField(field: string): bool =
  field.len > 2 and field.startsWith("on") and field[2].isUpperAscii

proc arrowTarget(node: NimNode): NimNode =
  ## `-> source` (a prefix `->`): the source. nil when `node` is not one.
  if node.kind == nnkPrefix and node[0].kind == nnkIdent:
    case node[0].strVal
    of "->": return node[1]
    of "<->", "<-":
      error("ui: bindings are one-way. Read state with `.value` " &
            "(`TextInput(text = name.value, onChange = name.setter)`); " &
            "a handler writes it back", node)
    else: discard
  nil

proc bindingStatements(w: NimNode, field: string, expr: NimNode,
                       reads: seq[NimNode]): NimNode =
  ## The widget shows `expr`, now and whenever any Link it reads changes.
  result = newStmtList()
  let target = newDotExpr(w, ident(field))
  result.add newAssignment(target, expr)                      # now
  for link in reads:
    result.add newCall(ident("dependsOn"), w, link)
  let apply = newProc(newEmptyNode(), [newEmptyNode()],
                      newStmtList(newAssignment(target, expr)), nnkLambda)
  result.add newCall(ident("refreshWith"), w, apply)

proc buildCall(node: NimNode, body: NimNode): NimNode =
  ## `Foo(a, b)` with an optional child block, as an expression. The block
  ## may come from further up a modifier chain, so it is passed in rather
  ## than read off `node`.
  let widgetSym = genSym(nskLet, "w")
  var call = newCall(constructorName(node[0]))
  var reactive: seq[tuple[field: string, expr: NimNode, reads: seq[NimNode]]]
  var lists: seq[tuple[field: string, source: NimNode]]
  for i in 1 ..< node.len:
    if node[i].kind == nnkStmtList: continue
    if node[i].kind == nnkExprEqExpr:
      let field = node[i][0].strVal
      let src = node[i][1].arrowTarget
      if src != nil:
        if field notin ["items", "rows"]:
          error("ui: `->` is for list sources (items, rows). Read state with " &
                "`.value`: `" & field & " = link.value`", node[i])
        lists.add (field, src)
        continue
      var reads: seq[NimNode]
      if not field.isHandlerField: node[i][1].valueReads(reads)
      if reads.len > 0:
        reactive.add (field, node[i][1], reads)
        continue
    call.add(node[i])

  var stmts = newStmtList(nnkLetSection.newTree(
    newIdentDefs(widgetSym, newEmptyNode(), call)))
  for l in lists:
    stmts.add newCall(ident(if l.field == "items": "bindItems" else: "bindRows"),
                      widgetSym, l.source)
  for r in reactive:
    stmts.add bindingStatements(widgetSym, r.field, r.expr, r.reads)
  if body != nil:
    addChildrenTo(widgetSym, body, stmts)
  stmts.add(widgetSym)
  nnkBlockStmt.newTree(newEmptyNode(), stmts)

proc buildWidget(node: NimNode): NimNode =
  ## The expression that creates one widget, children and all, with any
  ## modifiers applied. A child block is written after the whole chain but
  ## belongs to the widget at its bottom.
  var body: NimNode = nil
  if node.kind != nnkDotExpr and node.len > 1 and node[^1].kind == nnkStmtList:
    body = node[^1]
  let chain = splitChain(node)
  if chain.mods.len == 0:
    return buildCall(chain.base, body)
  # Each modifier's result feeds the next: most return the widget they were
  # given, but `margin` and `padding` return the wrapper they put around it.
  var current = genSym(nskLet, "m")
  var stmts = newStmtList(nnkLetSection.newTree(
    newIdentDefs(current, newEmptyNode(), buildCall(chain.base, body))))
  for m in chain.mods:
    var call = newCall(m[0], current)
    for i in 1 ..< m.len:
      call.add m[i]
    current = genSym(nskLet, "m")
    stmts.add nnkLetSection.newTree(newIdentDefs(current, newEmptyNode(), call))
  stmts.add current
  nnkBlockStmt.newTree(newEmptyNode(), stmts)

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
