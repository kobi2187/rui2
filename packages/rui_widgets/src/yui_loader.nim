## loadYui: build a widget tree from a `.yui` file (github.com/kobi2187/yui).
##
## ```nim
## let store = newStore()
## var actions: YuiActions
## actions["save/0"] = proc (args: JsonNode) = echo "saved ", store.get[string]("name")
## let doc = loadYui("app.yui", store, actions)
## for w in doc.warnings: stderr.writeLine w
## let app = newApp(doc.title, doc.width, doc.height)
## app.setRootWidget(doc.root)
## ```
##
## Nothing here is per-widget: elements are found in the yui table
## (`yui_names`), built and filled in through the widget registry
## (`widget_registry`), and `state:` is a `Store` whose names `bind`,
## `"{name}"` and `visible: "{!name}"` refer to.
##
## A document that is not YAML, or has no `view:`, raises `YuiLoadError`. A
## problem with one element or property -- an unknown element, a value that
## does not fit, an action nobody registered -- is a *warning* with the path to
## it (`view[1].children[0]`), and the rest of the tree still loads: a typo
## should cost one widget, not the screen. Features the loader does not map
## (themes, fonts, `$token` references) are reported, never silently dropped.

import std/[json, options, strutils, tables, os, editdistance, sequtils, sugar]
import yaml
import yaml/tojson
import rui_core
import layout/boxes
import layout/flex
import containers/tabcontrol

type
  YuiLoadError* = object of CatchableError

  YuiActions* = Table[string, YuiHandler]
    ## Handlers by the name a document uses: `save/0`.

  YuiDoc* = ref object
    root*: Widget
    title*: string
    width*, height*: int          ## 0: the document does not say
    themePath*: string            ## `import_theme:`, for the host to load
    store*: Store
    declaredActions*: seq[string] ## the `actions:` list
    warnings*: seq[string]

  Loader = object
    doc: YuiDoc
    actions: YuiActions

  Hooks = Table[string, seq[YuiHandler]]

const
  # yui's spelling -> rui2's
  propAliases = {"min": "minValue", "max": "maxValue",
                 "dividerPosition": "initialRatio", "options": "items",
                 "multiline": "multiline"}.toTable
  unmappedStyle = ["theme", "font", "color", "backgroundColor", "background",
                   "border", "shrink", "wrap"]
  contentProps = ["text", "title", "caption", "label"]
  boundFields = ["checked", "value", "text"]

proc warn(c: var Loader, path, message: string) =
  c.doc.warnings.add path & ": " & message

func isTruthy(text: string): bool =
  text.strip().toLowerAscii in ["true", "1", "yes", "on"]

func argText(arg: JsonNode): string =
  if arg.kind == JString: arg.getStr() else: $arg

proc suggest(name: string, allowed: seq[string]): string =
  var best = ""
  var bestDist = 3
  for a in allowed:
    let d = editDistanceAscii(name.toLowerAscii, a.toLowerAscii)
    if d < bestDist: best = a; bestDist = d
  if best.len > 0: " (did you mean '" & best & "'?)" else: ""

proc firstProp(bp: WidgetBlueprint, names: openArray[string]): string =
  for n in names:
    if bp.findProp(n) >= 0: return n

proc addHook(hooks: var Hooks, action: string, handler: YuiHandler) =
  hooks.mgetOrPut(action, @[]).add handler

# ---------------------------------------------------------------------------
# state, actions

proc declareState(c: var Loader, node: JsonNode) =
  if node.isNil or node.kind == JNull: return
  if node.kind != JObject:
    c.warn("state", "expected a mapping of names to values")
    return
  for name, value in node:
    if c.doc.store.has(name): continue    # the host declared it first
    case value.kind
    of JBool: discard c.doc.store.declare(name, value.getBool())
    of JInt: discard c.doc.store.declare(name, value.getInt())
    of JFloat: discard c.doc.store.declare(name, value.getFloat())
    of JString: discard c.doc.store.declare(name, value.getStr())
    else: c.warn("state." & name, "lists and objects are not supported yet; '" &
                 name & "' is not declared")

