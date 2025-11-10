## RadioButton Widget - RUI2
##
## A radio button for mutually exclusive selection.
## Typically used in groups where only one button can be selected at a time.
## Ported from Hummingbird to RUI2's definePrimitive DSL.

import ../../core/widget_dsl_v2
import std/options

when defined(useGraphics):
  import raylib

definePrimitive(RadioButton):
  props:
    text: string = ""
    value: string = ""           # This button's value
    selectedValue: string = ""   # Currently selected value in the group
    disabled: bool = false

  state:
    hovered: bool

  actions:
    onChange(value: string)

  events:
    on_mouse_down:
      if not widget.disabled:
        # Only trigger if this button is not already selected
        if widget.selectedValue != widget.value:
          if widget.onChange.isSome:
            widget.onChange.get()(widget.value)
        return true
      return false

    on_mouse_enter:
      widget.hovered.set(true)
      return false

    on_mouse_leave:
      widget.hovered.set(false)
      return false

  render:
    when defined(useGraphics):
      # Check if this radio button is selected
      let isSelected = widget.selectedValue == widget.value

      if GuiRadioButton(
        Rectangle(
          x: widget.bounds.x,
          y: widget.bounds.y,
          width: 20,
          height: 20
        ),
        widget.text.cstring,
        isSelected
      ):
        # GuiRadioButton returns true when clicked
        if widget.onChange.isSome:
          widget.onChange.get()(widget.value)
    else:
      # Non-graphics mode: just echo
      let marker = if widget.selectedValue == widget.value: "●" else: "○"
      echo "RadioButton: ", marker, " ", widget.text
