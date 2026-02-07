## Basic Shape Drawing Primitives
##
## Composable, focused functions for drawing geometric shapes
## Part of the refactored drawing_primitives module

import raylib
import math
import ../../../core/types

export types

type
  Gradient* = object
    startColor*, endColor*: raylib.Color
    vertical*: bool

  Shadow* = object
    blur*: float32
    spread*: float32
    color*: raylib.Color
    offsetX*, offsetY*: float32

# ============================================================================
# Basic Shapes
# ============================================================================

proc drawRect*(rect: Rect, color: raylib.Color, filled = true) =
  ## Draws a rectangle with optional fill
  if filled:
    drawRectangle(
      int32(rect.x),
      int32(rect.y),
      int32(rect.width),
      int32(rect.height),
      color
    )
  else:
    drawRectangleLines(
      int32(rect.x),
      int32(rect.y),
      int32(rect.width),
      int32(rect.height),
      color
    )

proc drawRoundedRect*(rect: Rect, radius: float32, color: raylib.Color,
    filled = true, lineThickness = 2.0f32) =
  ## Draws a rectangle with rounded corners
  let rec = Rectangle(
    x: rect.x,
    y: rect.y,
    width: rect.width,
    height: rect.height
  )
  if filled:
    drawRectangleRounded(rec, radius/min(rect.width, rect.height), 10, color)
  else:
    drawRectangleRoundedLines(rec, radius/min(rect.width, rect.height), 10, lineThickness, color)

proc drawRoundedRectLines*(rect: Rect, radius, lineThickness: float32,
    color: raylib.Color) =
  ## Draws rounded rectangle outline (convenience wrapper)
  drawRoundedRect(rect, radius, color, filled = false, lineThickness = lineThickness)

proc drawLine*(x1, y1, x2, y2: float32, color: raylib.Color, thickness = 1.0f32) =
  ## Draws a line with specified thickness
  drawLine(
    Vector2(x: x1, y: y1),
    Vector2(x: x2, y: y2),
    thickness,
    color
  )

proc drawDashedLine*(x1, y1, x2, y2: float32, dashLen: float32, color: raylib.Color) =
  ## Draws a dashed line with specified dash length
  let dx = x2 - x1
  let dy = y2 - y1
  let len = sqrt(dx * dx + dy * dy)
  let steps = int(len / dashLen / 2)

  let stepX = (dx / len) * dashLen
  let stepY = (dy / len) * dashLen

  for i in 0..<steps:
    let startX = x1 + stepX * (i.float32 * 2)
    let startY = y1 + stepY * (i.float32 * 2)
    let endX = startX + stepX
    let endY = startY + stepY
    drawLine(startX, startY, endX, endY, color)

proc drawArc*(centerX, centerY, radius: float32,
              startAngle, endAngle: float32, color: raylib.Color) =
  ## Draws an arc (partial circle)
  let startRad = degToRad(startAngle)
  let endRad = degToRad(endAngle)

  let segments = int32(radius / 4) + 8
  let step = (endRad - startRad) / segments.float32

  var points = newSeq[Vector2](segments + 1)
  for i in 0..segments:
    let angle = startRad + step * i.float32
    points[i] = Vector2(
      x: centerX + cos(angle) * radius,
      y: centerY + sin(angle) * radius
    )

  for i in 0..<points.high:
    drawLine(points[i], points[i + 1], 2, color)

proc drawPie*(centerX, centerY, radius: float32,
              startAngle, endAngle: float32, color: raylib.Color) =
  ## Draws a pie slice (filled arc)
  let center = Vector2(x: centerX, y: centerY)
  let segments = int32(radius / 4) + 8
  let startRad = degToRad(startAngle)
  let endRad = degToRad(endAngle)
  let step = (endRad - startRad) / segments.float32

  var points = newSeq[Vector2](segments + 2)
  points[0] = center

  for i in 0..segments:
    let angle = startRad + step * i.float32
    points[i + 1] = Vector2(
      x: centerX + cos(angle) * radius,
      y: centerY + sin(angle) * radius
    )

  for i in 0..<points.high-1:
    drawTriangle(points[0], points[i + 1], points[i + 2], color)

proc drawBezier*(x1, y1, cp1x, cp1y, cp2x, cp2y, x2, y2: float32,
                 color: raylib.Color, thickness = 2.0f32) =
  ## Draws a cubic Bezier curve
  let steps = 20
  for i in 0..<steps:
    let t1 = i.float32 / steps.float32
    let t2 = (i + 1).float32 / steps.float32

    let p1x = pow(1-t1, 3)*x1 + 3*pow(1-t1, 2)*t1*cp1x +
              3*(1-t1)*pow(t1, 2)*cp2x + pow(t1, 3)*x2
    let p1y = pow(1-t1, 3)*y1 + 3*pow(1-t1, 2)*t1*cp1y +
              3*(1-t1)*pow(t1, 2)*cp2y + pow(t1, 3)*y2

    let p2x = pow(1-t2, 3)*x1 + 3*pow(1-t2, 2)*t2*cp1x +
              3*(1-t2)*pow(t2, 2)*cp2x + pow(t2, 3)*x2
    let p2y = pow(1-t2, 3)*y1 + 3*pow(1-t2, 2)*t2*cp1y +
              3*(1-t2)*pow(t2, 2)*cp2y + pow(t2, 3)*y2

    drawLine(
      Vector2(x: p1x, y: p1y),
      Vector2(x: p2x, y: p2y),
      thickness,
      color
    )

# ============================================================================
# Visual Effects
# ============================================================================

proc drawShadow*(rect: Rect, shadow: Shadow) =
  ## Draws a drop shadow effect
  for i in 0..<int(shadow.blur):
    let alpha = uint8(shadow.color.a.float32 * (1.0 - i.float32/shadow.blur))
    let offset = i.float32
    let shadowColor = raylib.Color(
      r: shadow.color.r,
      g: shadow.color.g,
      b: shadow.color.b,
      a: alpha
    )

    drawRectangle(
      int32(rect.x + shadow.offsetX - offset),
      int32(rect.y + shadow.offsetY - offset),
      int32(rect.width + shadow.spread + offset * 2),
      int32(rect.height + shadow.spread + offset * 2),
      shadowColor
    )

proc drawGradient*(rect: Rect, gradient: Gradient) =
  ## Draws a gradient fill
  if gradient.vertical:
    drawRectangleGradientV(
      int32(rect.x),
      int32(rect.y),
      int32(rect.width),
      int32(rect.height),
      gradient.startColor,
      gradient.endColor
    )
  else:
    drawRectangleGradientH(
      int32(rect.x),
      int32(rect.y),
      int32(rect.width),
      int32(rect.height),
      gradient.startColor,
      gradient.endColor
    )

# ============================================================================
# Clipping
# ============================================================================

type ClipRect* = object
  x*, y*, width*, height*: int32

proc beginClip*(rect: Rect): ClipRect =
  ## Begins a clipping region
  result = ClipRect(
    x: int32(rect.x),
    y: int32(rect.y),
    width: int32(rect.width),
    height: int32(rect.height)
  )
  beginScissorMode(result.x, result.y, result.width, result.height)

proc endClip*(clip: ClipRect) =
  ## Ends a clipping region
  endScissorMode()