proc handlerFor(c: var Loader, spec, path: string): Option[YuiHandler] =
  let action = parseYuiAction(spec)
  if action.isNone:
    c.warn(path, "'" & spec & "' is not an action (write name/arity, e.g. save/0)")
    return none(YuiHandler)
  let key = formatYuiAction(action.get)
  if key in c.actions: return some(c.actions[key])
  for registered, handler in c.actions:
    if registered.startsWith(action.get.name & "/"):
      c.warn(path, "action '" & key & "' is registered as '" & registered &
             "': arity differs")
      return some(handler)
  c.warn(path, "no handler registered for action '" & key & "'")
  none(YuiHandler)

# ---------------------------------------------------------------------------
# bindings and interpolation

proc setFrom(bp: WidgetBlueprint, w: Widget, field: string, text: string) =
  discard bp.setProp(w, field, %text)

proc namesDeclared(c: var Loader, names: seq[string], path: string): bool =
  result = true
  for n in names:
    if not c.doc.store.has(n):
      c.warn(path, "'" & n & "' is not declared in state:")
      result = false

proc flagOf(pattern: string): Option[tuple[name: string, negated: bool]] =
  ## `"{busy}"` or `"{!busy}"`: the whole string is one (possibly negated) name.
  let t = pattern.strip()
  if t.len > 2 and t[0] == '{' and t[^1] == '}' and t.count('{') == 1:
    var name = t[1 ..< t.len - 1].strip()
    let negated = name.startsWith("!")
    if negated: name = name[1 .. ^1].strip()
    return some((name, negated))

proc bindFlag(c: var Loader, w: Widget, flag: tuple[name: string, negated: bool],
              path: string, apply: proc (on: bool) {.closure.}) =
  if not c.namesDeclared(@[flag.name], path): return
  let negated = flag.negated
  c.doc.store.bindText(flag.name, w, proc (text: string) =
    apply(text.isTruthy != negated))

proc bindPattern(c: var Loader, w: Widget, bp: WidgetBlueprint, field, pattern,
                 path: string) =
  ## `"Hello, {name}"` pushed into `field`, kept current; `"{!flag}"` pushes
  ## the (negated) truth of one name.
  let store = c.doc.store
  let flag = flagOf(pattern)
  if flag.isSome and flag.get.negated:
    c.bindFlag(w, flag.get, path, proc (on: bool) = discard bp.setProp(w, field, %on))
    return
  var names: seq[string]
  try: names = mentions(pattern)
  except StoreError as e:
    c.warn(path, e.msg); return
  if names.len == 0 or not c.namesDeclared(names, path): return
  for n in names:
    store.bindText(n, w, proc (text: string) =
      discard bp.setProp(w, field, %store.format(pattern)))

proc changeHook(field: string): string =
  case field
  of "checked": "onToggle"
  else: "onChange"

proc bindState(c: var Loader, w: Widget, bp: WidgetBlueprint,
               binding: YuiBinding, hooks: var Hooks, path: string) =
  let field = bp.firstProp(boundFields)
  if field.len == 0:
    c.warn(path, "this widget has nothing to bind (no checked, value or text)")
    return
  let store = c.doc.store
  if not c.namesDeclared(@[binding.path], path): return
  if binding.direction in {bindTwoWay, bindToWidget}:
    store.bindText(binding.path, w, proc (text: string) = bp.setFrom(w, field, text))
  if binding.direction in {bindTwoWay, bindToState}:
    let name = binding.path
    hooks.addHook(changeHook(field), proc (args: JsonNode) =
      if args.len > 0: discard store.setText(name, argText(args[0])))

proc bindingOf(key: string, value: JsonNode): Option[YuiBinding] =
  ## `bind: "<-> x"` and the README's bare `bind <-> x`, which reads as a key
  ## with no value.
  if key == "bind" and value.kind == JString: return parseYuiBind(value.getStr())
  if key.startsWith("bind ") and value.kind == JNull:
    return parseYuiBind(key[5 .. ^1])

