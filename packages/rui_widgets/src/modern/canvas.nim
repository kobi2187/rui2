## Canvas Widget - RUI2
##
## A retained-mode drawing surface: a list of DrawCommands that the widget
## replays every repaint, plus optional interactive drawing.
##
## Command coordinates are relative to the canvas' top-left corner, not to the
## screen. That is what lets a canvas be moved or re-laid-out without its
## contents sliding, and it is also required by renderPass, which zeroes
## `bounds.x/y` while a widget paints into its own render texture.

import rui_core
import rui_drawing
import std/[options, math]

import raylib

type
  DrawCommandKind* = enum
    dcLine
    dcRect
    dcRectFilled
    dcCircle
    dcCircleFilled
    dcTriangle
    dcPolygon
    dcText

  DrawCommand* = object
    ## All positions are canvas-relative.
    case kind*: DrawCommandKind
    of dcLine:
      lineStart*: Point
      lineEnd*: Point
      lineColor*: Color
      lineThickness*: float32

    of dcRect, dcRectFilled:
      rect*: Rect
      rectColor*: Color
      rectRounded*: bool
      rectRoundness*: float32

    of dcCircle, dcCircleFilled:
      center*: Point
      radius*: float32
      circleColor*: Color

    of dcTriangle:
      v1*, v2*, v3*: Point
      triangleColor*: Color

    of dcPolygon:
      points*: seq[Point]
      polygonColor*: Color
      polygonFilled*: bool

    of dcText:
      textContent*: string
      textPos*: Point
      textSize*: float32
      textColor*: Color

  DrawingMode* = enum
    dmNone        # Interaction off; the canvas only replays its commands
    dmFreehand
    dmLine
    dmRect
    dmCircle

proc dist(a, b: Point): float32 =
  let dx = b.x - a.x
  let dy = b.y - a.y
  sqrt(dx * dx + dy * dy)

proc drawCommand(cmd: DrawCommand, originX, originY: float32) =
  ## Replay one command, offset to wherever the canvas currently is.
  case cmd.kind
  of dcLine:
    drawLine(originX + cmd.lineStart.x, originY + cmd.lineStart.y,
             originX + cmd.lineEnd.x, originY + cmd.lineEnd.y,
             cmd.lineColor, cmd.lineThickness)
  of dcRect, dcRectFilled:
    let r = Rect(x: originX + cmd.rect.x, y: originY + cmd.rect.y,
                 width: cmd.rect.width, height: cmd.rect.height)
    if cmd.rectRounded:
      if cmd.kind == dcRectFilled:
        drawRoundedRect(r, cmd.rectRoundness, cmd.rectColor, true)
      else:
        drawRoundedRectLines(r, cmd.rectRoundness, 2.0, cmd.rectColor)
    else:
      drawRect(r, cmd.rectColor, filled = cmd.kind == dcRectFilled)
  of dcCircle:
    drawArc(originX + cmd.center.x, originY + cmd.center.y, cmd.radius,
            0.0, 360.0, cmd.circleColor)
  of dcCircleFilled:
    drawPie(originX + cmd.center.x, originY + cmd.center.y, cmd.radius,
            0.0, 360.0, cmd.circleColor)
  of dcTriangle:
    # No triangle primitive in rui_drawing; three edges is close enough and
    # keeps the widget off raylib's raw drawing calls.
    drawLine(originX + cmd.v1.x, originY + cmd.v1.y,
             originX + cmd.v2.x, originY + cmd.v2.y, cmd.triangleColor, 2.0)
    drawLine(originX + cmd.v2.x, originY + cmd.v2.y,
             originX + cmd.v3.x, originY + cmd.v3.y, cmd.triangleColor, 2.0)
    drawLine(originX + cmd.v3.x, originY + cmd.v3.y,
             originX + cmd.v1.x, originY + cmd.v1.y, cmd.triangleColor, 2.0)
  of dcPolygon:
    if cmd.points.len >= 2:
      for i in 0 ..< cmd.points.len:
        let a = cmd.points[i]
        let b = cmd.points[(i + 1) mod cmd.points.len]
        drawLine(originX + a.x, originY + a.y,
                 originX + b.x, originY + b.y, cmd.polygonColor, 2.0)
  of dcText:
    drawText(cmd.textContent, originX + cmd.textPos.x, originY + cmd.textPos.y,
             cmd.textSize, cmd.textColor)

