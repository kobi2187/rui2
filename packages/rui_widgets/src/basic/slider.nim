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

import rui_core
import rui_drawing
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
        widget.setValue(valueAtX(event.mousePos.x, widget.bounds.x,
                                 widget.bounds.width,
                                 widget.minValue, widget.maxValue))
        return true
      return false

    on_mouse_move:
      if widget.dragging and not widget.disabled:
        widget.setValue(valueAtX(event.mousePos.x, widget.bounds.x,
                                 widget.bounds.width,
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
      widget.bounds.width = 200.0f32

  render:
    let state = if widget.disabled: Disabled
                elif widget.dragging: Pressed
                elif widget.hovered: Hovered
                else: Normal
    let props = currentTheme.getThemeProps(widget.intent, state)

    drawSlider(
      widget.bounds,
      widget.value,
      widget.minValue,
      widget.maxValue,
      props,
      widget.dragging
    )

    if widget.showValue:
      let textColor = props.foregroundColor.get(Color(r: 60, g: 60, b: 60, a: 255))
      let rightText = fmt"{widget.value:.1f}"
      drawText(rightText, widget.bounds.x + widget.bounds.width + 10, widget.bounds.y + (widget.bounds.height - 14) / 2, 14.0, textColor)