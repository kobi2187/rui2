## Store: named, typed state for bindings.
##
## A `Link[T]` is one value you hold in a variable. A `Store` is a bag of them
## addressed by name -- what yui calls `state`, and what a form, a settings
## page or a file loaded at runtime needs, where the widgets are described by
## data and cannot name your Nim variables:
##
## ```nim
## let store = newStore()
## let name  = store.declare("name", "")          # a Link[string]
## discard     store.declare("count", 0)
##
## store.set("count", 3)                          # by name
## echo store.get[:int]("count")
## echo store.format("Hello, {name} ({count})")   # Hello,  (3)
## ```
##
## The entries *are* Links: bind widgets to them (`label.text = name.value`). The store only
## adds the names and a text view of each value (`getText` / `setText`, for scalars) so that a name from a file can be read
## and written without knowing its type. Names are flat strings; a dotted name
## like `settings.apiKey` is just a name that contains a dot.

import std/[tables, strutils, macros]
import types, link

type
  StoreError* = object of CatchableError
    ## An unknown name, a name declared twice, or a name read as the wrong type.

  StoreEntry = ref object of RootObj
    typeName: string
    getText: proc(): string {.closure.}
    setText: proc(text: string): bool {.closure.}
    bindWidget: proc(widget: Widget, apply: proc(text: string) {.closure.}) {.closure.}

  TypedEntry[T] = ref object of StoreEntry
    link: Link[T]

proc newStore*(): Store = Store()

proc has*(store: Store, name: string): bool = name in store.entries

proc names*(store: Store): seq[string] =
  ## Every declared name, in the order they were declared.
  store.order

proc scalarText[T](value: T): string =
  when T is string: value else: $value

proc scalarParse[T](link: Link[T], text: string): bool =
  ## Set `link` from `text`; false (and unchanged) when it does not read as a T
  ## or T is not a scalar the store knows how to read.
  try:
    when T is string: link.value = text
    elif T is bool:
      case text.strip().toLowerAscii
      of "true", "yes", "on", "1": link.value = true
      of "false", "no", "off", "0": link.value = false
      else: return false
    elif T is SomeInteger: link.value = T(parseInt(text.strip()))
    elif T is SomeFloat: link.value = T(parseFloat(text.strip()))
    else: return false
    true
  except ValueError:
    false

proc declare*[T](store: Store, name: string, initial: T): Link[T] =
  ## Create the entry `name` holding `initial`, and return its Link.
  if name.len == 0: raise newException(StoreError, "a store name cannot be empty")
  if name in store.entries:
    raise newException(StoreError, "'" & name & "' is already declared")
  let link = newLink(initial)
  let entry = TypedEntry[T](link: link, typeName: $T)
  entry.getText = proc(): string = scalarText(link.value)
  entry.setText = proc(text: string): bool = scalarParse(link, text)
  entry.bindWidget = proc(widget: Widget, apply: proc(text: string) {.closure.}) =
    link.bindTo(widget, proc(v: T) = apply(scalarText(v)))
  store.entries[name] = RootRef(entry)
  store.order.add name
  link

proc entry(store: Store, name: string): StoreEntry =
  if name notin store.entries:
    raise newException(StoreError, "no store entry named '" & name & "'")
  cast[StoreEntry](store.entries[name])

proc linkFor*[T](store: Store, name: string): Link[T] =
  ## The Link behind `name`. Raises if it is not declared or holds another type.
  let e = store.entry(name)
  if not (e of TypedEntry[T]):
    raise newException(StoreError, "'" & name & "' holds a " & e.typeName &
                       ", not a " & $T)
  TypedEntry[T](e).link

proc get*[T](store: Store, name: string): T =
  let source = linkFor[T](store, name)
  source.value

proc set*[T](store: Store, name: string, value: T) =
  ## `store.set("count", 3)`: the type is the value's, so `set("n", 3)` on a
  ## float entry is an error -- write `3.0`.
  let target = linkFor[T](store, name)
  target.value = value

