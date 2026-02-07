## Interactive Control Primitives
##
## Composable functions for UI controls and interactive elements
## Part of the refactored drawing_primitives module

import raylib
import math
import ../../../core/types
import shapes
import text as textModule  # Import with alias to avoid identifier conflicts

# ============================================================================
# Helper Functions
# ============================================================================

proc fadeColor(color: raylib.Color, factor: float32): raylib.Color =
  ## Fades a color by a factor (0.0 = transparent, 1.0 = opaque)
  raylib.Color(
    r: uint8(color.r.float32 * factor),
    g: uint8(color.g.float32 * factor),
    b: uint8(color.b.float32 * factor),
    a: color.a
  )

# ============================================================================
# Basic Interactive Marks
# ============================================================================

proc drawCheckmark*(rect: Rect, color: raylib.Color, thickness = 2.0f32) =
  ## Draws a checkmark symbol
  let padding = rect.width * 0.2
  let points = [
    Vector2(x: rect.x + padding,
           y: rect.y + rect.height * 0.5),
    Vector2(x: rect.x + rect.width * 0.4,
           y: rect.y + rect.height * 0.8),
    Vector2(x: rect.x + rect.width - padding,
           y: rect.y + rect.height * 0.2)
  ]

  drawLine(points[0], points[1], thickness, color)
  drawLine(points[1], points[2], thickness, color)

proc drawRadioCircle*(rect: Rect, selected: bool, color: raylib.Color) =
  ## Draws a radio button circle
  let center = Vector2(
    x: rect.x + rect.width/2,
    y: rect.y + rect.height/2
  )
  let radius = min(rect.width, rect.height) / 2

  # Outer circle
  drawCircleLines(
    int32(center.x),
    int32(center.y),
    radius,
    color
  )

  # Inner dot if selected
  if selected:
    drawCircle(
      int32(center.x),
      int32(center.y),
      radius * 0.4,
      color
    )

proc drawFocusRing*(rect: Rect, color: raylib.Color) =
  ## Draws a focus indicator around a rectangle
  const dashLength = 4.0f32
  drawDashedLine(
    rect.x, rect.y,
    rect.x + rect.width, rect.y,
    dashLength, color
  )
  drawDashedLine(
    rect.x + rect.width, rect.y,
    rect.x + rect.width, rect.y + rect.height,
    dashLength, color
  )
  drawDashedLine(
    rect.x + rect.width, rect.y + rect.height,
    rect.x, rect.y + rect.height,
    dashLength, color
  )
  drawDashedLine(
    rect.x, rect.y + rect.height,
    rect.x, rect.y,
    dashLength, color
  )

# ============================================================================
# Scrollbars and Handles
# ============================================================================

proc drawScrollbar*(rect: Rect, contentSize, viewSize, offset: float32,
                   color: raylib.Color, hovered = false) =
  ## Draws a scrollbar with thumb
  # Track
  drawRect(rect, color.fadeColor(0.3))

  # Calculate thumb size and position
  let ratio = viewSize / contentSize
  let thumbSize = max(rect.height * ratio, 40.0)
  let maxOffset = contentSize - viewSize
  let thumbOffset = (rect.height - thumbSize) * (offset / maxOffset)

  # Thumb
  drawRoundedRect(
    Rect(
      x: rect.x,
      y: rect.y + thumbOffset,
      width: rect.width,
      height: thumbSize
    ),
    rect.width / 2,
    if hovered: color else: color.fadeColor(0.8)
  )

proc drawResizeHandle*(rect: Rect, color: raylib.Color) =
  ## Draws a resize handle in the corner
  let size = min(rect.width, rect.height)
  let spacing = size / 4

  for i in 0..2:
    drawLine(
      rect.x + rect.width - spacing * (i.float32 + 1),
      rect.y + rect.height,
      rect.x + rect.width,
      rect.y + rect.height - spacing * (i.float32 + 1),
      color,
      1.0
    )

# ============================================================================
# Visual Feedback Effects
# ============================================================================

