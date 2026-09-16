## Canvas draw commands: the shape vocabulary and how each one paints.
##
## Split out of canvas.nim, whose definePrimitive body was otherwise carrying a
## hundred lines of shape drawing alongside its input handling.
##
## Every command stores canvas-relative coordinates and is painted at an
## explicit origin. That is not a style choice: main_loop's renderPass draws
## each widget into its own RenderTexture2D with the widget's bounds.x/y zeroed
## for the duration, so a command holding absolute screen coordinates would
## paint in the wrong place, or off the texture entirely.

import rui_core
import rui_drawing
import std/[options, math, json]

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

proc dist*(a, b: Point): float32 =
  let dx = b.x - a.x
  let dy = b.y - a.y
  sqrt(dx * dx + dy * dy)

proc drawLineCmd*(cmd: DrawCommand, originX, originY: float32) =
  drawLine(originX + cmd.lineStart.x, originY + cmd.lineStart.y,
           originX + cmd.lineEnd.x, originY + cmd.lineEnd.y,
           cmd.lineColor, cmd.lineThickness)

proc drawRectCmd*(cmd: DrawCommand, originX, originY: float32) =
  ## dcRect and dcRectFilled: square or rounded, outlined or filled.
  let r = Rect(x: originX + cmd.rect.x, y: originY + cmd.rect.y,
               width: cmd.rect.width, height: cmd.rect.height)
  let filled = cmd.kind == dcRectFilled
  if not cmd.rectRounded:
    drawRect(r, cmd.rectColor, filled = filled)
  elif filled:
    drawRoundedRect(r, cmd.rectRoundness, cmd.rectColor, true)
  else:
    drawRoundedRectLines(r, cmd.rectRoundness, 2.0, cmd.rectColor)

proc drawTriangleCmd*(cmd: DrawCommand, originX, originY: float32) =
  ## No triangle primitive in rui_drawing; three edges is close enough and
  ## keeps the widget off raylib's raw drawing calls.
  drawLine(originX + cmd.v1.x, originY + cmd.v1.y,
           originX + cmd.v2.x, originY + cmd.v2.y, cmd.triangleColor, 2.0)
  drawLine(originX + cmd.v2.x, originY + cmd.v2.y,
           originX + cmd.v3.x, originY + cmd.v3.y, cmd.triangleColor, 2.0)
  drawLine(originX + cmd.v3.x, originY + cmd.v3.y,
           originX + cmd.v1.x, originY + cmd.v1.y, cmd.triangleColor, 2.0)

proc drawPolygonCmd*(cmd: DrawCommand, originX, originY: float32) =
  ## Closed outline through the points. Fewer than two draws nothing.
  if cmd.points.len < 2:
    return
  for i in 0 ..< cmd.points.len:
    let a = cmd.points[i]
    let b = cmd.points[(i + 1) mod cmd.points.len]
    drawLine(originX + a.x, originY + a.y,
             originX + b.x, originY + b.y, cmd.polygonColor, 2.0)

proc drawCommand*(cmd: DrawCommand, originX, originY: float32) =
  ## Replay one command, offset to wherever the canvas currently is.
  ## Dispatch only -- each shape's drawing lives in its own proc above.
  case cmd.kind
  of dcLine:         drawLineCmd(cmd, originX, originY)
  of dcRect,
     dcRectFilled:   drawRectCmd(cmd, originX, originY)
  of dcCircle:       drawArc(originX + cmd.center.x, originY + cmd.center.y,
                             cmd.radius, 0.0, 360.0, cmd.circleColor)
  of dcCircleFilled: drawPie(originX + cmd.center.x, originY + cmd.center.y,
                             cmd.radius, 0.0, 360.0, cmd.circleColor)
  of dcTriangle:     drawTriangleCmd(cmd, originX, originY)
  of dcPolygon:      drawPolygonCmd(cmd, originX, originY)
  of dcText:         drawText(cmd.textContent,
                              originX + cmd.textPos.x, originY + cmd.textPos.y,
                              cmd.textSize, cmd.textColor)

