## TimePicker -- a time of day, edited in place: "14:30".
##
## Click the hours or the minutes, or move between them with Left/Right; Up and
## Down (or the wheel) step the part; digits type it ("1", "4" -> 14). With
## `use24h = false` there is a third part, AM/PM. The value is text, always
## 24-hour "HH:MM" whatever it shows, so it binds like any string:
## `TimePicker(value = <-> alarm)`. `minuteStep` sets how far Up/Down move the
## minutes. `onChange(value)` reports changes.

import rui_core
import rui_drawing
import std/[options, strutils]
import picker_values
from raylib import KeyboardKey

const AmPm = 2

proc partCount(use24h: bool): int = (if use24h: 2 else: 3)

proc minutesOf(value: string): int =
  let t = parseTime(value)
  if t.isSome: t.get else: 0

proc partWidths(use24h: bool, style: TextStyle): seq[float32] =
  result = @[measureText("00", style).width, measureText("00", style).width]
  if not use24h: result.add measureText("PM", style).width

proc partAt*(widths: seq[float32], gap, x: float32): int =
  ## Which part a press at `x` (relative to the text's left edge) lands on.
  var edge = 0.0'f32
  for i, w in widths:
    edge += w + gap / 2
    if x < edge: return i
    edge += gap / 2
  widths.high

proc stepPart*(minutes, part, steps, minuteStep: int, use24h: bool): int =
  ## `minutes` with one part moved `steps` times: hours wrap round the day,
  ## minutes wrap within the hour (no carry), AM/PM flips twelve hours.
  let hour = minutes div 60
  let minute = minutes mod 60
  case part
  of 0: ((hour + steps) mod 24 + 24) mod 24 * 60 + minute
  of 1:
    let stepBy = max(1, minuteStep)
    hour * 60 + ((minute + steps * stepBy) mod 60 + 60) mod 60
  else: (minutes + 12 * 60) mod (24 * 60)

definePrimitive(TimePicker):
  props:
    initialValue: string = "00:00"
    use24h: bool = true
    minuteStep: int = 1
    disabled: bool = false
    intent: ThemeIntent = Default

  state:
    value: string
    part: int
    typed: string

  actions:
    onChange(value: string)

  init:
    widget.focusable = true
    if parseTime(widget.value).isNone: widget.value = formatTime(0)

  events:
    on_mouse_down:
      if widget.disabled: return false
      let props = widget.themeProps(widget.intent, crText)
      let style = props.captionStyle(BLACK)
      let widths = partWidths(widget.use24h, style)
      widget.part = partAt(widths, measureText(":", style).width * 2,
                           event.mousePos.x - widget.bounds.x - props.fieldInset)
      widget.typed = ""
      widget.isDirty = true
      return true

    on_key_down:
      if widget.disabled or not widget.focused: return false
      let parts = partCount(widget.use24h)
      var next = minutesOf(widget.value)
      case event.key
      of KeyboardKey.Left:
        widget.part = max(0, widget.part - 1); widget.typed = ""
        widget.isDirty = true
        return true
      of KeyboardKey.Right:
        widget.part = min(parts - 1, widget.part + 1); widget.typed = ""
        widget.isDirty = true
        return true
      of KeyboardKey.Up: next = stepPart(next, widget.part, 1, widget.minuteStep, widget.use24h)
      of KeyboardKey.Down: next = stepPart(next, widget.part, -1, widget.minuteStep, widget.use24h)
      else: return false
      widget.typed = ""
      let text = formatTime(next)
      if text != widget.value:
        widget.value = text
        widget.isDirty = true
        widget.layoutDirty = true
        if widget.onChange != nil: widget.onChange(text)
      return true

    on_char:
      if widget.disabled or not widget.focused: return false
      let r = event.typedRune
      if r.int notin ord('0') .. ord('9') or widget.part == AmPm: return false
      widget.typed = (widget.typed & char(r.int))[^min(2, widget.typed.len + 1) .. ^1]
      let n = parseInt(widget.typed)
      var minutes = minutesOf(widget.value)
      if widget.part == 0:
        if n > 23: widget.typed = $char(r.int); minutes = (parseInt(widget.typed)) * 60 + minutes mod 60
        else: minutes = n * 60 + minutes mod 60
        if widget.typed.len == 2 or parseInt(widget.typed) > 2:
          widget.part = 1; widget.typed = ""
      else:
        if n > 59: widget.typed = $char(r.int)
        minutes = minutes div 60 * 60 + parseInt(widget.typed)
        if widget.typed.len == 2 or parseInt(widget.typed) > 5: widget.typed = ""
      let text = formatTime(minutes)
      if text != widget.value:
        widget.value = text
        if widget.onChange != nil: widget.onChange(text)
      widget.isDirty = true
      return true

    on_mouse_wheel:
      if widget.disabled or not widget.focused or event.wheelDelta == 0: return false
      let text = formatTime(stepPart(minutesOf(widget.value), widget.part,
        (if event.wheelDelta > 0: 1 else: -1), widget.minuteStep, widget.use24h))
      if text != widget.value:
        widget.value = text
        widget.isDirty = true
        if widget.onChange != nil: widget.onChange(text)
      return true

  layout:
    let props = widget.themeProps(widget.intent, crText, disabled = widget.disabled)
    let style = props.captionStyle(BLACK)
    if widget.bounds.height <= 0:
      let line = measureText("Ag", style).height
      widget.bounds.height = max(currentTheme.controlHeight, line + 2 * props.fieldInset)
    if widget.bounds.width <= 0:
      let widths = partWidths(widget.use24h, style)
      var total = 0.0'f32
      for w in widths: total += w
      widget.bounds.width = total + measureText(":", style).width * 4 + props.fieldInset * 2 + 8

  render:
    let props = widget.themeProps(widget.intent, crText, disabled = widget.disabled)
    drawInteractiveBox(widget.bounds, props, hovered = widget.hovered, focused = widget.focused)
    let style = props.captionStyle(props.foregroundColor.get(BLACK))
    let shown = formatTime(minutesOf(widget.value), widget.use24h)
    let pieces = shown.replace(" ", ":").split(':')       # "02", "30" [, "PM"]
    let widths = partWidths(widget.use24h, style)
    let colon = measureText(":", style).width
    var x = widget.bounds.x + props.fieldInset
    let y = widget.bounds.y + (widget.bounds.height - style.fontSize) / 2
    for i, piece in pieces:
      if widget.focused and i == widget.part:
        drawBox(Rect(x: x - 2, y: y - 2, width: widths[i] + 4, height: style.fontSize + 4),
                3, props.activeColor.get(Color(r: 80, g: 120, b: 255, a: 60)).withAlpha(0.3'f32),
                Color(r: 0, g: 0, b: 0, a: 0), 0)
      drawStyledText(piece, x, y, style)
      x += widths[i]
      if i < 2:
        if i == 0: drawStyledText(":", x + colon / 2, y, style)
        x += colon * 2
