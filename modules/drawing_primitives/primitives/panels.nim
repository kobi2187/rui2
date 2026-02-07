## Panel and Container Primitives
##
## Composable functions for drawing panels, cards, and containers
## Part of the refactored drawing_primitives module

import raylib
import options
import ../../../core/types
import shapes
import text

export types, options

# ============================================================================
# Border and Panel Styles
# ============================================================================

type
  BStyle* = enum
    Solid, Double, Dotted, Dashed

  BorderStyle* = object
    color*: raylib.Color
    width*: float32
    radius*: float32
    style*: BStyle
    shadowColor*: raylib.Color
    elevation*: float32

  GroupBoxStyle* = object
    borderStyle*: BorderStyle
    titleStyle*: TextStyle
    backgroundColor*: raylib.Color
    titlePosition*: TextAlign
    titlePadding*: float32
    titleBackgroundColor*: Option[raylib.Color]

# ============================================================================
# Basic Panels
# ============================================================================

proc drawPanel*(rect: Rect, style: BorderStyle,
                backgroundColor: raylib.Color) =
  ## Draws a basic panel with customizable border
  # Draw background
  if style.radius > 0:
    drawRoundedRect(rect, style.radius, backgroundColor)
  else:
    drawRect(rect, backgroundColor)

  # Draw border based on style
  case style.style
  of Solid:
    if style.radius > 0:
      drawRoundedRect(rect, style.radius, style.color, filled = false)
    else:
      drawRectangleLines(
        int32(rect.x),
        int32(rect.y),
        int32(rect.width),
        int32(rect.height),
        style.color
      )
  of Double:
    let inner = Rect(
      x: rect.x + style.width * 2,
      y: rect.y + style.width * 2,
      width: rect.width - style.width * 4,
      height: rect.height - style.width * 4
    )
    drawPanel(rect, BorderStyle(style: Solid, color: style.color,
              width: style.width), backgroundColor)
    drawPanel(inner, BorderStyle(style: Solid, color: style.color,
              width: style.width), backgroundColor)
  of Dotted:
    let perimeter = 2 * (rect.width + rect.height)
    let dotSpacing = 4.0
    let dots = int(perimeter / dotSpacing)
    for i in 0..<dots:
      let pos = i.float32 * perimeter / dots.float32
      var x, y: float32
      if pos < rect.width:
        x = rect.x + pos
        y = rect.y
      elif pos < rect.width + rect.height:
        x = rect.x + rect.width
        y = rect.y + (pos - rect.width)
      elif pos < 2 * rect.width + rect.height:
        x = rect.x + rect.width - (pos - (rect.width + rect.height))
        y = rect.y + rect.height
      else:
        x = rect.x
        y = rect.y + rect.height - (pos - (2 * rect.width + rect.height))
      drawCircle(int32(x), int32(y), style.width/2, style.color)
  of Dashed:
    drawDashedLine(rect.x, rect.y, rect.x + rect.width, rect.y, 8, style.color)
    drawDashedLine(rect.x + rect.width, rect.y, rect.x + rect.width,
                  rect.y + rect.height, 8, style.color)
    drawDashedLine(rect.x + rect.width, rect.y + rect.height, rect.x,
                  rect.y + rect.height, 8, style.color)
    drawDashedLine(rect.x, rect.y + rect.height, rect.x, rect.y, 8, style.color)

  # Draw elevation shadow if needed
  if style.elevation > 0:
    drawShadow(rect, Shadow(
      blur: style.elevation,
      spread: style.elevation * 0.5,
      color: style.shadowColor,
      offsetX: style.elevation * 0.5,
      offsetY: style.elevation * 0.5
    ))

# ============================================================================
# Group Boxes
# ============================================================================

proc drawGroupBox*(rect: Rect, title: string, style: GroupBoxStyle) =
  ## Draws a group box with title
  let metrics = measureText(title, style.titleStyle)
  let titleHeight = metrics.height
  let titleY = rect.y
  let contentY = titleY + titleHeight/2

  # Draw the main box slightly lower to accommodate title
  let boxRect = Rect(
    x: rect.x,
    y: contentY,
    width: rect.width,
    height: rect.height - titleHeight/2
  )
  drawPanel(boxRect, style.borderStyle, style.backgroundColor)

  # Calculate title position
  var titleX = rect.x + style.titlePadding
  case style.titlePosition:
  of Center:
    titleX = rect.x + (rect.width - metrics.width)/2
  of Right:
    titleX = rect.x + rect.width - metrics.width - style.titlePadding
  else: discard

  # Draw title background if specified
  if style.titleBackgroundColor.isSome:
    let titleBgRect = Rect(
      x: titleX - style.titlePadding,
      y: titleY,
      width: metrics.width + style.titlePadding * 2,
      height: titleHeight
    )
    drawRect(titleBgRect, style.titleBackgroundColor.get)

  # Draw title
  drawText(title, Rect(
    x: titleX,
    y: titleY,
    width: metrics.width,
    height: titleHeight
  ), style.titleStyle)

  # "Break" the border where the title is
  let breakWidth = metrics.width + style.titlePadding * 2
  let breakStart = case style.titlePosition:
    of Left: titleX - style.titlePadding
    of Center: titleX - style.titlePadding
    of Right: titleX - style.titlePadding

  drawRect(Rect(
    x: breakStart,
    y: contentY - style.borderStyle.width/2,
    width: breakWidth,
    height: style.borderStyle.width
  ), style.backgroundColor)

# ============================================================================
# Cards and Dividers
# ============================================================================

proc drawCard*(rect: Rect, style: BorderStyle,
               backgroundColor: raylib.Color) =
  ## Draws a card with optional elevation shadow
  if style.elevation > 0:
    drawShadow(rect, Shadow(
      blur: style.elevation,
      spread: 0,
      color: style.shadowColor,
      offsetX: 0,
      offsetY: style.elevation * 0.5
    ))

  drawRoundedRect(rect, style.radius, backgroundColor)

proc drawDivider*(rect: Rect, color: raylib.Color, vertical = false) =
  ## Draws a divider line (horizontal or vertical)
  if vertical:
    let x = rect.x + rect.width/2
    drawLine(x, rect.y, x, rect.y + rect.height, color)
  else:
    let y = rect.y + rect.height/2
    drawLine(rect.x, y, rect.x + rect.width, y, color)