# ---------------------------------------------------------------------------
# properties

proc setNumberOrStyle(c: var Loader, w: Widget, bp: WidgetBlueprint, key: string,
                      value: JsonNode, path: string): bool =
  ## width, height, size, grow, align, justify, spacing: the layout words.
  result = true
  case key
  of "width", "height":
    let dim = parseYuiDim(argText(value))
    if dim.isNone: c.warn(path, "not a size: " & $value)
    elif dim.get.kind == dimFixed:
      if key == "width": discard w.frame(width = dim.get.px)
      else: discard w.frame(height = dim.get.px)
    elif dim.get.kind == dimFill: discard w.flex()
  of "size":
    let parts = argText(value).toLowerAscii.split('x')
    let wd = if parts.len == 2: parseYuiDim(parts[0]) else: none(YuiDim)
    let ht = if parts.len == 2: parseYuiDim(parts[1]) else: none(YuiDim)
    if wd.isSome and ht.isSome and wd.get.kind == dimFixed and ht.get.kind == dimFixed:
      discard w.size(wd.get.px, ht.get.px)
    else: c.warn(path, "size wants WxH, like 120x40")
  of "grow":
    let g = parseYuiGrow(argText(value))
    if g.isSome: discard w.flex(g.get) else: c.warn(path, "not a grow value: " & $value)
  of "align", "justify":
    let prop = if key == "align": "crossAxisAlignment" else: "mainAxisAlignment"
    let name = if key == "align": parseAlign(argText(value)).map(a => $a)
               else: parseJustify(argText(value)).map(a => $a)
    if bp.findProp(prop) < 0: c.warn(path, "'" & key & "' does not apply here")
    elif name.isNone or not bp.setProp(w, prop, %name.get):
      c.warn(path, "not a valid " & key & ": " & $value)
  else: result = false

proc setGenericProp(c: var Loader, w: Widget, bp: WidgetBlueprint, key: string,
                    value: JsonNode, path: string) =
  let name = propAliases.getOrDefault(key, key)
  if bp.findProp(name) < 0:
    c.warn(path, "unknown property '" & key & "' for " & bp.typeName &
           suggest(key, bp.propNames))
  elif value.kind == JString and value.getStr().startsWith("$"):
    c.warn(path, "theme token " & value.getStr() & " is not supported (themes: #46)")
  elif value.kind == JString and '{' in value.getStr():
    c.bindPattern(w, bp, name, value.getStr(), path)
  elif not bp.setProp(w, name, value):
    c.warn(path, "'" & argText(value) & "' does not fit " & key)

# ---------------------------------------------------------------------------
# elements

proc buildElement(c: var Loader, node: JsonNode, path: string): Widget

proc buildChildren(c: var Loader, parent: Widget, children: JsonNode, path: string) =
  if children.kind != JArray:
    c.warn(path, "children must be a list"); return
  for i in 0 ..< children.len:
    let item = children[i]
    let child = c.buildElement(item, path & "[" & $i & "]")
    if child != nil: parent.addChild(child)

proc buildTabs(c: var Loader, tabs: Widget, bp: WidgetBlueprint,
               children: JsonNode, path: string) =
  ## Each `tab "Title"` child is a page; several children make a Column.
  var titles: seq[string]
  for i in 0 ..< children.len:
    let item = children[i]
    let p = path & "[" & $i & "]"
    var title = "Tab " & $(i + 1)
    var body = item
    var key = ""
    if item.kind == JObject and item.len == 1:
      for k, v in item: key = k; body = v
    elif item.kind == JString: key = item.getStr()
    let parsed = parseYuiKey(key)
    if parsed.kind == "tab":
      if parsed.content.len > 0: title = parsed.content
      let page = newColumn()
      if body.kind == JObject and "children" in body:
        c.buildChildren(page, body["children"], p & ".children")
      let content = if page.children.len == 1: page.children[0] else: Widget(page)
      if page.children.len == 1: page.removeChild(content)
      tabs.addChild(content)
    else:
      let page = c.buildElement(item, p)
      if page != nil:
        if parsed.content.len > 0: title = parsed.content
        tabs.addChild(page)
    titles.add title
  discard bp.setProp(tabs, "tabs", %titles)

