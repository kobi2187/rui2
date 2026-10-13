## ColorPicker -- a colour chosen from a saturation/value square and a hue bar
## that drop down from a swatch field.
##
## The value is hex text ("#3366cc"), so it binds like any string:
## `ColorPicker(value = <-> accent)`. Drag in the square for saturation (left to
## right) and brightness (down to up), in the bar for hue. From the keyboard
## (focused) Left/Right turn the hue, Up/Down change the brightness,
## Enter/Space/F4 open and close the picker, Escape closes it. `onChange(value)`
## fires on real changes.

import rui_core
import rui_drawing
import std/[options, math]
import picker_values, popup_field
from raylib import KeyboardKey, drawRectangleGradientH, drawRectangleGradientV

type ColorSource* = proc(): Hsv {.closure.}

proc drawHueBar(r: Rect) =
  let segments = 6
  for i in 0 ..< segments:
    let a = Hsv(h: float32(i) * 60, s: 1, v: 1).toColor
    let b = Hsv(h: float32(i + 1) * 60, s: 1, v: 1).toColor
    let x0 = r.x + r.width * float32(i) / float32(segments)
    let x1 = r.x + r.width * float32(i + 1) / float32(segments)
    drawRectangleGradientH(int32(x0), int32(r.y), int32(x1) - int32(x0) + 1, int32(r.height), a, b)

definePrimitive(ColorPopup):
  props:
    intent: ThemeIntent = Default

  state:
    source: ColorSource
    dragging: int          # 0 none, 1 the square, 2 the hue bar

  actions:
    onColor(hsv: Hsv)

  init:
    widget.floating = true

  events:
    on_mouse_down:
      if widget.source == nil: return true
      let p = event.mousePos
      if colSvRect(widget.bounds).contains(p.x, p.y): widget.dragging = 1
      elif colHueRect(widget.bounds).contains(p.x, p.y): widget.dragging = 2
      else: return true
      let cur = widget.source()
      if widget.onColor != nil:
        widget.onColor(if widget.dragging == 1: svAt(widget.bounds, p.x, p.y, cur.h)
                       else: Hsv(h: hueAt(widget.bounds, p.x), s: cur.s, v: cur.v))
      return true

    on_mouse_move:
      if widget.dragging == 0 or widget.source == nil: return true
      let p = event.mousePos
      let cur = widget.source()
      if widget.onColor != nil:
        widget.onColor(if widget.dragging == 1: svAt(widget.bounds, p.x, p.y, cur.h)
                       else: Hsv(h: hueAt(widget.bounds, p.x), s: cur.s, v: cur.v))
      return true

    on_mouse_up:
      widget.dragging = 0
      return true

  render:
    if widget.source == nil: return
    let hsv = widget.source()
    let props = currentTheme.getThemeProps(widget.intent, Normal)
    drawThemedBackground(widget.bounds, props)
    let sv = colSvRect(widget.bounds)
    let pure = Hsv(h: hsv.h, s: 1, v: 1).toColor
    drawRectangleGradientH(int32(sv.x), int32(sv.y), int32(sv.width), int32(sv.height), WHITE, pure)
    drawRectangleGradientV(int32(sv.x), int32(sv.y), int32(sv.width), int32(sv.height),
                           Color(r: 0, g: 0, b: 0, a: 0), BLACK)
    let marker = Rect(x: sv.x + hsv.s * sv.width - 6, y: sv.y + (1 - hsv.v) * sv.height - 6,
                      width: 12, height: 12)
    drawBox(marker, 6, Color(r: 0, g: 0, b: 0, a: 0), WHITE, 2)
    let bar = colHueRect(widget.bounds)
    drawHueBar(bar)
    let hx = bar.x + hsv.h / 360 * bar.width
    drawBox(Rect(x: hx - 3, y: bar.y - 2, width: 6, height: bar.height + 4), 2,
            Color(r: 0, g: 0, b: 0, a: 0), WHITE, 2)
    let style = props.captionStyle(props.foregroundColor.get(BLACK))
    drawStyledText(formatHexColor(hsv.toColor), widget.bounds.x + ColPad,
                   bar.y + bar.height + ColPad + (ColLabelH - style.fontSize) / 2, style)
    drawThemedBorder(widget.bounds, props)

