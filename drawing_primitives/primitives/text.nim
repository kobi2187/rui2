## Text Rendering Primitives
##
## Composable functions for text measurement and rendering
## Part of the refactored drawing_primitives module

import raylib
import strutils
import ../../core/types
import shapes  # For drawLine (underline support)

export types

type
  TextStyle* = object
    fontFamily*: string
    fontSize*: float32
    color*: raylib.Color
    bold*: bool
    italic*: bool
    underline*: bool

  TextAlign* = enum
    Left, Center, Right

  TextLayout* = object
    text*: string
    rect*: Rect
    style*: TextStyle
    align*: TextAlign
    wrap*: bool

  TextMetrics* = object
    width*, height*: float32
    lineHeight*: float32
    baseline*: float32

# ============================================================================
# Text Measurement
# ============================================================================

proc measureText*(text: string, style: TextStyle): TextMetrics =
  ## Measures text dimensions with given style
  let fontSize = int32(style.fontSize)
  result.width = float32(raylib.measureText(text, fontSize))
  result.height = style.fontSize
  result.lineHeight = style.fontSize * 1.2  # Standard line height
  result.baseline = style.fontSize * 0.8    # Approximate baseline

proc measureTextLine*(text: string, style: TextStyle, maxWidth: float32): tuple[
  fits: bool, breakPos: int] =
  ## Measures text and finds word break position if it exceeds width
  var lastSpace = -1
  var currentWidth = 0.0f32

  for i, c in text:
    if c == ' ': lastSpace = i
    currentWidth = measureText(text[0..i], style).width

    if currentWidth > maxWidth:
      return (false, if lastSpace > 0: lastSpace else: i)

  return (true, text.len)

# ============================================================================
# Basic Text Drawing
# ============================================================================

proc drawText*(text: string, rect: Rect, style: TextStyle,
    align = TextAlign.Left) =
  ## Draws single-line text with alignment
  let metrics = measureText(text, style)
  var x = rect.x

  case align:
  of TextAlign.Center:
    x = rect.x + (rect.width - metrics.width) / 2
  of TextAlign.Right:
    x = rect.x + rect.width - metrics.width
  else: discard

  # Basic style rendering
  raylib.drawText(text, int32(x), int32(rect.y + (rect.height - metrics.height) / 2),
    int32(style.fontSize),
    style.color
  )

  # Underline if needed
  if style.underline:
    let underlineY = rect.y + (rect.height + metrics.height) / 2
    drawLine(
      x, underlineY,
      x + metrics.width, underlineY,
      style.color,
      style.fontSize * 0.05
    )

# ============================================================================
# Multi-line Text
# ============================================================================

proc drawTextLayout*(layout: TextLayout) =
  ## Draws multi-line text with wrapping
  var y = layout.rect.y
  let spaceWidth = measureText(" ", layout.style).width
  var currentLine = ""
  var words: seq[string] = layout.text.split(' ')

  while words.len > 0:
    let nextWord = words[0]
    let testLine = if currentLine.len > 0:
                    currentLine & " " & nextWord
                   else:
                    nextWord

    let metrics = measureText(testLine, layout.style)
    if metrics.width <= layout.rect.width:
      currentLine = testLine
      words.delete(0)
    else:
      if currentLine.len > 0:
        # Draw current line
        drawText(currentLine,
                Rect(x: layout.rect.x,
                     y: y,
                     width: layout.rect.width,
                     height: layout.style.fontSize),
                layout.style,
                layout.align)
        y += layout.style.fontSize * 1.2
        currentLine = ""
      else:
        # Word is too long, must split
        currentLine = nextWord
        words.delete(0)

  # Draw last line
  if currentLine.len > 0:
    drawText(currentLine,
            Rect(x: layout.rect.x,
                 y: y,
                 width: layout.rect.width,
                 height: layout.style.fontSize),
            layout.style,
            layout.align)

proc drawEllipsis*(text: string, rect: Rect, style: TextStyle) =
  ## Draws text with ellipsis if it doesn't fit
  const ellipsis = "..."
  let ellipsisWidth = measureText(ellipsis, style).width
  let availableWidth = rect.width - ellipsisWidth

  var fitChars = 0
  var currentWidth = 0.0f32

  for i, c in text:
    let charWidth = measureText($c, style).width
    if currentWidth + charWidth > availableWidth:
      break
    currentWidth += charWidth
    fitChars = i + 1

  if fitChars < text.len:
    let truncated = text[0..<fitChars] & ellipsis
    drawText(truncated, rect, style)
  else:
    drawText(text, rect, style)

# ============================================================================
# Selection and Cursor
# ============================================================================

proc drawTextSelection*(rect: Rect, selStart, selEnd: int,
                       text: string, style: TextStyle,
                       selectionColor: raylib.Color) =
  ## Draws text selection highlight
  let startMetrics = measureText(text[0..<selStart], style)
  let selectionMetrics = measureText(text[selStart..<selEnd], style)

  shapes.drawRect(
    Rect(
      x: rect.x + startMetrics.width,
      y: rect.y,
      width: selectionMetrics.width,
      height: rect.height
    ),
    selectionColor
  )

  # Draw text on top of selection
  drawText(text, rect, style)

proc drawCursor*(rect: Rect, position: int, text: string,
                style: TextStyle, blinkPhase: float32) =
  ## Draws text cursor with blinking
  if blinkPhase < 0.5:
    let cursorX = rect.x + measureText(text[0..<position], style).width
    drawLine(
      cursorX, rect.y,
      cursorX, rect.y + style.fontSize,
      style.color,
      2.0
    )
