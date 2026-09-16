## Spinner Widget - RUI2
##
## A numeric spinner with up/down buttons for value adjustment.
## Allows stepping through numeric values within a range.

import rui_core
import rui_drawing
import std/[options, strutils]

const
  ButtonWidth = 16.0'f32   ## Must match drawSpinnerButtons in rui_drawing.
  DefaultHeight = 28.0'f32

definePrimitive(Spinner):
  props:
    initialValue: float32 = 0.0
    minValue: float32 = 0.0
    maxValue: float32 = 100.0
    step: float32 = 1.0
    decimals: int = 2
    textLeft: string = ""
    disabled: bool = false
    intent: ThemeIntent = Default

  state:
    value: float32
    upHovered: bool
    downHovered: bool

  actions:
    onChange(value: float32)

  init:
    widget.focusable = true

  events:
    on_mouse_down:
      if widget.disabled:
        return false
      # The up/down buttons live in the right-hand 16px gutter, split in half.
      let buttonX = widget.bounds.x + widget.bounds.width - ButtonWidth
      if event.mousePos.x < buttonX:
        return false

      let delta = if event.mousePos.y < widget.bounds.y + widget.bounds.height / 2:
                    widget.step
                  else:
                    -widget.step
      let stepped = clamp(widget.value + delta, widget.minValue, widget.maxValue)
      if stepped != widget.value:
        widget.value = stepped
        widget.isDirty = true
        if widget.onChange != nil:
          widget.onChange(stepped)
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

  layout:
    let style = TextStyle(fontFamily: "", fontSize: 14.0, color: BLACK,
                          bold: false, italic: false, underline: false)
    let m = measureText(widget.textLeft & formatFloat(widget.maxValue, ffDecimal, widget.decimals), style)
    if widget.bounds.height <= 0:
      widget.bounds.height = max(DefaultHeight, m.height)
    if widget.bounds.width <= 0:
      widget.bounds.width = m.width + ButtonWidth + 24.0

  render:
    let state = if widget.disabled: Disabled
                elif widget.focused: Focused
                elif widget.hovered: Hovered
                else: Normal
    let props = currentTheme.getThemeProps(widget.intent, state)

    let text = widget.textLeft & formatFloat(widget.value, ffDecimal, widget.decimals)
    drawSpinner(widget.bounds, text, props,
                widget.upHovered, widget.downHovered, widget.focused)
    if widget.disabled:
      drawDisabledOverlay(widget.bounds)
