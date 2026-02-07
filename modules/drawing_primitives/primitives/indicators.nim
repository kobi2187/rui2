## Status and State Indicator Primitives
##
## Composable functions for validation marks, alerts, and progress indicators
## Part of the refactored drawing_primitives module

import raylib
import math, options
import ../../../core/types
import shapes

export types, options

# ============================================================================
# Validation States
# ============================================================================

type
  ValidationState* = enum
    Success, Error, Warning

  AlertLevel* = enum
    Info, Alert, Critical

proc drawValidationMark*(rect: Rect, state: ValidationState,
                        color: Option[raylib.Color] = none(raylib.Color)) =
  ## Draws validation indicators (checkmark, X, or warning triangle)
  let size = min(rect.width, rect.height)
  let center = (x: rect.x + rect.width/2, y: rect.y + rect.height/2)
  let markColor = if color.isSome: color.get else:
    case state
    of Success: raylib.Color(r: 76, g: 175, b: 80, a: 255)    # Material Green
    of Error: raylib.Color(r: 244, g: 67, b: 54, a: 255)      # Material Red
    of Warning: raylib.Color(r: 255, g: 152, b: 0, a: 255)    # Material Orange

  case state
  of Success:
    # Checkmark
    let points = [
      Vector2(x: center.x - size * 0.3, y: center.y),
      Vector2(x: center.x - size * 0.1, y: center.y + size * 0.2),
      Vector2(x: center.x + size * 0.3, y: center.y - size * 0.2)
    ]
    drawLine(points[0], points[1], 2, markColor)
    drawLine(points[1], points[2], 2, markColor)

  of Error:
    # X mark
    drawLine(
      Vector2(x: center.x - size * 0.3, y: center.y - size * 0.3),
      Vector2(x: center.x + size * 0.3, y: center.y + size * 0.3),
      2, markColor
    )
    drawLine(
      Vector2(x: center.x - size * 0.3, y: center.y + size * 0.3),
      Vector2(x: center.x + size * 0.3, y: center.y - size * 0.3),
      2, markColor
    )

  of Warning:
    # Triangle with exclamation mark
    let points = [
      Vector2(x: center.x, y: center.y - size * 0.3),
      Vector2(x: center.x - size * 0.3, y: center.y + size * 0.3),
      Vector2(x: center.x + size * 0.3, y: center.y + size * 0.3)
    ]
    for i in 0..2:
      drawLine(
        points[i],
        points[(i + 1) mod 3],
        2, markColor
      )
    # Exclamation mark
    drawCircle(int32(center.x), int32(center.y + size * 0.1), 2, markColor)
    drawLine(
      Vector2(x: center.x, y: center.y - size * 0.1),
      Vector2(x: center.x, y: center.y),
      2, markColor
    )

proc drawAlertSymbol*(rect: Rect, level: AlertLevel,
                      color: Option[raylib.Color] = none(raylib.Color)) =
  ## Draws alert symbols (info, warning, critical)
  let size = min(rect.width, rect.height)
  let center = (x: rect.x + rect.width/2, y: rect.y + rect.height/2)
  let symbolColor = if color.isSome: color.get else:
    case level
    of Info: raylib.Color(r: 33, g: 150, b: 243, a: 255)      # Material Blue
    of Alert: raylib.Color(r: 255, g: 152, b: 0, a: 255)      # Material Orange
    of Critical: raylib.Color(r: 244, g: 67, b: 54, a: 255)   # Material Red

  case level
  of Info:
    # Circle with 'i'
    drawCircleLines(int32(center.x), int32(center.y), size/2, symbolColor)
    drawCircle(int32(center.x), int32(center.y - size * 0.2), 2, symbolColor)
    drawLine(
      Vector2(x: center.x, y: center.y - size * 0.1),
      Vector2(x: center.x, y: center.y + size * 0.2),
      2, symbolColor
    )

  of Alert, Critical:
    # Octagon for critical, circle for alert
    if level == Critical:
      var points = newSeq[Vector2](8)
      for i in 0..7:
        let angle = PI/8 + i.float32 * PI/4
        points[i] = Vector2(
          x: center.x + cos(angle) * size/2,
          y: center.y + sin(angle) * size/2
        )
      for i in 0..7:
        drawLine(points[i], points[(i + 1) mod 8], 2, symbolColor)
    else:
      drawCircleLines(int32(center.x), int32(center.y), size/2, symbolColor)

    # Exclamation mark
    drawCircle(int32(center.x), int32(center.y + size * 0.1), 2, symbolColor)
    drawLine(
      Vector2(x: center.x, y: center.y - size * 0.2),
      Vector2(x: center.x, y: center.y),
      2, symbolColor
    )

