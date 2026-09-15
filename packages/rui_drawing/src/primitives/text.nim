## Text Rendering Primitives
##
## Composable functions for text measurement and rendering
## Part of the refactored drawing_primitives module

import raylib
import strutils
import rui_core
import shapes      # For drawLine (underline support)
import ../pango_text  # Real font rasterisation and metrics

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

proc pangoFont*(style: TextStyle): string {.inline.} =
  ## Translate a TextStyle into a Pango font description.
  fontDescString(style.fontFamily, style.fontSize, style.bold, style.italic)

proc measureText*(text: string, style: TextStyle): TextMetrics =
  ## Measure text with the real font.
  ##
  ## This used to call raylib.measureText, which measures the built-in 10-pixel
  ## bitmap font and reports the *requested* size as the height, with the
  ## baseline guessed at 0.8 of that. Both were wrong for any real font, which
  ## is why labels were mis-centred and containers could not size to content.
  let m = measureTextPango(text, style.pangoFont)
  result.width = m.width
  result.height = m.height
  result.lineHeight = m.height
  result.baseline = m.baseline

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

  # Pango rasterises the glyphs into an alpha mask; the colour is applied as a
  # draw tint, so the cached texture is colour-independent.
  let y = rect.y + (rect.height - metrics.height) / 2
  drawTextPango(text, x, y, style.pangoFont, style.color)

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
  ## Draw multi-line text, wrapped to the layout rect.
  ##
  ## Wrapping is delegated to Pango rather than the previous split-on-spaces
  ## loop, which could not break Thai or CJK (no spaces), mismeasured any
  ## proportional font, and re-measured the accumulated line once per word.
  if layout.text.len == 0:
    return

  let font = layout.style.pangoFont
  let wrapWidth = if layout.wrap and layout.rect.width > 0:
                    layout.rect.width.int32
                  else:
                    -1'i32
  let m = measureTextPango(layout.text, font, wrapWidth)

  var x = layout.rect.x
  case layout.align
  of TextAlign.Center: x = layout.rect.x + (layout.rect.width - m.width) / 2
  of TextAlign.Right:  x = layout.rect.x + layout.rect.width - m.width
  else: discard

  drawTextPango(layout.text, x, layout.rect.y, font, layout.style.color,
                wrapWidth)

proc measureTextWrapped*(text: string, style: TextStyle,
                         maxWidth: float32): TextMetrics =
  ## Metrics for text wrapped to `maxWidth`. Containers use this to size
  ## themselves to their content.
  let m = measureTextPango(text, style.pangoFont, maxWidth.int32)
  result.width = m.width
  result.height = m.height
  result.lineHeight = m.height
  result.baseline = m.baseline

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
