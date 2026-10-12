## Widgets by name: construct one, set its props from JSON, attach handlers.
##
## `definePrimitive` / `defineWidget` register every widget they define, so a
## program that only has a *name* and some values -- a .yui file, a script, a
## test -- can build the widget without a line of per-widget code:
##
## ```nim
## let bp = blueprintFor("Slider").get
## let slider = bp.create()
## discard bp.setProp(slider, "max", %100)
## bp.attach(slider, "onChange", proc (args: JsonNode) = echo args)
## ```
##
## Names are matched ignoring case and underscores, so `checkbox`,
## `Checkbox` and `check_box` all find the same entry.
##
## Values arrive as JSON (or YAML read as JSON) and are coerced to the field's
## type by `yuiAssign`: numbers may carry a `px` suffix, enums are read by name,
## a `seq[string]` by a list, a Color by `#rgb` / `#rrggbb` / `#rrggbbaa`.

import std/[json, options, strutils, tables]
import raylib
import types, script_bridge

type
  YuiHandler* = proc (args: JsonNode) {.closure.}
    ## What a loaded document attaches to an action: the action's arguments,
    ## as a JSON array, in declaration order.

  BlueprintAction* = object
    name*: string          ## as the widget declares it: `onClick`
    arity*: int            ## number of arguments the widget passes
    attach*: proc (widget: Widget, handler: YuiHandler) {.closure.}

  WidgetBlueprint* = object
    typeName*: string
    create*: proc (): Widget {.closure.}
    props*: seq[ScriptField]       ## every prop and state field, writable
    actions*: seq[BlueprintAction]

var blueprints {.threadvar.}: Table[string, WidgetBlueprint]

func normalised(name: string): string =
  name.toLowerAscii().replace("_", "")

proc registerWidget*(bp: WidgetBlueprint) =
  blueprints[normalised(bp.typeName)] = bp

proc blueprintFor*(typeName: string): Option[WidgetBlueprint] =
  let key = normalised(typeName)
  if key in blueprints: some(blueprints[key]) else: none(WidgetBlueprint)

proc registerVariant*(typeName, base: string, create: proc (): Widget {.closure.}) =
  ## `typeName` is `base` made differently: Label and TextInput are TextArea
  ## with some flags, Row and Column are Flex with an axis. Same props and
  ## actions, its own constructor. `base` must already be registered.
  var bp = blueprints[normalised(base)]
  bp.typeName = typeName
  bp.create = create
  registerWidget(bp)

proc registeredWidgets*(): seq[string] =
  ## The type names, as each widget spells its own.
  for bp in blueprints.values: result.add bp.typeName

proc newWidgetByName*(typeName: string): Option[Widget] =
  let bp = blueprintFor(typeName)
  if bp.isNone: none(Widget) else: some(bp.get.create())

proc propNames*(bp: WidgetBlueprint): seq[string] =
  for f in bp.props: result.add f.name

proc findProp*(bp: WidgetBlueprint, name: string): int =
  for i, f in bp.props:
    if cmpIgnoreStyle(f.name, name) == 0: return i
  -1

proc findAction*(bp: WidgetBlueprint, name: string): int =
  ## `onClick`, `click` and `on_click` all name the same action.
  let wanted = name.toLowerAscii().replace("_", "")
  for i, a in bp.actions:
    let own = a.name.toLowerAscii()
    if own == wanted or (own.len > 2 and own[0..1] == "on" and own[2..^1] == wanted):
      return i
  -1

proc setProp*(bp: WidgetBlueprint, widget: Widget, name: string,
              value: JsonNode): bool =
  ## False when the widget has no such prop or the value does not fit it.
  let i = bp.findProp(name)
  i >= 0 and bp.props[i].assign(widget, value)

proc attach*(bp: WidgetBlueprint, widget: Widget, action: string,
             handler: YuiHandler): bool =
  let i = bp.findAction(action)
  if i < 0: return false
  bp.actions[i].attach(widget, handler)
  true

# ---------------------------------------------------------------------------
# Value coercion
# ---------------------------------------------------------------------------

proc withoutPx*(node: JsonNode): JsonNode =
  ## `"16px"` reads as 16. Anything else comes back unchanged.
  if node.kind == JString:
    let s = node.getStr().strip()
    if s.endsWith("px"):
      try: return %parseFloat(s[0 ..< s.len - 2])
      except ValueError: discard
  node

proc parseHexColor*(text: string): Option[Color] =
  ## "#rgb", "#rrggbb" or "#rrggbbaa", with or without the '#'.
  var t = text.strip()
  if t.startsWith("#"): t = t[1 .. ^1]
  if t.len notin [3, 6, 8]: return none(Color)
  if t.len == 3:
    var wide = ""
    for ch in t: wide.add ch; wide.add ch
    t = wide
  try:
    let r = parseHexInt(t[0 .. 1])
    let g = parseHexInt(t[2 .. 3])
    let b = parseHexInt(t[4 .. 5])
    let a = if t.len == 8: parseHexInt(t[6 .. 7]) else: 255
    some(Color(r: uint8(r), g: uint8(g), b: uint8(b), a: uint8(a)))
  except ValueError:
    none(Color)

proc parseEnumName*[T: enum](text: string, dst: var T): bool =
  ## Style-insensitive: `Primary`, `primary` and `PRIMARY` agree.
  for e in T:
    if cmpIgnoreStyle($e, text.strip()) == 0:
      dst = e
      return true
  false

proc textList(node: JsonNode, dst: var seq[string]): bool =
  if node.kind != JArray: return false
  dst = @[]
  for item in node: dst.add item.getStr($item)
  true

template yuiAssign*(dst: untyped, node: JsonNode): bool =
  ## `scriptAssign` plus the shapes a document needs: `px` suffixes, enums by
  ## name, lists of strings and colours.
  when dst is enum:
    node.kind == JString and parseEnumName(node.getStr(), dst)
  elif dst is seq[string]:
    textList(node, dst)
  elif dst is Color:
    node.kind == JString and (block:
      let c = parseHexColor(node.getStr())
      if c.isSome: dst = c.get
      c.isSome)
  elif dst is SomeFloat or dst is SomeInteger:
    scriptAssign(dst, withoutPx(node))
  else:
    when compiles(scriptAssign(dst, node)): scriptAssign(dst, node) else: false

template argJson*(x: untyped): JsonNode =
  ## An action argument as JSON: scalars as themselves, anything else as its
  ## `$` (or null). Deliberately not `when compiles(%x)`: probing json's generic
  ## `%` with an arbitrary type can leave a half-built instantiation behind.
  when x is bool or x is SomeInteger or x is SomeFloat or x is string or x is enum:
    %x
  elif compiles($x): %($x)
  else: newJNull()

proc jsonArgs*(args: varargs[JsonNode]): JsonNode =
  ## The array a handler receives.
  result = newJArray()
  for a in args: result.add a