proc applyBody(c: var Loader, w: Widget, bp: WidgetBlueprint,
               key: YuiKey, body: JsonNode, path: string): Widget =
  ## Returns the widget to put in the parent: `w`, or a margin/padding box
  ## around it.
  var hooks: Hooks
  var marginCss, paddingCss = ""
  if body.kind == JObject:
    for k, v in body:
      let p = path & "." & k
      let binding = bindingOf(k, v)
      if binding.isSome: c.bindState(w, bp, binding.get, hooks, p)
      elif k == "bind": c.warn(p, "bind wants '<-> name', '-> name' or '<- name'")
      elif k == "children": discard   # after the props, so the parent is set up
      elif k == "id": w.stringId = argText(v)
      elif k in ["visible", "enabled"]:
        if v.kind == JBool:
          if k == "visible": w.visible = v.getBool()
          else: w.enabled = v.getBool()
        elif v.kind == JString and flagOf(v.getStr()).isSome:
          let target = k
          c.bindFlag(w, flagOf(v.getStr()).get, p, proc (on: bool) =
            if target == "visible": w.visible = on else: w.enabled = on)
        else: c.warn(p, "visible/enabled want true, false or \"{name}\"")
      elif k.startsWith("on_"):
        let event = ruiEventName(k)
        let action = bp.findAction(event)
        if action < 0:
          c.warn(p, bp.typeName & " has no '" & k & "' event")
        elif v.kind == JString:
          let h = c.handlerFor(v.getStr(), p)
          if h.isSome: hooks.addHook(bp.actions[action].name, h.get)
      elif k == "margin": marginCss = argText(v)
      elif k == "padding":
        if bp.findProp("padding") >= 0 and bp.setProp(w, "padding", v): discard
        else: paddingCss = argText(v)
      elif k == "spacing" and key.kind == "grid":
        discard bp.setProp(w, "crossAxisSpacing", (if v.kind == JArray and v.len > 0: v[0] else: v))
        discard bp.setProp(w, "mainAxisSpacing", (if v.kind == JArray and v.len > 1: v[1] else: (if v.kind == JArray: v[0] else: v)))
      elif k in unmappedStyle:
        c.warn(p, "'" & k & "' is not mapped: themes are global (#46)")
      elif c.setNumberOrStyle(w, bp, k, v, p): discard
      else: c.setGenericProp(w, bp, k, v, p)
  # attach handlers (several sources can share one action)
  for action, list in hooks:
    let handlers = list
    discard bp.attach(w, action, proc (args: JsonNode) =
      for h in handlers: h(args))
  # container children
  if body.kind == JObject and "children" in body:
    if bp.typeName == "TabControl":
      c.buildTabs(w, bp, body["children"], path & ".children")
    else:
      c.buildChildren(w, body["children"], path & ".children")
  # wrappers last, so they hold the finished widget
  result = w
  if paddingCss.len > 0 or marginCss.len > 0:
    try:
      if paddingCss.len > 0: result = Widget(result.padding(paddingCss))
      if marginCss.len > 0: result = Widget(result.margin(marginCss))
    except ValueError as e:
      c.warn(path, e.msg)

proc applyKey(c: var Loader, w: Widget, bp: WidgetBlueprint, key: YuiKey,
              path: string) =
  if key.content.len > 0:
    let field = bp.firstProp(contentProps)
    if key.kind == "pane":
      discard bp.setProp(w, "axis", %key.content)
    elif field.len == 0:
      c.warn(path, "'" & key.kind & "' takes no text: \"" & key.content & "\"")
    elif '{' in key.content:
      c.bindPattern(w, bp, field, key.content, path)
    else:
      discard bp.setProp(w, field, %key.content)
  if key.hasSize:
    if key.kind == "grid":
      discard bp.setProp(w, "crossAxisCount", %int(key.width))
    else: discard w.size(key.width, key.height)

