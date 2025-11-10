# types.nim
type
  Point* = object
    x*, y*: float32

  Size* = object
    width*, height*: float32

  Rect* = object
    pos*: Point
    size*: Size

  Color* = object
    r*, g*, b*, a*: uint8

  Widget* = ref object of RootObj
    id*: string
    rect*: Rect
    visible*: bool
    parent*: Widget
    children*: seq[Widget]

proc newPoint*(x, y: float32): Point =
  Point(x: x, y: y)

proc newSize*(width, height: float32): Size =
  Size(width: width, height: height)

proc newRect*(x, y, width, height: float32): Rect =
  Rect(
    pos: newPoint(x, y),
    size: newSize(width, height)
  )

# widgets.nim
import types, macros

type
  WidgetKind* = enum
    wkContainer, wkButton, wkLabel, wkPanel
    # Add more as needed

  RenderContext* = object
    # Will contain rendering state

method render*(widget: Widget, ctx: RenderContext) {.base.} =
  # Base render method
  discard

method update*(widget: Widget) {.base.} =
  # Base update method
  discard

proc addChild*(parent: Widget, child: Widget) =
  child.parent = parent
  parent.children.add(child)

macro defineWidget*(name: untyped, body: untyped): untyped =
  # Widget definition macro
  result = newStmtList()
  
  var props = newNimNode(nnkRecList)
  var renderBody: NimNode
  var updateBody: NimNode
  
  for section in body:
    case section[0].strVal
    of "props":
      for prop in section[1]:
        props.add(prop)
    of "render":
      renderBody = section[1]
    of "update":
      updateBody = section[1]
  
  let typeName = ident($name)
  result.add quote do:
    type `typeName` = ref object of Widget
      `props`

# Example basic widget
defineWidget Button:
  props:
    text: string
    onClick: proc()

  render:
    # Basic render implementation
    let rect = widget.rect
    nw.drawButton(rect, widget.text)
    
  update:
    if nw.isClicked(widget.rect):
      widget.onClick()

# renderer.nim
import types, naylib

type NaylibWrapper = object
  # Will contain wrapper methods for Raylib/raygui

proc drawButton*(nw: NaylibWrapper, rect: Rect, text: string) =
  # Wrapper for raygui button
  if GuiButton(
    Rectangle(
      x: rect.pos.x,
      y: rect.pos.y,
      width: rect.size.width,
      height: rect.size.height
    ),
    text.cstring
  ):
    # Handle click
    discard

# quickui.nim
import types, widgets, renderer
export types, widgets

proc init*() =
  # Initialize the GUI system
  initWindow(800, 600, "QuickUI App")
  setTargetFPS(60)

proc run*(root: Widget) =
  while not windowShouldClose():
    beginDrawing()
    clearBackground(RayWhite)
    
    let ctx = RenderContext()
    root.update()
    root.render(ctx)
    
    endDrawing()
  
  closeWindow()