# ============================================================================
# Progress Indicators
# ============================================================================

proc drawBusyIndicator*(rect: Rect, progress: float32, color: raylib.Color) =
  ## Draws an animated busy indicator (macOS style spinning dots)
  let center = (x: rect.x + rect.width/2, y: rect.y + rect.height/2)
  let radius = min(rect.width, rect.height)/2
  let dotCount = 8
  let dotRadius = radius * 0.15

  for i in 0..<dotCount:
    let angle = progress * PI * 2 + i.float32 * PI * 2 / dotCount.float32
    let x = center.x + cos(angle) * radius
    let y = center.y + sin(angle) * radius
    let alpha = uint8(255.0 * (1.0 - i.float32/dotCount.float32))
    drawCircle(
      int32(x),
      int32(y),
      dotRadius,
      raylib.Color(r: color.r, g: color.g, b: color.b, a: alpha)
    )

proc drawIndeterminateProgress*(rect: Rect, offset: float32, color: raylib.Color) =
  ## Draws a moving dots progress indicator
  const dotCount = 5
  const dotSpacing = 20.0
  let dotRadius = rect.height / 3

  for i in 0..<dotCount:
    let phase = (offset + i.float32/dotCount) mod 1.0
    let x = rect.x + phase * rect.width
    let y = rect.y + rect.height/2
    let scale = 1.0 - abs(phase - 0.5) * 2

    drawCircle(
      int32(x),
      int32(y),
      dotRadius * scale,
      color
    )

# ============================================================================
# Highlight and Selection
# ============================================================================

proc drawHighlight*(rect: Rect, color: raylib.Color) =
  ## Draws a glowing highlight effect around a rectangle
  const glowSize = 4.0
  for i in 0..<int(glowSize):
    let alpha = uint8(255.0 * (1.0 - i.float32/glowSize))
    let offset = i.float32
    drawRectangleLines(
      int32(rect.x - offset),
      int32(rect.y - offset),
      int32(rect.width + offset * 2),
      int32(rect.height + offset * 2),
      raylib.Color(r: color.r, g: color.g, b: color.b, a: alpha)
    )

proc drawSelectionRect*(rect: Rect, color: raylib.Color) =
  ## Draws a selection rectangle with dashed border
  const dashLength = 4.0
  drawDashedLine(rect.x, rect.y, rect.x + rect.width, rect.y, dashLength, color)
  drawDashedLine(rect.x + rect.width, rect.y, rect.x + rect.width, rect.y +
      rect.height, dashLength, color)
  drawDashedLine(rect.x + rect.width, rect.y + rect.height, rect.x, rect.y +
      rect.height, dashLength, color)
  drawDashedLine(rect.x, rect.y + rect.height, rect.x, rect.y, dashLength, color)

proc drawFocusHighlight*(rect: Rect, color: raylib.Color) =
  ## Draws a prominent focus highlight (stronger than basic focus ring)
  const borderWidth = 2.0
  const glowSize = 3.0

  # Inner border
  drawRectangleLines(
    int32(rect.x),
    int32(rect.y),
    int32(rect.width),
    int32(rect.height),
    color
  )

  # Outer glow
  for i in 1..int(glowSize):
    let alpha = uint8(255.0 * (1.0 - i.float32/glowSize))
    drawRectangleLines(
      int32(rect.x - i.float32),
      int32(rect.y - i.float32),
      int32(rect.width + i.float32 * 2),
      int32(rect.height + i.float32 * 2),
      raylib.Color(r: color.r, g: color.g, b: color.b, a: alpha)
    )

proc drawDisabledOverlay*(rect: Rect) =
  ## Draws a semi-transparent overlay for disabled UI elements
  drawRect(rect, raylib.Color(r: 128, g: 128, b: 128, a: 128))
