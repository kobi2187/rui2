## Checkbox Widget - RUI2
##
## A checkbox input widget with a label that can be toggled on/off.
## Ported from Hummingbird to RUI2's definePrimitive DSL.

import ../../core/widget_dsl_v2
import std/options

when defined(useGraphics):
  import raylib

definePrimitive(Checkbox):
  props:
    text: string = ""
    initialChecked: bool = false
    disabled: bool = false

  state:
    checked: bool
    hovered: bool

  actions:
    onToggle(checked: bool)

  events:
    on_mouse_down:
      if not widget.disabled:
        # Toggle the checked state
        widget.checked.set(not widget.checked.get())
        # Call the callback
        if widget.onToggle.isSome:
          widget.onToggle.get()(widget.checked.get())
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
      # Use raygui for rendering
      var checked = widget.checked.get()

      if GuiCheckBox(
        Rectangle(
          x: widget.bounds.x,
          y: widget.bounds.y,
          width: 20,
          height: 20
        ),
        widget.text.cstring,
        addr checked
      ):
        # GuiCheckBox returns true when clicked
        widget.checked.set(checked)
        if widget.onToggle.isSome:
          widget.onToggle.get()(checked)
    else:
      # Non-graphics mode: just echo
      echo "Checkbox: ", widget.text, " [", (if widget.checked.get(): "X" else: " "), "]"
