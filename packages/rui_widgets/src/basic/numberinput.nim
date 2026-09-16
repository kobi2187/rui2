## NumberInput Widget - RUI2
##
## A numeric input field with text editing, validation and spinner buttons.
## Unlike Spinner, the value can be typed directly when the widget has focus.

import rui_core
import rui_drawing
import std/[options, strutils]
# rui_core does not re-export KeyboardKey -- its Menu/Down/Up fields collide
# with the Menu widget and with rui_drawing's ArrowDirection. Widgets that read
# keys ask for it by name.
from raylib import KeyboardKey

const
  ButtonWidth = 16.0'f32   ## Must match drawSpinnerButtons in rui_drawing.
  DefaultHeight = 28.0'f32

definePrimitive(NumberInput):
  props:
    initialValue: float32 = 0.0
    minValue: float32 = 0.0
    maxValue: float32 = 100.0
    step: float32 = 1.0
    decimals: int = 2
    placeholder: string = "0.0"
    disabled: bool = false
    intent: ThemeIntent = Default

  state:
    value: float32
    editing: bool
    textValue: string    # String representation while editing
    upHovered: bool
    downHovered: bool

  actions:
    onChange(value: float32)
    onValidationError(input: string)

  init:
    widget.focusable = true

  events:
    on_mouse_down:
      if widget.disabled:
        return false
      let buttonX = widget.bounds.x + widget.bounds.width - ButtonWidth
      if event.mousePos.x >= buttonX:
        let delta = if event.mousePos.y < widget.bounds.y + widget.bounds.height / 2:
                      widget.step
                    else:
                      -widget.step
        let stepped = clamp(widget.value + delta, widget.minValue, widget.maxValue)
        if stepped != widget.value:
          widget.value = stepped
          widget.textValue = formatFloat(stepped, ffDecimal, widget.decimals)
          widget.isDirty = true
          if widget.onChange.isSome:
            widget.onChange.get()(stepped)
        return true

      # Clicking the text area starts editing from the current value.
      widget.editing = true
      widget.textValue = formatFloat(widget.value, ffDecimal, widget.decimals)
      widget.isDirty = true
      return true

    on_mouse_move:
      if widget.disabled:
        return false
      let buttonX = widget.bounds.x + widget.bounds.width - ButtonWidth
      let inGutter = event.mousePos.x >= buttonX
      let up = inGutter and event.mousePos.y < widget.bounds.y + widget.bounds.height / 2
      let down = inGutter and not up
      if up != widget.upHovered or down != widget.downHovered:
        widget.upHovered = up
        widget.downHovered = down
        widget.isDirty = true
      return false

    on_char:
      if widget.disabled or not widget.editing:
        return false
      # Only accept characters that can appear in a number.
      if event.char in {'0'..'9', '.', '-', '+'}:
        widget.textValue.add(event.char)
        widget.isDirty = true
        return true
      return false

    on_key_down:
      if widget.disabled or not widget.editing:
        return false
      case event.key
      of Backspace:
        if widget.textValue.len > 0:
          widget.textValue.setLen(widget.textValue.len - 1)
          widget.isDirty = true
        return true
      of Enter, KpEnter:
        # Commit: parse, clamp, report. Invalid text reverts and reports.
        widget.editing = false
        widget.isDirty = true
        try:
          let clamped = clamp(float32(parseFloat(widget.textValue)),
                              widget.minValue, widget.maxValue)
          widget.value = clamped
          if widget.onChange.isSome:
            widget.onChange.get()(clamped)
        except ValueError:
          if widget.onValidationError.isSome:
            widget.onValidationError.get()(widget.textValue)
          widget.textValue = formatFloat(widget.value, ffDecimal, widget.decimals)
        return true
      of Escape:
        widget.editing = false
        widget.textValue = formatFloat(widget.value, ffDecimal, widget.decimals)
        widget.isDirty = true
        return true
      else:
        return false

  layout:
    let style = TextStyle(fontFamily: "", fontSize: 14.0, color: BLACK,
                          bold: false, italic: false, underline: false)
    let m = measureText(formatFloat(widget.maxValue, ffDecimal, widget.decimals), style)
    if widget.bounds.height <= 0:
      widget.bounds.height = max(DefaultHeight, m.height)
    if widget.bounds.width <= 0:
      widget.bounds.width = m.width + ButtonWidth + 24.0

  render:
    let state = if widget.disabled: Disabled
                elif widget.editing or widget.focused: Focused
                elif widget.hovered: Hovered
                else: Normal
    let props = currentTheme.getThemeProps(widget.intent, state)

    let display =
      if widget.editing: widget.textValue
      elif widget.value == 0 and widget.placeholder.len > 0 and not widget.focused:
        widget.placeholder
      else: formatFloat(widget.value, ffDecimal, widget.decimals)

    drawSpinner(widget.bounds, display, props,
                widget.upHovered, widget.downHovered, widget.editing or widget.focused)
    if widget.disabled:
      drawDisabledOverlay(widget.bounds)
