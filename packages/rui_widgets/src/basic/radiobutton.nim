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
          if widget.onChange != nil:
            widget.onChange(widget.value)
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
    drawRadioButton(box, widget.selectedValue == widget.value, props, widget.hovered, widget.focused)

    let textColor = props.foregroundColor.get(Color(r: 60, g: 60, b: 60, a: 255))
    let style = props.captionStyle(textColor)
    let textX = widget.bounds.x + size + props.spacing.get(8.0f32)
    let textY = widget.bounds.y + (widget.bounds.height - style.fontSize) / 2
    drawStyledText(widget.text, textX, textY, style)