proc getText*(store: Store, name: string): string =
  ## The value as text: strings as they are, everything else through `$`.
  store.entry(name).getText()

proc setText*(store: Store, name: string, text: string): bool =
  ## Set a string, bool, integer or float entry from text. False when `text`
  ## does not read as that type (the value is left alone).
  store.entry(name).setText(text)

proc typeName*(store: Store, name: string): string = store.entry(name).typeName

proc bindText*(store: Store, name: string, widget: Widget,
               apply: proc(text: string) {.closure.}) =
  ## Keep `widget` in step with `name`: `apply` gets the value as text now and
  ## on every change, and the widget is repainted. The type-blind sibling of
  ## `Link.bindTo`, for a name that came from a file. Unbound when the widget
  ## is disposed.
  store.entry(name).bindWidget(widget, apply)

# ---------------------------------------------------------------------------
# Interpolation: "Hello, {name}"

type Piece = tuple[text: string, isName: bool]

proc pieces(pattern: string): seq[Piece] =
  ## Split on `{name}`. `{{` and `}}` are literal braces.
  var literal = ""
  var i = 0
  while i < pattern.len:
    let ch = pattern[i]
    if ch == '{' and i + 1 < pattern.len and pattern[i + 1] == '{':
      literal.add '{'; i += 2
    elif ch == '}' and i + 1 < pattern.len and pattern[i + 1] == '}':
      literal.add '}'; i += 2
    elif ch == '{':
      let close = pattern.find('}', i)
      if close < 0:
        raise newException(StoreError, "unclosed '{' in \"" & pattern & "\"")
      if literal.len > 0: result.add (literal, false); literal = ""
      result.add (pattern[i + 1 ..< close].strip(), true)
      i = close + 1
    else:
      literal.add ch; inc i
  if literal.len > 0: result.add (literal, false)

proc mentions*(pattern: string): seq[string] =
  ## The names a pattern refers to, in order of appearance: `"{a} and {b}"`
  ## gives `@["a", "b"]`.
  for p in pieces(pattern):
    if p.isName: result.add p.text

proc format*(store: Store, pattern: string): string =
  ## Fill `{name}` with each entry's text. An unknown name raises.
  for p in pieces(pattern):
    result.add (if p.isName: store.getText(p.text) else: p.text)

macro state*(args: varargs[untyped]): untyped =
  ## Declare an app's state in one block: a `Store` and a typed `Link` per entry,
  ## the same idea as yui's `state:`.
  ##
  ## ```nim
  ## state:
  ##   count: int = 0
  ##   name: string = ""
  ##   volume = 0.5            # the type is the value's: float
  ## ```
  ##
  ## declares `store` (the `Store`), and `count`, `name`, `volume` (the Links, also
  ## reachable by name: `store.get[:int]("count")`). `state(app):` names the Store
  ## `app` instead. Use it where `let` works -- the top of a proc or a module.
  var storeName = ident"store"
  var body: NimNode
  case args.len
  of 1: body = args[0]
  of 2: storeName = args[0]; body = args[1]
  else: error("state: expected `state:` or `state(name):` and a block", args[0])
  result = newStmtList()
  result.add quote do:
    let `storeName` = newStore()
  for entry in body:
    var name, init: NimNode
    var typ: NimNode = nil
    if entry.kind == nnkCall and entry.len == 2 and entry[1].kind == nnkStmtList and
       entry[1].len == 1 and entry[1][0].kind == nnkAsgn:
      # `count: int = 0` parses as Call(count, StmtList(Asgn(int, 0)))
      name = entry[0]; typ = entry[1][0][0]; init = entry[1][0][1]
    elif entry.kind in {nnkAsgn, nnkExprEqExpr}:
      name = entry[0]; init = entry[1]               # `count = 0`
    else:
      error("state: write `name: Type = value` or `name = value`", entry)
    let label = newLit($name)
    let value = if typ == nil: init else: newCall(typ, init)
    result.add quote do:
      let `name` = `storeName`.declare(`label`, `value`)
