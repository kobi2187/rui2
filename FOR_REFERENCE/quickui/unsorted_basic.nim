# types.nim
type
  StateKey*[T] = distinct string

  WidgetKind* = enum
    wkButton, wkLabel, wkPanel, wkContainer

  Point* = object
    x*, y*: float32

  Size* = object
    width*, height*: float32

  Rect* = object
    pos*: Point
    size*: Size

  Widget* = ref object of RootObj
    id*: string
    rect*: Rect
    visible*: bool
    layout*: Option[Layout]
    style*: Option[Style]
    children*: seq[Widget]

  Color* = object
    r*, g*, b*, a*: uint8

  ThemeColors* = object
    background*: Color
    text*: Color
    primary*: Color
    secondary*: Color
    accent*: Color
    disabled*: Color

  ThemeSpacing* = object
    small*: Size
    medium*: Size
    large*: Size

  FontWeight* = enum
    Regular, Bold, Light

  FontStyle* = object
    size*: float32
    family*: string
    weight*: FontWeight

  ThemeTypography* = object
    body*: FontStyle
    header*: FontStyle
    caption*: FontStyle

  Theme* = ref object
    colors*: ThemeColors
    spacing*: ThemeSpacing
    typography*: ThemeTypography

# naylib_widgets.nim
# Abstractions over raygui primitives
import naylib

type
  NWidget* = object  # Base widget drawing functionality
    rect*: Rect
    enabled*: bool
    focused*: bool

proc button*(nw: NWidget, text: string): bool =
  ## Returns true if button was clicked
  let r = Rectangle(
    x: nw.rect.pos.x,
    y: nw.rect.pos.y,
    width: nw.rect.size.width,
    height: nw.rect.size.height
  )
  result = GuiButton(r, text.cstring)

proc label*(nw: NWidget, text: string) =
  GuiLabel(Rectangle(
    x: nw.rect.pos.x,
    y: nw.rect.pos.y,
    width: nw.rect.size.width,
    height: nw.rect.size.height
  ), text.cstring)

proc textBox*(nw: NWidget, text: var string, maxLength: int, editMode: bool): bool =
  var buffer: array[256, char]
  copyMem(addr buffer[0], text.cstring, min(text.len, maxLength))
  result = GuiTextBox(
    Rectangle(
      x: nw.rect.pos.x,
      y: nw.rect.pos.y,
      width: nw.rect.size.width,
      height: nw.rect.size.height
    ),
    addr buffer[0],
    maxLength,
    editMode
  )
  if result:
    text = $addr buffer[0]

# state.nim
import tables, hashes

type
  State* = ref object
    data: TableRef[string, RootRef]

proc newState*(): State =
  State(data: newTable[string, RootRef]())

proc hash*(key: StateKey): Hash = hash(string(key))

proc `$`*(key: StateKey): string = string(key)

proc set*[T](state: State, key: StateKey[T], value: T) =
  # Store value wrapped in RootRef
  state.data[$key] = cast[RootRef](value)

proc get*[T](state: State, key: StateKey[T]): T =
  # Retrieve and cast back to original type
  cast[T](state.data[$key])

# widgets.nim
import macros
import types, naylib_widgets

macro defineWidget*(name: untyped, body: untyped): untyped =
  # Cleaner widget definition macro
  result = newStmtList()

  var props = newNimNode(nnkRecList)
  var renderBody: NimNode

  for section in body:
    case section[0].strVal
    of "props":
      for prop in section[1]:
        props.add(prop)
    of "render":
      renderBody = section[1]

  let typeName = ident($name)

  # Generate widget type
  result.add quote do:
    type `typeName` = ref object of Widget
      `props`

  # Generate render method with NWidget abstraction
  let renderProc = newProc(
    name = ident("render"),
    params = [newEmptyNode(), newIdentDefs(ident("widget"), typeName)],
    body = quote do:
      let nw = NWidget(rect: widget.rect, enabled: widget.visible)
      `renderBody`
  )
  result.add renderProc

# Example usage showing improved syntax
defineWidget Button:
  props:
    text: string
    onClick: proc()

  render:
    if nw.button(widget.text):
      widget.onClick()

defineWidget TextInput:
  props:
    text: string
    onChange: proc(newText: string)
    maxLength: int = 100

  render:
    var currentText = widget.text
    if nw.textBox(currentText, widget.maxLength, true):
      widget.onChange(currentText)

# Example of state usage
let countKey = StateKey[int]("count")
let textKey = StateKey[string]("inputText")

let state = newState()
state.set(countKey, 0)
state.set(textKey, "")

# Main app setup
let button = Button(
  rect: Rect(pos: Point(x: 10, y: 10), size: Size(width: 100, height: 30)),
  text: "Click me",
  onClick: proc() =
    let count = state.get(countKey)
    state.set(countKey, count + 1)
)