proc drawRipple*(rect: Rect, center: tuple[x, y: float32],
                 progress: float32, color: raylib.Color) =
  ## Draws a material design ripple effect
  let maxRadius = sqrt(rect.width * rect.width + rect.height * rect.height)
  let currentRadius = maxRadius * progress

  # Fade out as the circle grows
  let alpha = uint8((1.0 - progress) * 255)
  let rippleColor = raylib.Color(
    r: color.r, g: color.g, b: color.b, a: alpha
  )

  drawCircle(
    int32(center.x),
    int32(center.y),
    currentRadius,
    rippleColor
  )

# ============================================================================
# Progress and Loading
# ============================================================================

proc drawProgressBar*(rect: Rect, progress: float32,
                     color: raylib.Color, backgroundColor: raylib.Color) =
  ## Draws a horizontal progress bar
  # Background
  drawRoundedRect(rect, rect.height/2, backgroundColor)

  # Progress
  if progress > 0:
    drawRoundedRect(
      Rect(
        x: rect.x,
        y: rect.y,
        width: rect.width * clamp(progress, 0.0, 1.0),
        height: rect.height
      ),
      rect.height/2,
      color
    )

proc drawSpinner*(center: tuple[x, y: float32], radius: float32,
                  rotation: float32, color: raylib.Color) =
  ## Draws an animated loading spinner
  const segments = 12
  let arcLength = 2.0 * PI * 0.75  # Leave a gap
  let segmentAngle = arcLength / segments.float32

  for i in 0..<segments:
    let alpha = uint8(float32(255) * (i.float32 / segments.float32))
    let segmentColor = raylib.Color(
      r: color.r, g: color.g, b: color.b, a: alpha
    )

    let startAngle = rotation + i.float32 * segmentAngle
    let endAngle = startAngle + segmentAngle * 0.8

    drawArc(center.x, center.y, radius,
            radToDeg(startAngle), radToDeg(endAngle),
            segmentColor)

# ============================================================================
# Decorative Elements
# ============================================================================

type ArrowDirection* = enum
  Up, Down, Left, Right

export ArrowDirection

proc drawArrow*(rect: Rect, direction: ArrowDirection,
                color: raylib.Color, thickness = 2.0f32) =
  ## Draws a directional arrow
  let center = (x: rect.x + rect.width/2, y: rect.y + rect.height/2)
  let size = min(rect.width, rect.height) * 0.4

  var points: array[3, Vector2]
  case direction:
  of Up:
    points = [
      Vector2(x: center.x, y: center.y - size),
      Vector2(x: center.x - size, y: center.y + size),
      Vector2(x: center.x + size, y: center.y + size)
    ]
  of Down:
    points = [
      Vector2(x: center.x, y: center.y + size),
      Vector2(x: center.x - size, y: center.y - size),
      Vector2(x: center.x + size, y: center.y - size)
    ]
  of Left:
    points = [
      Vector2(x: center.x - size, y: center.y),
      Vector2(x: center.x + size, y: center.y - size),
      Vector2(x: center.x + size, y: center.y + size)
    ]
  of Right:
    points = [
      Vector2(x: center.x + size, y: center.y),
      Vector2(x: center.x - size, y: center.y - size),
      Vector2(x: center.x - size, y: center.y + size)
    ]

  drawTriangle(points[0], points[1], points[2], color)

proc drawBadge*(text: string, rect: Rect, color: raylib.Color,
                textColor: raylib.Color, style: TextStyle) =
  ## Draws a notification badge
  let metrics = measureText(text, style)
  let diameter = max(metrics.width + 10, metrics.height + 6)

  # Draw circle background
  drawCircle(
    int32(rect.x + rect.width),
    int32(rect.y),
    diameter/2,
    color
  )

  # Draw text centered in badge
  drawText(
    text,
    Rect(
      x: rect.x + rect.width - diameter/2 - metrics.width/2,
      y: rect.y - diameter/2 - metrics.height/2,
      width: metrics.width,
      height: metrics.height
    ),
    TextStyle(fontSize: style.fontSize, color: textColor)
  )

