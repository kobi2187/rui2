## RadioGroup Widget - RUI2
##
## A group of mutually exclusive options: picking one clears the rest.
##
## The group draws its own options rather than owning RadioButton children.
## Exclusivity is the whole point of the widget, and keeping the selected index
## in one place is what makes it exclusive -- a bag of independent RadioButton
## children would each own their own `selected` flag with nothing to reconcile them.

import rui_core
import rui_drawing
import std/options
# rui_core does not re-export KeyboardKey -- its Menu/Down/Up fields collide
# with the Menu widget and with rui_drawing's ArrowDirection. Widgets that read
# keys ask for it by name, which is what keeps `of Up:` below meaning the key
# rather than the arrow glyph.
from raylib import KeyboardKey

const
  ButtonSize = 20.0'f32
  Gap = 8.0'f32

definePrimitive(RadioGroup):
  props:
    options: seq[string] = @[]
    # Named to match the state field `selectedIndex`: the DSL seeds state from
    # a prop called initial<StateField>, so the old `initialSelected` was simply
    # ignored and the widget always started on item 0.
    initialSelectedIndex: int = 0
    spacing: float32 = 24.0      # Vertical pitch between options
    disabled: bool = false
    intent: ThemeIntent = Default

  state:
    selectedIndex: int
    hoverIndex: int

  actions:
    onSelect(index: int)

  init:
    widget.focusable = true
    # Not a focusGroup: RadioGroup draws its own options rather than owning
    # child widgets, so there is nothing for group navigation to move between.
    # Its Up/Down handling is internal, and reaches it because the focused
    # widget gets first refusal on every key.

  events:
    on_mouse_down:
      if widget.disabled:
        return false
      let idx = int((event.mousePos.y - widget.bounds.y) / widget.spacing)
      if idx < 0 or idx >= widget.options.len:
        return false
      if idx != widget.selectedIndex:
        widget.selectedIndex = idx
        widget.isDirty = true
        if widget.onSelect.isSome:
          widget.onSelect.get()(idx)
      return true

    on_mouse_move:
      if widget.disabled:
        return false
      let idx = int((event.mousePos.y - widget.bounds.y) / widget.spacing)
      let newHover = if idx >= 0 and idx < widget.options.len: idx else: -1
      if newHover != widget.hoverIndex:
        widget.hoverIndex = newHover
        widget.isDirty = true
      return false

    on_key_down:
      if widget.disabled or widget.options.len == 0:
        return false
      var newIndex = widget.selectedIndex
      case event.key
      of Up:   newIndex = max(0, widget.selectedIndex - 1)
      of Down: newIndex = min(widget.options.len - 1, widget.selectedIndex + 1)
      else:    return false
      if newIndex != widget.selectedIndex:
        widget.selectedIndex = newIndex
        widget.isDirty = true
        if widget.onSelect.isSome:
          widget.onSelect.get()(newIndex)
      return true

  layout:
    let style = TextStyle(fontFamily: "", fontSize: 14.0, color: BLACK,
                          bold: false, italic: false, underline: false)
    if widget.bounds.height <= 0:
      widget.bounds.height = float32(widget.options.len) * widget.spacing
    if widget.bounds.width <= 0:
      var widest = 0.0'f32
      for option in widget.options:
        widest = max(widest, measureText(option, style).width)
      widget.bounds.width = ButtonSize + Gap + widest

  render:
    let style = TextStyle(fontFamily: "", fontSize: 14.0, color: BLACK,
                          bold: false, italic: false, underline: false)
    for i, option in widget.options:
      let state = if widget.disabled: Disabled
                  elif i == widget.hoverIndex: Hovered
                  elif widget.focused and i == widget.selectedIndex: Focused
                  else: Normal
      let props = currentTheme.getThemeProps(widget.intent, state)

      let rowY = widget.bounds.y + float32(i) * widget.spacing
      drawRadioButton(Rect(x: widget.bounds.x, y: rowY,
                           width: ButtonSize, height: ButtonSize),
                      i == widget.selectedIndex, props)

      let textColor = props.foregroundColor.get(Color(r: 60, g: 60, b: 60, a: 255))
      drawText(option, widget.bounds.x + ButtonSize + Gap,
               rowY + (ButtonSize - style.fontSize) / 2, style.fontSize, textColor)

    if widget.disabled:
      drawDisabledOverlay(widget.bounds)
