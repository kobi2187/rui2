## RadioButton Widget - RUI2
##
## A single radio button. Note what it does *not* have: any state. Whether it is
## filled is `selectedValue == value`, both props, both pushed in from outside.
## A click does not select it -- it reports `onChange(value)` and waits for the
## owner to push a new `selectedValue` back.
##
## That is the only arrangement that can be exclusive. A button holding its own
## `selected` flag has nothing to reconcile it with its siblings, so two of them
## can be on at once.
##
## containers/radiogroup.nim takes this further and draws its options itself
## rather than owning RadioButton children, for the same reason: one
## selectedIndex in one place is what makes the group exclusive. Use a
## RadioButton on its own when you are driving the selection from somewhere
## else; use a RadioGroup when the group is the thing.

import rui_core
import rui_drawing
import std/options

import raylib

definePrimitive(RadioButton):
  props:
    text: string = ""
    value: string = ""
    selectedValue: string = ""
    disabled: bool = false
    intent: ThemeIntent = Default

  actions:
    onChange(value: string)

  init:
    widget.focusable = true

  events:
    on_mouse_down:
      if not widget.disabled:
        if widget.selectedValue != widget.value:
          if widget.onChange.isSome:
            widget.onChange.get()(widget.value)
        return true
      return false

  layout:
    const BoxSize = 20.0f32
    const Gap = 8.0f32
    let style = TextStyle(fontFamily: "", fontSize: 14.0, color: BLACK,
                          bold: false, italic: false, underline: false)
    let m = measureText(widget.text, style)
    if widget.bounds.height <= 0:
      widget.bounds.height = max(BoxSize, m.height)
    if widget.bounds.width <= 0:
      widget.bounds.width = BoxSize + Gap + m.width

  render:
    let state = if widget.disabled: Disabled
                elif widget.focused: Focused
                else: Normal
    let props = currentTheme.getThemeProps(widget.intent, state)

    let isSelected = widget.selectedValue == widget.value
    let radioRect = Rect(
      x: widget.bounds.x,
      y: widget.bounds.y,
      width: 20,
      height: 20
    )
    drawRadioButton(radioRect, isSelected, props)

    let textColor = props.foregroundColor.get(Color(r: 60, g: 60, b: 60, a: 255))
    let textX = widget.bounds.x + 25
    let textY = widget.bounds.y + (20 - 14) / 2
    drawText(widget.text, textX, textY, 14.0, textColor)