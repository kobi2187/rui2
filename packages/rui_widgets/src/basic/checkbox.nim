## Checkbox Widget - RUI2
##
## A box and a label, drawn directly rather than composed of children -- at two
## drawing calls a composite would cost more in child bookkeeping than it saved.
##
## `initialChecked` is a prop and `checked` is state, and the connection between
## them is the DSL's seeding convention: a prop named `initial<Field>` seeds the
## state field `<Field>`. The names are not decorative. Renaming the prop
## without renaming the state field silently stops the seeding, which is how
## `initialChecked = true` used to build an unchecked box.
##
## The widget owns its own `checked`, so a caller who needs the value back
## reads it from the widget or listens to `onToggle`; nothing pushes it. That
## is also what the scripting bridge writes when a script says `write true`.

import rui_core
import rui_drawing
import std/options

import raylib

definePrimitive(Checkbox):
  props:
    text: string = ""
    initialChecked: bool = false
    disabled: bool = false
    intent: ThemeIntent = Default

  state:
    checked: bool

  actions:
    onToggle(checked: bool)

  init:
    widget.focusable = true

  events:
    on_mouse_down:
      if not widget.disabled:
        widget.checked = not widget.checked
        if widget.onToggle != nil:
          widget.onToggle(widget.checked)
        return true
      return false

  layout:
    # Size to content so stacks can arrange checkboxes without hand-set bounds.
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
    let props = widget.themeProps(widget.intent, slFocusFirst,
                                  disabled = widget.disabled)

    let checkboxRect = Rect(
      x: widget.bounds.x,
      y: widget.bounds.y,
      width: 20,
      height: 20
    )
    drawCheckbox(checkboxRect, widget.checked, props)

    let textColor = props.foregroundColor.get(Color(r: 60, g: 60, b: 60, a: 255))
    let textX = widget.bounds.x + 25
    let textY = widget.bounds.y + (20 - 14) / 2
    drawText(widget.text, textX, textY, 14.0, textColor)