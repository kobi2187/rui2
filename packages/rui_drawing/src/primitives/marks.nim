## Marks: small theme-free drawings many widgets use.
##
## A check mark, an arrow glyph, an alert symbol, a dashed focus outline, a
## disabled veil, a scroll thumb's geometry, a group box frame, and two colour
## helpers. They take their colours as arguments; the themed parts that choose
## those colours are in widget_primitives.nim. (Gathered from the old controls,
## indicators and panels modules, whose other helpers nothing used.)

import raylib
import math, options
import rui_core
import shapes
import text

export types, options


proc dimColor*(color: raylib.Color, factor: float32): raylib.Color =
  ## Scales a colour toward black, leaving it fully opaque.
  ##
  ## This was `fadeColor`, private, documented as "0.0 = transparent, 1.0 =
  ## opaque" -- which is what `withAlpha` below does. It never touched alpha;
  ## it multiplies the channels. The old name is why basic/scrollbar.nim
  ## inlined its own alpha maths rather than calling it: exporting the proc
  ## would not have helped, because it does a different thing.
  raylib.Color(
    r: uint8(color.r.float32 * factor),
    g: uint8(color.g.float32 * factor),
    b: uint8(color.b.float32 * factor),
    a: color.a
  )

proc withAlpha*(color: raylib.Color, factor: float32): raylib.Color =
  ## Scales a colour's opacity, leaving its hue alone.
  ## 0.0 is fully transparent, 1.0 leaves it as it was.
  raylib.Color(r: color.r, g: color.g, b: color.b,
               a: uint8(float32(color.a) * factor))

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

  drawSmoothLine(points[0], points[1], thickness, color)
  drawSmoothLine(points[1], points[2], thickness, color)

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

proc scrollThumb*(track: Rect, contentSize, viewSize, offset: float32,
                  minThumb = 24.0'f32): Rect =
  ## The thumb inside `track`, along its long side: its length is the visible
  ## share of the content, its position the scrolled share of what is left.
  ## Content that fits fills the track, and nothing divides by zero.
  let vertical = track.height >= track.width
  let length = if vertical: track.height else: track.width
  let ratio = if contentSize <= 0: 1.0'f32 else: clamp(viewSize / contentSize, 0.0, 1.0)
  let thumb = min(length, max(length * ratio, minThumb))
  let slack = contentSize - viewSize
  let t = if slack <= 0: 0.0'f32 else: clamp(offset / slack, 0.0, 1.0)
  let along = (length - thumb) * t
  if vertical:
    Rect(x: track.x, y: track.y + along, width: track.width, height: thumb)
  else:
    Rect(x: track.x + along, y: track.y, width: thumb, height: track.height)

type ArrowDirection* {.pure.} = enum
  ## `{.pure.}` so the fields stay qualified. Bare Up/Down/Left/Right in every
  ## module that imports rui_drawing collided with naylib's KeyboardKey, which
  ## is what forced `KeyboardKey.Down` on the keyboard-navigation tests. An
  ## arrow glyph's direction is named four times in the whole repo; a key is
  ## named in every widget that reads one.
  Up, Down, Left, Right

export ArrowDirection

proc drawArrow*(rect: Rect, direction: ArrowDirection,
                color: raylib.Color, thickness = 2.0f32) =
  ## Draws a directional arrow
  let center = (x: rect.x + rect.width/2, y: rect.y + rect.height/2)
  let size = min(rect.width, rect.height) * 0.4

  var points: array[3, Vector2]
  case direction:
  of ArrowDirection.Up:
    points = [
      Vector2(x: center.x, y: center.y - size),
      Vector2(x: center.x - size, y: center.y + size),
      Vector2(x: center.x + size, y: center.y + size)
    ]
  of ArrowDirection.Down:
    points = [
      Vector2(x: center.x, y: center.y + size),
      Vector2(x: center.x - size, y: center.y - size),
      Vector2(x: center.x + size, y: center.y - size)
    ]
  of ArrowDirection.Left:
    points = [
      Vector2(x: center.x - size, y: center.y),
      Vector2(x: center.x + size, y: center.y - size),
      Vector2(x: center.x + size, y: center.y + size)
    ]
  of ArrowDirection.Right:
    points = [
      Vector2(x: center.x + size, y: center.y),
      Vector2(x: center.x - size, y: center.y - size),
      Vector2(x: center.x - size, y: center.y + size)
    ]

  drawTriangleAnyWinding(points[0], points[1], points[2], color)

type
  AlertLevel* = enum
    alInfo, alAlert, alCritical     # prefixed for the same reason (ThemeIntent.Info)

proc drawAlertSymbol*(rect: Rect, level: AlertLevel,
                      color: Option[raylib.Color] = none(raylib.Color)) =
  ## Draws alert symbols (info, warning, critical)
  let size = min(rect.width, rect.height)
  let center = (x: rect.x + rect.width/2, y: rect.y + rect.height/2)
  let symbolColor = if color.isSome: color.get else:
    case level
    of alInfo: raylib.Color(r: 33, g: 150, b: 243, a: 255)      # Material Blue
    of alAlert: raylib.Color(r: 255, g: 152, b: 0, a: 255)      # Material Orange
    of alCritical: raylib.Color(r: 244, g: 67, b: 54, a: 255)   # Material Red

  case level
  of alInfo:
    # Circle with 'i'
    drawCircleLines(int32(center.x), int32(center.y), size/2, symbolColor)
    drawCircle(int32(center.x), int32(center.y - size * 0.2), 2, symbolColor)
    drawLine(
      Vector2(x: center.x, y: center.y - size * 0.1),
      Vector2(x: center.x, y: center.y + size * 0.2),
      2, symbolColor
    )

  of alAlert, alCritical:
    # Octagon for critical, circle for alert
    if level == alCritical:
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

proc drawDisabledOverlay*(rect: Rect, canvas: raylib.Color) =
  ## Fades a disabled control toward the canvas behind it. A fixed grey read as a
  ## light block on a dark theme and a dark smudge on a light one; the canvas is
  ## the colour the control is fading into on any theme.
  drawRect(rect, raylib.Color(r: canvas.r, g: canvas.g, b: canvas.b, a: 160))

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

  # "Break" the border where the title is
  let breakWidth = metrics.width + style.titlePadding * 2
  let breakStart = case style.titlePosition:
    of Left: titleX - style.titlePadding
    of Center: titleX - style.titlePadding
    of Right: titleX - style.titlePadding

  drawRect(Rect(
    x: breakStart,
    y: contentY,                     # outlines are drawn inside the box
    width: breakWidth,
    height: style.borderStyle.width
  ), style.backgroundColor)

  # Draw title
  drawText(title, Rect(
    x: titleX,
    y: titleY,
    width: metrics.width,
    height: titleHeight
  ), style.titleStyle)