proc buildElement(c: var Loader, node: JsonNode, path: string): Widget =
  var keyText = ""
  var body: JsonNode = newJNull()
  if node.kind == JString: keyText = node.getStr()
  elif node.kind == JObject and node.len == 1:
    for k, v in node: keyText = k; body = v
  else:
    c.warn(path, "an element is one key (`button \"OK\": {...}`) or a bare string")
    return nil
  let key = parseYuiKey(keyText)
  let widgetName = widgetFor(key.kind)
  if widgetName.isNone:
    let row = yuiElement(key.kind)
    c.warn(path, if row.isSome and row.get.kind == mapGap:
                   "'" & key.kind & "' has no rui2 widget yet"
                 else: "unknown element '" & key.kind & "'")
    return nil
  let bpOpt = blueprintFor(widgetName.get)
  if bpOpt.isNone:
    c.warn(path, widgetName.get & " is not registered"); return nil
  let bp = bpOpt.get
  let w = bp.create()
  c.applyKey(w, bp, key, path)
  result = c.applyBody(w, bp, key, body, path)

# ---------------------------------------------------------------------------
# document

proc loadYuiText*(text: string, store: Store = nil,
                  actions: YuiActions = initTable[string, YuiHandler](),
                  origin = "yui"): YuiDoc =
  ## Build the tree described by `text`. `store` receives the document's
  ## `state:` (names it already holds keep their values); a new one is made
  ## when none is given and is on the result either way.
  var c = Loader(doc: YuiDoc(store: if store.isNil: newStore() else: store),
                 actions: actions)
  result = c.doc
  var docs: seq[JsonNode]
  try: docs = loadToJson(text)
  except CatchableError as e:
    raise newException(YuiLoadError, origin & ": " & e.msg)
  if docs.len == 0 or docs[0].kind != JObject:
    raise newException(YuiLoadError, origin & ": expected a mapping at the top level")
  let top = docs[0]
  if "app" in top:
    let app = top["app"]
    if app.kind == JString: result.title = app.getStr()
    elif app.kind == JObject:
      result.title = app{"title"}.getStr()
      result.width = app{"width"}.getInt()
      result.height = app{"height"}.getInt()
      let size = app{"size"}.getStr().split('x')
      if size.len == 2:
        try:
          result.width = parseInt(size[0]); result.height = parseInt(size[1])
        except ValueError: c.warn("app.size", "wants WxH, like 800x600")
  result.themePath = top{"import_theme"}.getStr()
  c.declareState(top{"state"})
  if "actions" in top and top["actions"].kind == JArray:
    for a in top["actions"]:
      let parsed = parseYuiAction(a.getStr())
      if parsed.isNone: c.warn("actions", "'" & a.getStr() & "' is not name/arity")
      else:
        result.declaredActions.add formatYuiAction(parsed.get)
        if formatYuiAction(parsed.get) notin actions:
          c.warn("actions", "declared action '" & formatYuiAction(parsed.get) &
                 "' has no handler")
  if "view" notin top:
    raise newException(YuiLoadError, origin & ": no view: section")
  let view = top["view"]
  let items = if view.kind == JArray: view else: %[view]
  var built: seq[Widget]
  for i in 0 ..< items.len:
    let item = items[i]
    let w = c.buildElement(item, "view[" & $i & "]")
    if w != nil: built.add w
  if built.len == 0:
    raise newException(YuiLoadError, origin & ": nothing in view: could be built")
  if built.len == 1: result.root = built[0]
  else:
    let column = newColumn()
    for w in built: column.addChild(w)
    result.root = column
  if result.width == 0: result.width = 800
  if result.height == 0: result.height = 600

proc loadYui*(path: string, store: Store = nil,
              actions: YuiActions = initTable[string, YuiHandler]()): YuiDoc =
  ## `loadYuiText` for a file. Raises `YuiLoadError` when it cannot be read.
  var text: string
  try: text = readFile(path)
  except IOError as e: raise newException(YuiLoadError, path & ": " & e.msg)
  loadYuiText(text, store, actions, path)
