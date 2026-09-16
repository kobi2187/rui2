## ProgressBar Widget - RUI2
##
## A filled bar over 0..`maxValue`, with an optional caption.
##
## Two things here were promises the widget did not keep, and now does:
##
## `format` and `textLeft` were declared props that nothing read -- `render`
## hard-coded "<n>%" whatever you passed. `formatProgress` below honours them,
## and is a plain proc so the formatting is testable without a window.
##
## `onComplete` fired from inside `render`, on every frame the bar was full.
## A handler that opened a dialog opened one per repaint. It now fires on the
## transition into completion and re-arms if the value drops back, which is
## what a completion callback has to mean.

import rui_core
import rui_drawing
import std/[options, strutils]

import raylib

type ProgressFormat* = object
  ## A parsed `%.<n>f` or `%.<n>f%%` caption spec.
  decimals*: int
  asPercent*: bool
    ## true for the `%%` forms: show the percentage of maxValue, not the value.

proc parseProgressFormat*(format: string): Option[ProgressFormat] =
  ## `none` for anything that is not a spec, which the caller then uses
  ## literally -- so passing "Loading" gets you "Loading".
  if not format.startsWith("%."):
    return none(ProgressFormat)
  let fIdx = format.find('f', 2)
  if fIdx < 0:
    return none(ProgressFormat)
  try:
    some(ProgressFormat(decimals: parseInt(format[2 ..< fIdx]),
                        asPercent: format.endsWith("%%")))
  except ValueError:
    none(ProgressFormat)

proc render*(spec: ProgressFormat, value, maxValue: float): string =
  let shown = if not spec.asPercent: value
              elif maxValue == 0: 0.0
              else: value / maxValue * 100.0
  result = formatFloat(shown, ffDecimal, spec.decimals)
  if spec.decimals == 0:
    # formatFloat leaves a trailing point at zero decimals: "50." not "50".
    result.removeSuffix('.')
  if spec.asPercent:
    result.add('%')

proc formatProgress*(value, maxValue: float, format: string): string =
  ## Render the caption for a progress value.
  ##
  ## `format` is a small printf-ish subset, because that is what the shipped
  ## default ("%.0f%%") already looked like: `%.<n>f` prints the raw value to
  ## <n> decimals, and a trailing `%%` prints the percentage of maxValue
  ## instead. Anything else is used literally.
  let spec = parseProgressFormat(format)
  if spec.isNone: format else: spec.get().render(value, maxValue)

definePrimitive(ProgressBar):
  props:
    initialValue: float = 0.0
    maxValue: float = 100.0
    showText: bool = true
    format: string = "%.0f%%"
    textLeft: string = ""
    disabled: bool = false
    intent: ThemeIntent = Default

  state:
    value: float
    # completed latches, so onComplete fires once per completion rather than
    # once per frame the bar happens to be full.
    completed: bool

  actions:
    onComplete()

  layout:
    # Completion is checked here rather than in `render` for two reasons: it is
    # logic rather than drawing, and `render` needs a GL context, so a bar in a
    # headless test could never reach it.
    #
    # Fire on the transition, not on every frame the bar happens to be full,
    # and re-arm if the value drops back so a reused bar completes again. The
    # old code called onComplete from inside render on every repaint -- a
    # handler that opened a dialog opened one per frame.
    let isComplete = widget.value >= widget.maxValue
    if isComplete and not widget.completed:
      if widget.onComplete.isSome:
        widget.onComplete.get()()
    widget.completed = isComplete

    if widget.bounds.height <= 0:
      let style = TextStyle(fontFamily: "", fontSize: 12.0, color: BLACK,
                            bold: false, italic: false, underline: false)
      widget.bounds.height = max(20.0f32, measureText("0%", style).height + 4)
    if widget.bounds.width <= 0:
      widget.bounds.width = 200.0f32

  render:
    let state = if widget.disabled: Disabled else: Normal
    let props = currentTheme.getThemeProps(widget.intent, state)

    let progress = (widget.value / widget.maxValue).float32
    drawProgressBar(widget.bounds, progress, props)

    if widget.showText:
      let textColor = props.foregroundColor.get(Color(r: 60, g: 60, b: 60, a: 255))
      let displayText = widget.textLeft &
                        formatProgress(widget.value, widget.maxValue, widget.format)
      drawText(displayText, widget.bounds.x + widget.bounds.width / 2, widget.bounds.y + (widget.bounds.height - 14) / 2, 14.0, textColor, centered = true)

