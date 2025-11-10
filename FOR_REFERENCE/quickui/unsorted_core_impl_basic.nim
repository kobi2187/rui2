# Core Types
type
  Widget = ref object
    id: string
    x, y: float32
    width, height: float32
    visible: bool
    layout: Option[Layout]
    style: Style
    children: seq[Widget]

  Theme = ref object
    colors: ThemeColors
    spacing: ThemeSpacing
    typography: ThemeTypography

  ThemeColors = object
    background: Color
    text: Color
    primary: Color
    secondary: Color
    accent: Color
    disabled: Color

  ThemeSpacing = object
    small: Point
    medium: Point
    large: Point

  ThemeTypography = object
    body: FontStyle
    header: FontStyle
    caption: FontStyle

  Point = tuple[x, y: float32]

  Layout = object
    case kind: LayoutKind
    of lkFlow: flowConfig: FlowLayout
    of lkGrid: gridConfig: GridLayout
    of lkStack: stackConfig: StackLayout

# Widget Definition System
macro defineWidget*(name: untyped, body: untyped): untyped =
  # Parse the widget definition and generate the necessary types and procs
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
  
  # Generate the widget type
  let typeName = ident($name)
  result.add quote do:
    type `typeName` = ref object of Widget
      `props`

  # Generate the render method
  let renderProc = newProc(
    name = ident("render"),
    params = [newEmptyNode(), newIdentDefs(ident("widget"), typeName)],
    body = renderBody
  )
  result.add renderProc

# Theme System
macro defineTheme*(name: untyped, body: untyped): untyped =
  result = newStmtList()
  
  var themeObj = quote do:
    Theme(
      colors: ThemeColors(),
      spacing: ThemeSpacing(),
      typography: ThemeTypography()
    )
  
  for section in body:
    case section[0].strVal
    of "colors", "spacing", "typography":
      processThemeSection(themeObj, section)
  
  result.add quote do:
    let `name` = `themeObj`

proc processThemeSection(themeObj: var NimNode, section: NimNode) =
  for property in section[1]:
    let name = property[0]
    let value = property[1]
    themeObj.add(
      newColonExpr(
        newDotExpr(ident(section[0].strVal), name),
        value
      )
    )

# Layout System
type
  LayoutKind = enum
    lkFlow, lkGrid, lkStack

  FlowDirection = enum
    Horizontal, Vertical

  Alignment = enum
    Start, Center, End, SpaceBetween, SpaceAround

  FlowLayout = object
    direction: FlowDirection
    spacing: Point
    align: Alignment

  GridLayout = object
    columns: int
    rowGap: float32
    columnGap: float32
    align: Alignment

  StackLayout = object
    align: Alignment

proc arrangeChildren(widget: Widget) =
  if widget.layout.isNone: return
  let layout = widget.layout.get

  case layout.kind
  of lkFlow:
    var curX = widget.x
    var curY = widget.y
    let config = layout.flowConfig

    for child in widget.children:
      child.x = curX
      child.y = curY
      
      case config.direction
      of Horizontal:
        curX += child.width + config.spacing.x
      of Vertical:
        curY += child.height + config.spacing.y

  of lkGrid:
    let config = layout.gridConfig
    var row = 0
    var col = 0
    let cellWidth = widget.width / config.columns.float32

    for child in widget.children:
      child.x = widget.x + (col.float32 * (cellWidth + config.columnGap))
      child.y = widget.y + (row.float32 * (child.height + config.rowGap))
      
      inc col
      if col >= config.columns:
        col = 0
        inc row

  of lkStack:
    for child in widget.children:
      child.x = widget.x
      child.y = widget.y

# State Management
type State = object
  data: Table[string, any]

var state {.threadvar.}: State

proc set*[T](s: var State, key: string, value: T) =
  s.data[key] = value

proc get*[T](s: State, key: string): T =
  s.data[key].T

# Example Usage
defineWidget Button:
  props:
    text: string
    onClick: proc()
  
  render:
    if GuiButton(Rectangle(x: widget.x, y: widget.y, 
                          width: widget.width, height: widget.height),
                 widget.text):
      widget.onClick()

defineTheme LightTheme:
  colors:
    background: Color(r: 255, g: 255, b: 255, a: 255)
    text: Color(r: 0, g: 0, b: 0, a: 255)
    primary: Color(r: 0, g: 122, b: 255, a: 255)
  spacing:
    small: (x: 4.0, y: 4.0)
    medium: (x: 8.0, y: 8.0)
    large: (x: 16.0, y: 16.0)
  typography:
    body: FontStyle(size: 16, family: "Arial", weight: Regular)
    header: FontStyle(size: 24, family: "Arial", weight: Bold)