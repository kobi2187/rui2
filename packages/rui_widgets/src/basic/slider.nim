## Slider Widget - RUI2
##
## A horizontal slider over `minValue`..`maxValue`, holding its own `value`.
##
## Dragging is three events, not one: press sets the value and starts the drag,
## move updates it, release ends it. The move handler is the one that matters
## and it was missing -- the widget set `dragging = true` on press and had no
## on_mouse_move at all, so the thumb never followed the pointer and `onChange`
## never fired. The value was only ever whatever `initialValue` seeded.
##
## The pointer-to-value mapping is `valueAtX`, an ordinary proc rather than
## something buried in an event handler, so it can be tested without a window
## and so the reverse mapping in drawSlider has something to be checked against.
##
## Captions (`textLeft`, `textRight`, the value when `showValue`) sit *inside*
## the bounds, either side of a narrower track. They used to be drawn past the
## right edge, which is outside the widget's own render texture, so they were
## clipped away and never seen. `trackRect` is the one place that decides where
## the track is; drawing and the pointer mapping both go through it.

import rui_core
import rui_drawing
import ../text_content
import std/[options, strformat, strutils]

import raylib

proc valueAtX*(x, boundsX, boundsWidth, minValue, maxValue: float32): float32 =
  ## Where a pointer at `x` falls on a slider spanning boundsX..+boundsWidth.
  ## Clamped, so dragging past either end pins to that end rather than running
  ## the value off the scale.
  if boundsWidth <= 0:
    return minValue
  let t = clamp((x - boundsX) / boundsWidth, 0.0'f32, 1.0'f32)
  minValue + t * (maxValue - minValue)

const
  CaptionSize = 14.0'f32
  CaptionGap = 8.0'f32

proc trackRect*(bounds: Rect, leftWidth, rightWidth: float32): Rect =
  ## The part of the bounds the track occupies once the captions either side
  ## have taken their room. A caption of width 0 takes no gap either.
  let left = if leftWidth > 0: leftWidth + CaptionGap else: 0.0'f32
  let right = if rightWidth > 0: rightWidth + CaptionGap else: 0.0'f32
  Rect(x: bounds.x + left, y: bounds.y,
       width: max(0.0'f32, bounds.width - left - right), height: bounds.height)

proc captionWidth(text: string): float32 =
  if text.len == 0: 0.0'f32
  else: measureText(text, textStyle(CaptionSize, BLACK)).width

proc formatValue(v: float32): string = fmt"{v:.1f}"

proc rightCaption(textRight: string, showValue: bool, v: float32): string =
  ## What goes right of the track: the value, then any fixed caption.
  var parts: seq[string]
  if showValue: parts.add formatValue(v)
  if textRight.len > 0: parts.add textRight
  parts.join(" ")

template captionRoom(w: untyped): tuple[left, right: float32] =
  ## Room for the captions either side of the track. The right slot is sized
  ## for the widest value the range can show, so the track does not jitter as
  ## the digits change.
  (captionWidth(w.textLeft),
   max(captionWidth(rightCaption(w.textRight, w.showValue, w.minValue)),
       captionWidth(rightCaption(w.textRight, w.showValue, w.maxValue))))

template track(w: untyped): Rect =
  ## This slider's track, inside its bounds.
  block:
    let room = w.captionRoom
    trackRect(w.bounds, room.left, room.right)

template setValue(w, computed: untyped) =
  ## Move the slider, and tell anyone listening -- but only on a real change, so
  ## a drag that stays within one pixel does not fire onChange sixty times a
  ## second.
  ##
  ## A template rather than a proc because it names the widget type, which does
  ## not exist until definePrimitive below has run.
  block:
    let v = computed
    if w.value != v:
      w.value = v
      w.isDirty = true
      if w.onChange != nil:
        w.onChange(v)

definePrimitive(Slider):
  props:
    initialValue: float32 = 0.0
    minValue: float32 = 0.0
    maxValue: float32 = 100.0
    showValue: bool = true
    textLeft: string = ""
    textRight: string = ""
    disabled: bool = false
    intent: ThemeIntent = Default

  state:
    value: float32
    dragging: bool

  actions:
    onChange(value: float32)

  init:
    widget.focusable = true

  events:
    on_mouse_down:
      # Pressing anywhere on the track jumps the thumb there, which is what
      # every other slider does and what makes a single click useful.
      if not widget.disabled:
        widget.dragging = true
        let t = widget.track
        widget.setValue(valueAtX(event.mousePos.x, t.x, t.width,
                                 widget.minValue, widget.maxValue))
        return true
      return false

    on_mouse_move:
      if widget.dragging and not widget.disabled:
        let t = widget.track
        widget.setValue(valueAtX(event.mousePos.x, t.x, t.width,
                                 widget.minValue, widget.maxValue))
        return true
      return false

    on_mouse_up:
      if widget.dragging:
        widget.dragging = false
        widget.isDirty = true
        return true
      return false

  layout:
    if widget.bounds.height <= 0:
      widget.bounds.height = 24.0f32
    if widget.bounds.width <= 0:
      # 200 of track, plus whatever the captions and their gaps need
      let room = widget.captionRoom
      let taken = 1000.0f32 - trackRect(Rect(width: 1000.0), room.left,
                                        room.right).width
      widget.bounds.width = 200.0f32 + taken

  render:
    let props = widget.themeProps(widget.intent, crPointer,
                                  disabled = widget.disabled,
                                  pressed = widget.dragging)

    let t = widget.track
    drawSlider(t, widget.value, widget.minValue, widget.maxValue, props,
               widget.dragging)

    let textColor = props.foregroundColor.get(Color(r: 60, g: 60, b: 60, a: 255))
    let y = widget.bounds.y + (widget.bounds.height - CaptionSize) / 2
    if widget.textLeft.len > 0:
      drawText(widget.textLeft, widget.bounds.x, y, CaptionSize, textColor)
    let right = rightCaption(widget.textRight, widget.showValue, widget.value)
    if right.len > 0:
      drawText(right, t.x + t.width + CaptionGap, y, CaptionSize, textColor)