template applyHsv(widget: untyped, candidate: Hsv) =
  block:
    let next = candidate
    widget.hsv = next
    let text = formatHexColor(next.toColor)
    if text != widget.value:
      widget.value = text
      widget.isDirty = true
      widget.layoutDirty = true
      if widget.onChange != nil: widget.onChange(text)
    widget.popup.isDirty = true

proc startHsv(value: string): Hsv =
  let c = parseHexColor(value)
  if c.isSome: c.get.toHsv else: Hsv(h: 210, s: 0.7, v: 0.8)

definePrimitive(ColorPicker):
  props:
    initialValue: string = "#3366cc"
    disabled: bool = false
    intent: ThemeIntent = Default

  state:
    value: string
    isOpen: bool
    hsv: Hsv                 # kept apart from the text so hue survives zero saturation
    popup: ColorPopup

  actions:
    onChange(value: string)

  init:
    widget.focusable = true
    let field = widget
    widget.hsv = startHsv(widget.value)
    if parseHexColor(widget.value).isNone: widget.value = formatHexColor(widget.hsv.toColor)
    widget.popup = newColorPopup(intent = widget.intent)
    widget.popup.source = proc(): Hsv = field.hsv
    widget.popup.onColor = proc(hsv: Hsv) = field.applyHsv(hsv)
    widget.addChild widget.popup

  events:
    on_mouse_down: return widget.popupFieldClick(widget.popup)

    on_key_down:
      if widget.disabled or not widget.focused: return false
      if widget.popupToggleKey(widget.popup, event): return true
      var next = widget.hsv
      case event.key
      of KeyboardKey.Left: next.h = (next.h + 355) mod 360.0'f32
      of KeyboardKey.Right: next.h = (next.h + 5) mod 360.0'f32
      of KeyboardKey.Up: next.v = min(1.0'f32, next.v + 0.05)
      of KeyboardKey.Down: next.v = max(0.0'f32, next.v - 0.05)
      else: return false
      widget.applyHsv(next)
      return true

  layout:
    let props = widget.themeProps(widget.intent, crText, disabled = widget.disabled)
    let style = props.captionStyle(BLACK)
    if widget.bounds.height <= 0:
      let line = measureText("Ag", style).height
      widget.bounds.height = max(currentTheme.controlHeight, line + 2 * props.fieldInset)
    if widget.bounds.width <= 0:
      widget.bounds.width = measureText("#000000", style).width + props.fieldInset * 3 +
                            widget.bounds.height + 24
    widget.popup.bounds = popupRect(widget.bounds, ColWidth, ColHeight)

  render:
    let props = widget.themeProps(widget.intent, crText, disabled = widget.disabled,
                                  pressed = widget.isOpen)
    drawInteractiveBox(widget.bounds, props, hovered = widget.hovered, focused = widget.focused)
    let swatchSize = widget.bounds.height - props.fieldInset * 2
    let swatch = Rect(x: widget.bounds.x + props.fieldInset, y: widget.bounds.y + props.fieldInset,
                      width: swatchSize, height: swatchSize)
    let color = parseHexColor(widget.value).get(BLACK)
    drawBox(swatch, 3, color, props.borderColor.get(GRAY), 1)
    let style = props.captionStyle(props.foregroundColor.get(BLACK))
    drawStyledText(widget.value, swatch.x + swatchSize + props.fieldInset,
                   widget.bounds.y + (widget.bounds.height - style.fontSize) / 2, style)
    if widget.isOpen:
      widget.popup.isDirty = true
    if widget.disabled: drawDisabledOverlay(widget.bounds)
