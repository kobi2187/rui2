## Skeleton -- the shape of what is coming, while it loads: grey bars where
## the text will be, a circle where the picture will be, gently pulsing.
##
## ```nim
## ui:
##   Row(spacing = 12):
##     Skeleton(shape = skCircle).size(40, 40)
##     Skeleton(shape = skText, lines = 3).size(240, 0)
## ```
##
## Swap it for the real widget when the data arrives (an IndexedStack, or set
## `visible`). The pulse is a continuous effect: with the user's motion set to
## none it stays still (animation.nim `effectsAllowed`). `drawSkeleton` is the
## drawing, for a primitive that shows placeholders of its own (a list's rows
## still being fetched).

import rui_core
import rui_drawing
import std/[options, monotimes, times, math]
import raylib

type SkeletonShape* = enum
  skBlock          ## a rounded rectangle: a card, a picture
  skCircle         ## an avatar
  skText           ## lines of text, the last one shorter

const PulseSeconds = 1.6

proc pulseAt*(seconds: float): float32 =
  ## 0 .. 1 .. 0 over PulseSeconds: how far the pulse is to its lightest.
  float32(0.5 - 0.5 * cos(seconds / PulseSeconds * 2 * PI))

proc textLines*(area: Rect, lines: int, lineHeight, gap: float32): seq[Rect] =
  ## The bars for `lines` of text in `area`: full width but the last (60%).
  for i in 0 ..< max(1, lines):
    let w = if i == max(1, lines) - 1 and lines > 1: area.width * 0.6 else: area.width
    result.add Rect(x: area.x, y: area.y + float32(i) * (lineHeight + gap),
                    width: w, height: lineHeight)

proc drawSkeleton*(area: Rect, shape: SkeletonShape, pulse: float32, lines = 3,
                   lineHeight = 12'f32, gap = 8'f32,
                   props: ThemeProps = currentTheme.getThemeProps(Default)) =
  ## The placeholder in `area`, `pulse` (0 .. 1) of the way to its lightest.
  let ink = props.foregroundColor.get(BLACK)
  let c = ink.withAlpha(0.07 + 0.07 * (1 - pulse))
  let r = props.cornerRadius.get(4.0)
  case shape
  of skBlock: discard drawSdfBox(area, r, 0, c, c)
  of skCircle:
    let d = min(area.width, area.height)
    discard drawSdfBox(Rect(x: area.x + (area.width - d) / 2, y: area.y + (area.height - d) / 2,
                            width: d, height: d), d / 2, 0, c, c)
  of skText:
    for bar in textLines(area, lines, lineHeight, gap):
      discard drawSdfBox(bar, min(r, lineHeight / 2), 0, c, c)

definePrimitive(Skeleton):
  props:
    shape: SkeletonShape = skBlock
    lines: int = 3                  ## skText
    lineHeight: float32 = 12.0
    gap: float32 = 8.0
    intent: ThemeIntent = Default

  state:
    born: MonoTime

  init:
    widget.born = getMonoTime()

  layout:
    if widget.bounds.width <= 0: widget.bounds.width = 200
    if widget.bounds.height <= 0:
      widget.bounds.height =
        case widget.shape
        of skText: float32(max(1, widget.lines)) * (widget.lineHeight + widget.gap) - widget.gap
        of skCircle: widget.bounds.width
        of skBlock: 80

  render:
    let moving = effectsAllowed()
    let pulse = if moving: pulseAt(float((getMonoTime() - widget.born).inMilliseconds) / 1000)
                else: 0'f32
    drawSkeleton(widget.bounds, widget.shape, pulse, widget.lines, widget.lineHeight,
                 widget.gap, currentTheme.getThemeProps(widget.intent, Normal))
    if moving: widget.repaintAfter(1.0 / 30.0)   # the next step; stops when it is hidden