proc drawTooltip*(text: string, rect: Rect,
                  backgroundColor: raylib.Color, textColor: raylib.Color,
                  style: TextStyle) =
  ## Draws a tooltip with arrow pointing to element
  let padding = 6.0
  let arrowSize = 5.0
  let metrics = measureText(text, style)
  let tooltipRect = Rect(
    x: rect.x,
    y: rect.y - metrics.height - padding * 2 - arrowSize,
    width: metrics.width + padding * 2,
    height: metrics.height + padding * 2
  )

  # Background
  drawRoundedRect(tooltipRect, 4, backgroundColor)

  # Arrow
  let points = [
    Vector2(x: rect.x + rect.width/2 - arrowSize,
           y: tooltipRect.y + tooltipRect.height),
    Vector2(x: rect.x + rect.width/2 + arrowSize,
           y: tooltipRect.y + tooltipRect.height),
    Vector2(x: rect.x + rect.width/2,
           y: tooltipRect.y + tooltipRect.height + arrowSize)
  ]
  drawTriangle(points[0], points[1], points[2], backgroundColor)

  # Text
  drawText(
    text,
    Rect(
      x: tooltipRect.x + padding,
      y: tooltipRect.y + padding,
      width: tooltipRect.width - padding * 2,
      height: tooltipRect.height - padding * 2
    ),
    TextStyle(fontSize: style.fontSize, color: textColor)
  )

proc drawPlaceholder*(rect: Rect, text: string,
                     style: TextStyle, opacity = 0.5) =
  ## Draws placeholder text with reduced opacity
  let color = raylib.Color(
    r: style.color.r,
    g: style.color.g,
    b: style.color.b,
    a: uint8(255.0 * opacity)
  )

  drawText(
    text,
    rect,
    TextStyle(fontSize: style.fontSize, color: color),
    TextAlign.Center
  )

# ============================================================================
# Toggle and Slider Controls
# ============================================================================

proc drawToggleSwitch*(rect: Rect, isOn: bool, color: raylib.Color) =
  ## Draws an iOS/Android style toggle switch
  let height = rect.height
  let width = height * 2
  let radius = height/2
  let thumbRadius = radius * 0.8

  # Track
  drawRoundedRect(
    Rect(x: rect.x, y: rect.y, width: width, height: height),
    radius,
    if isOn: color else: raylib.Color(r: 200, g: 200, b: 200, a: 255)
  )

  # Thumb position
  let thumbX = if isOn:
                 rect.x + width - radius
               else:
                 rect.x + radius

  # Thumb with shadow
  let shadow = Shadow(
    blur: 4,
    spread: 0,
    color: raylib.Color(r: 0, g: 0, b: 0, a: 64),
    offsetY: 2
  )

  drawShadow(
    Rect(
      x: thumbX - thumbRadius,
      y: rect.y + radius - thumbRadius,
      width: thumbRadius * 2,
      height: thumbRadius * 2
    ),
    shadow
  )

  # Thumb
  drawCircle(
    int32(thumbX),
    int32(rect.y + radius),
    thumbRadius,
    WHITE
  )

proc drawSlider*(rect: Rect, value: float32, color: raylib.Color) =
  ## Draws a horizontal slider
  let height = rect.height
  let trackHeight = height * 0.4
  let thumbRadius = height/2

  # Track
  drawRoundedRect(
    Rect(
      x: rect.x,
      y: rect.y + (height - trackHeight)/2,
      width: rect.width,
      height: trackHeight
    ),
    trackHeight/2,
    raylib.Color(r: 200, g: 200, b: 200, a: 255)
  )

  # Filled portion
  let thumbX = rect.x + rect.width * clamp(value, 0.0, 1.0)
  drawRoundedRect(
    Rect(
      x: rect.x,
      y: rect.y + (height - trackHeight)/2,
      width: thumbX - rect.x,
      height: trackHeight
    ),
    trackHeight/2,
    color
  )

  # Thumb
  drawCircle(
    int32(thumbX),
    int32(rect.y + height/2),
    thumbRadius,
    color
  )