definePrimitive(Canvas):
  props:
    enableDrawing: bool = true
    drawingMode: DrawingMode = dmNone
    defaultColor: Color = Color(r: 0, g: 0, b: 0, a: 255)
    defaultThickness: float32 = 2.0
    showGrid: bool = false
    gridSize: float32 = 20.0
    intent: ThemeIntent = Default

  state:
    commands: seq[DrawCommand]
    isDrawing: bool
    drawStart: Point             # Canvas-relative
    dragPos: Point               # Canvas-relative, current pointer
    currentPath: seq[Point]      # Freehand stroke in progress

  actions:
    onDraw(command: DrawCommand)
    onDrawComplete(commands: seq[DrawCommand])
    onClear()

  events:
    on_mouse_down:
      if not widget.enableDrawing or widget.drawingMode == dmNone:
        return false
      let p = Point(x: event.mousePos.x - widget.bounds.x,
                    y: event.mousePos.y - widget.bounds.y)
      widget.isDrawing = true
      widget.drawStart = p
      widget.dragPos = p
      widget.currentPath = @[p]
      widget.isDirty = true
      return true

    on_mouse_move:
      if not widget.isDrawing:
        return false
      let p = Point(x: event.mousePos.x - widget.bounds.x,
                    y: event.mousePos.y - widget.bounds.y)
      widget.dragPos = p
      if widget.drawingMode == dmFreehand:
        widget.currentPath.add(p)
      widget.isDirty = true
      return true

    on_mouse_up:
      if not widget.isDrawing:
        return false
      widget.isDrawing = false
      widget.isDirty = true

      let start = widget.drawStart
      let last = widget.dragPos

      case widget.drawingMode
      of dmNone:
        discard
      of dmFreehand:
        # One line segment per pair of sampled points.
        for i in 1 ..< widget.currentPath.len:
          let cmd = DrawCommand(kind: dcLine,
                                lineStart: widget.currentPath[i - 1],
                                lineEnd: widget.currentPath[i],
                                lineColor: widget.defaultColor,
                                lineThickness: widget.defaultThickness)
          widget.commands.add(cmd)
        if widget.onDrawComplete.isSome:
          widget.onDrawComplete.get()(widget.commands)
      of dmLine:
        let cmd = DrawCommand(kind: dcLine, lineStart: start, lineEnd: last,
                              lineColor: widget.defaultColor,
                              lineThickness: widget.defaultThickness)
        widget.commands.add(cmd)
        if widget.onDraw.isSome:
          widget.onDraw.get()(cmd)
      of dmRect:
        let cmd = DrawCommand(kind: dcRect,
                              rect: Rect(x: min(start.x, last.x),
                                         y: min(start.y, last.y),
                                         width: abs(last.x - start.x),
                                         height: abs(last.y - start.y)),
                              rectColor: widget.defaultColor,
                              rectRounded: false, rectRoundness: 0.0)
        widget.commands.add(cmd)
        if widget.onDraw.isSome:
          widget.onDraw.get()(cmd)
      of dmCircle:
        let cmd = DrawCommand(kind: dcCircle, center: start,
                              radius: dist(start, last),
                              circleColor: widget.defaultColor)
        widget.commands.add(cmd)
        if widget.onDraw.isSome:
          widget.onDraw.get()(cmd)

      widget.currentPath.setLen(0)
      return true

  layout:
    # A canvas has no content to measure; it fills whatever it is given.
    if widget.bounds.width <= 0:
      widget.bounds.width = 300.0'f32
    if widget.bounds.height <= 0:
      widget.bounds.height = 200.0'f32

  render:
    let props = currentTheme.getThemeProps(widget.intent, Normal)
    drawThemedBackground(widget.bounds, props)

    if widget.showGrid:
      let gridColor = props.borderColor.get(Color(r: 240, g: 240, b: 240, a: 255))
      var x = widget.bounds.x
      while x <= widget.bounds.x + widget.bounds.width:
        drawLine(x, widget.bounds.y, x, widget.bounds.y + widget.bounds.height, gridColor)
        x += widget.gridSize
      var y = widget.bounds.y
      while y <= widget.bounds.y + widget.bounds.height:
        drawLine(widget.bounds.x, y, widget.bounds.x + widget.bounds.width, y, gridColor)
        y += widget.gridSize

    let clip = beginClip(widget.bounds)
    for cmd in widget.commands:
      drawCommand(cmd, widget.bounds.x, widget.bounds.y)

    # Live preview of the stroke in progress.
    if widget.isDrawing:
      let ox = widget.bounds.x
      let oy = widget.bounds.y
      let start = widget.drawStart
      let last = widget.dragPos
      case widget.drawingMode
      of dmFreehand:
        for i in 1 ..< widget.currentPath.len:
          drawLine(ox + widget.currentPath[i - 1].x, oy + widget.currentPath[i - 1].y,
                   ox + widget.currentPath[i].x, oy + widget.currentPath[i].y,
                   widget.defaultColor, widget.defaultThickness)
      of dmLine:
        drawLine(ox + start.x, oy + start.y, ox + last.x, oy + last.y,
                 widget.defaultColor, widget.defaultThickness)
      of dmRect:
        drawRect(Rect(x: ox + min(start.x, last.x), y: oy + min(start.y, last.y),
                      width: abs(last.x - start.x), height: abs(last.y - start.y)),
                 widget.defaultColor, filled = false)
      of dmCircle:
        drawArc(ox + start.x, oy + start.y, dist(start, last),
                0.0, 360.0, widget.defaultColor)
      of dmNone:
        discard

    endClip(clip)
    drawThemedBorder(widget.bounds, props, widget.focused)

proc clearCanvas*(widget: Canvas) =
  ## Drop every command and repaint empty.
  widget.commands.setLen(0)
  widget.currentPath.setLen(0)
  widget.isDrawing = false
  widget.isDirty = true
  if widget.onClear.isSome:
    widget.onClear.get()()

proc addCommand*(widget: Canvas, cmd: DrawCommand) =
  ## Append a command from code (positions are canvas-relative).
  widget.commands.add(cmd)
  widget.isDirty = true
