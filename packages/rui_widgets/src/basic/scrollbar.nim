## ScrollBar Widget - RUI2
##
## A scroll bar control for scrolling through content.
## Can be vertical or horizontal.

import rui_core
import rui_drawing
import std/options

const
  Thickness = 12.0'f32
  MinThumb = 20.0'f32

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
      # Jump straight to the clicked position, then keep tracking on move.
      let track = if widget.vertical: widget.bounds.height else: widget.bounds.width
      let pos = if widget.vertical: event.mousePos.y - widget.bounds.y
                else: event.mousePos.x - widget.bounds.x
      let ratio = if track > 0: clamp(pos / track, 0.0'f32, 1.0'f32) else: 0.0'f32
      let newValue = widget.minValue + ratio * (widget.maxValue - widget.minValue)
      if newValue != widget.value:
        widget.value = newValue
        widget.isDirty = true
        if widget.onChange != nil:
          widget.onChange(newValue)
      return true

    on_mouse_move:
      if not widget.dragging or widget.disabled:
        return false
      let track = if widget.vertical: widget.bounds.height else: widget.bounds.width
      let pos = if widget.vertical: event.mousePos.y - widget.bounds.y
                else: event.mousePos.x - widget.bounds.x
      let ratio = if track > 0: clamp(pos / track, 0.0'f32, 1.0'f32) else: 0.0'f32
      let newValue = widget.minValue + ratio * (widget.maxValue - widget.minValue)
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
        widget.bounds.width = Thickness
      if widget.bounds.height <= 0:
        widget.bounds.height = 100.0'f32
    else:
      if widget.bounds.height <= 0:
        widget.bounds.height = Thickness
      if widget.bounds.width <= 0:
        widget.bounds.width = 100.0'f32

  render:
    let props = widget.themeProps(widget.intent, slPointerFirst,
                                  disabled = widget.disabled,
                                  pressed = widget.dragging)

    let range = max(widget.maxValue - widget.minValue, 0.0001'f32)
    let contentSize = range + widget.pageSize
    let offset = widget.value - widget.minValue

    if widget.vertical:
      drawScrollbar(widget.bounds, contentSize, widget.pageSize, offset,
                    props, widget.hovered)
    else:
      # The shared primitive measures the thumb off rect.height, so it only
      # works vertically. Horizontal gets its own two rects.
      let color = props.foregroundColor.get(Color(r: 160, g: 160, b: 160, a: 255))
      let trackColor = color.withAlpha(0.3)
      drawRect(widget.bounds, trackColor)
      let ratio = widget.pageSize / contentSize
      let thumbW = max(widget.bounds.width * ratio, MinThumb)
      let thumbX = widget.bounds.x +
                   (widget.bounds.width - thumbW) * (offset / range)
      drawRect(Rect(x: thumbX, y: widget.bounds.y,
                    width: thumbW, height: widget.bounds.height), color)
