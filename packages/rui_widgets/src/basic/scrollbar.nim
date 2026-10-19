## ScrollBar Widget - RUI2
##
## A scroll bar control for scrolling through content.
## Can be vertical or horizontal.

import rui_core
import ../value_input
import rui_drawing
import std/options

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
      widget.dragging = true
      capturePointer(widget)
      # Jump straight to the clicked position, then keep tracking on move.
      let newValue = if widget.vertical:
          valueAtPointer(event.mousePos.y, widget.bounds.y, widget.bounds.height,
                         widget.minValue, widget.maxValue, 0.0)
        else:
          valueAtPointer(event.mousePos.x, widget.bounds.x, widget.bounds.width,
                         widget.minValue, widget.maxValue, 0.0)
      if newValue != widget.value:
        widget.value = newValue
        widget.isDirty = true
        if widget.onChange != nil:
          widget.onChange(newValue)
      return true

    on_mouse_move:
      if not widget.dragging or widget.disabled:
        return false
      let newValue = if widget.vertical:
          valueAtPointer(event.mousePos.y, widget.bounds.y, widget.bounds.height,
                         widget.minValue, widget.maxValue, 0.0)
        else:
          valueAtPointer(event.mousePos.x, widget.bounds.x, widget.bounds.width,
                         widget.minValue, widget.maxValue, 0.0)
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
