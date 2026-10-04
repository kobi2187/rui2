## SegmentedControl -- a row of mutually exclusive choices in one rounded box.
##
## For a few short options that are all worth seeing at once ("Day | Week |
## Month"). The selected segment is filled with the accent. Click a segment, or
## use Left and Right while it has focus. Where a RadioGroup lists options down
## the page, this is the compact, horizontal version.
##
## ```nim
## SegmentedControl(options = @["Day", "Week", "Month"], initialSelectedIndex = 1,
##                  onSelect = proc(i: int) = ...)
## ```

import rui_core
import rui_drawing
import raylib

proc segmentEdges*(widths: openArray[float32]): seq[float32] =
  ## The left edge of each segment, then the right edge of the last.
  var x = 0.0'f32
  result.add x
  for w in widths:
    x += w
    result.add x

proc segmentAt*(widths: openArray[float32], x: float32): int =
  ## Which segment a point `x` (from the control's left edge) is in; -1 outside.
  let edges = segmentEdges(widths)
  for i in 0 ..< widths.len:
    if x >= edges[i] and x < edges[i + 1]:
      return i
  -1

template segmentWidths(widget: untyped, style: TextStyle, pad: float32): seq[float32] =
  block:
    var ws: seq[float32]
    for o in widget.options:
      ws.add measureText(o, style).width + pad * 2
    ws

definePrimitive(SegmentedControl):
  props:
    options: seq[string] = @[]
    initialSelectedIndex: int = 0
    disabled: bool = false
    intent: ThemeIntent = Default

  state:
    selectedIndex: int

  actions:
    onSelect(index: int)

  init:
    widget.focusable = true

  events:
    on_mouse_down:
      if widget.disabled: return false
      let props = widget.themeProps(widget.intent, crPointer)
      let ws = widget.segmentWidths(props.captionStyle(BLACK, action = true),
                                    props.fieldInset + 4)
      let hit = segmentAt(ws, event.mousePos.x - widget.bounds.x)
      if hit < 0: return false
      if hit != widget.selectedIndex:
        widget.selectedIndex = hit
        if widget.onSelect != nil: widget.onSelect(hit)
      return true

    on_key_down:
      if widget.disabled or not widget.focused: return false
      let step = if event.key == KeyboardKey.Left: -1
                 elif event.key == KeyboardKey.Right: 1
                 else: 0
      if step == 0: return false
      let next = widget.selectedIndex + step
      if next < 0 or next >= widget.options.len: return false   # at the end: let it navigate on
      widget.selectedIndex = next
      if widget.onSelect != nil: widget.onSelect(next)
      return true

  layout:
    let props = widget.themeProps(widget.intent, crPointer)
    let style = props.captionStyle(BLACK, action = true)
    if widget.bounds.width <= 0:
      var total = 0.0'f32
      for w in widget.segmentWidths(style, props.fieldInset + 4): total += w
      widget.bounds.width = total
    if widget.bounds.height <= 0:
      widget.bounds.height = max(currentTheme.controlHeight,
                                 measureText("Ag", style).height + props.fieldInset * 2)

  render:
    let props = widget.themeProps(widget.intent, crPointer, disabled = widget.disabled)
    let ink = props.foregroundColor.get(BLACK)
    let accent = props.activeColor.get(ink)
    let onAccent = currentTheme.getThemeProps(ThemeIntent.Info).foregroundColor.get(WHITE)
    let style = props.captionStyle(ink, action = true)
    let radius = props.cornerRadius.get(4.0'f32)
    let stroke = props.strokeWidth
    let ws = widget.segmentWidths(style, props.fieldInset + 4)
    let edges = segmentEdges(ws)
    # Scale the segments to the width the control was given.
    let scale = if edges[^1] > 0: widget.bounds.width / edges[^1] else: 1.0'f32
    drawBox(widget.bounds, radius, props.backgroundColor.get(WHITE),
            props.borderColor.get(ink), stroke)
    for i, o in widget.options:
      let x0 = widget.bounds.x + edges[i] * scale
      let seg = Rect(x: x0, y: widget.bounds.y, width: ws[i] * scale, height: widget.bounds.height)
      var text = style
      if i == widget.selectedIndex:
        drawBox(Rect(x: seg.x + stroke, y: seg.y + stroke, width: seg.width - stroke * 2,
                     height: seg.height - stroke * 2), max(0.0'f32, radius - stroke), accent, accent, 0)
        text.color = onAccent
      elif i > 0 and i - 1 != widget.selectedIndex:
        drawRect(Rect(x: seg.x, y: seg.y + seg.height * 0.2, width: 1, height: seg.height * 0.6),
                 props.borderColor.get(ink))
      let tw = measureText(o, text).width
      drawStyledText(o, seg.x + (seg.width - tw) / 2, seg.y + (seg.height - text.fontSize) / 2, text)
    if widget.focused:
      drawBox(Rect(x: widget.bounds.x - 3, y: widget.bounds.y - 3, width: widget.bounds.width + 6,
                   height: widget.bounds.height + 6), radius + 3, Color(r: 0, g: 0, b: 0, a: 0),
              props.focusColor.get(accent), props.focusRingWidth.get(2.0'f32))
