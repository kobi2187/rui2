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
    # Size to content, in the theme's indicator size, gap and caption font.
    let props = widget.themeProps(widget.intent, crPointer,
                                  disabled = widget.disabled)
    let box = currentTheme.indicatorSize
    let gap = props.spacing.get(8.0f32)
    let m = measureText(widget.text, props.captionStyle(BLACK))
    if widget.bounds.height <= 0:
      widget.bounds.height = max(box, m.height)
    if widget.bounds.width <= 0:
      widget.bounds.width = box + gap + m.width

  render:
    let props = widget.themeProps(widget.intent, crPointer,
                                  disabled = widget.disabled)
    let size = currentTheme.indicatorSize
    let box = Rect(x: widget.bounds.x,
                   y: widget.bounds.y + (widget.bounds.height - size) / 2,
                   width: size, height: size)
    drawCheckbox(box, widget.checked, props, widget.hovered, widget.focused)

    let textColor = props.foregroundColor.get(Color(r: 60, g: 60, b: 60, a: 255))
    let style = props.captionStyle(textColor)
    let textX = widget.bounds.x + size + props.spacing.get(8.0f32)
    let textY = widget.bounds.y + (widget.bounds.height - style.fontSize) / 2
    drawStyledText(widget.text, textX, textY, style)
