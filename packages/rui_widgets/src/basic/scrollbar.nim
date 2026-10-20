## ScrollBar Widget - RUI2
##
## A scroll bar control for scrolling through content.
## Can be vertical or horizontal.

import rui_core
import ../value_input
import rui_drawing
import std/options

proc valueAlong(bounds: Rect, vertical: bool, pos: Point,
                minValue, maxValue: float32): float32 =
  ## The value under `pos` along the thumb's track: the bar less its arrows.
  let track = scrollBarTrack(bounds)
  if vertical:
    valueAtPointer(pos.y, track.y, track.height, minValue, maxValue, 0.0)
  else:
    valueAtPointer(pos.x, track.x, track.width, minValue, maxValue, 0.0)

definePrimitive(ScrollBar):
  props:
    initialValue: float32 = 0.0
    minValue: float32 = 0.0
    maxValue: float32 = 100.0
    pageSize: float32 = 10.0     # Size of the visible area (drives thumb size)
    wheelStep: float32 = 10.0
    vertical: bool = true
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
      if widget.disabled:
        return false
      # A press on an arrow button steps one wheel notch; it does not drag.
      let ends = scrollBarEnds(widget.bounds)
      let step = if ends.startEnd.contains(event.mousePos.x, event.mousePos.y): -widget.wheelStep
                 elif ends.stopEnd.contains(event.mousePos.x, event.mousePos.y): widget.wheelStep
                 else: 0.0'f32
      if step != 0:
        let stepped = clamp(widget.value + step, widget.minValue, widget.maxValue)
        if stepped != widget.value:
          widget.value = stepped
          widget.isDirty = true
          if widget.onChange != nil:
            widget.onChange(stepped)
        return true
      widget.dragging = true
      capturePointer(widget)
      # Jump straight to the clicked position, then keep tracking on move.
      let newValue = valueAlong(widget.bounds, widget.vertical, event.mousePos,
                                widget.minValue, widget.maxValue)
      if newValue != widget.value:
        widget.value = newValue
        widget.isDirty = true
        if widget.onChange != nil:
          widget.onChange(newValue)
      return true

    on_mouse_move:
      if not widget.dragging or widget.disabled:
        return false
      let newValue = valueAlong(widget.bounds, widget.vertical, event.mousePos,
                                widget.minValue, widget.maxValue)
      if newValue != widget.value:
        widget.value = newValue
        widget.isDirty = true
        if widget.onChange != nil:
          widget.onChange(newValue)
      return true

    on_mouse_up:
      if widget.dragging:
        widget.dragging = false
        return true
      return false

    on_mouse_wheel:
      if widget.disabled:
        return false
      let newValue = clamp(widget.value - event.wheelDelta * widget.wheelStep,
                           widget.minValue, widget.maxValue)
      if newValue != widget.value:
        widget.value = newValue
        widget.isDirty = true
        if widget.onChange != nil:
          widget.onChange(newValue)
      return true

  layout:
    # Fixed on the cross axis, stretched by the parent on the main axis.
    if widget.vertical:
      if widget.bounds.width <= 0:
        widget.bounds.width = fingerSized(currentTheme.scrollbarThickness)
      if widget.bounds.height <= 0:
        widget.bounds.height = 100.0'f32
    else:
      if widget.bounds.height <= 0:
        widget.bounds.height = fingerSized(currentTheme.scrollbarThickness)
      if widget.bounds.width <= 0:
        widget.bounds.width = 100.0'f32

  render:
    let props = widget.themeProps(widget.intent, crPointer,
                                  disabled = widget.disabled,
                                  pressed = widget.dragging)

    let range = max(widget.maxValue - widget.minValue, 0.0001'f32)
    let contentSize = range + widget.pageSize
    let offset = widget.value - widget.minValue

    # The shared primitive handles both orientations now (by the track's
    # shape), so there is no separate horizontal drawing here any more.
    drawScrollbar(widget.bounds, contentSize, widget.pageSize, offset,
                  props, widget.hovered)
