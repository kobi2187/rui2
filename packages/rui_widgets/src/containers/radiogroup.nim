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
  Gap = 8.0'f32

template pitch(w: untyped): float32 =
  ## Row pitch: `spacing`, or more if the theme's radios or text need it.
  max(w.spacing, currentTheme.indicatorSize + 4)

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
    widget.hoverIndex = -1       # no row is under the pointer yet
    # Not a focusGroup: RadioGroup draws its own options rather than owning
    # child widgets, so there is nothing for group navigation to move between.
    # Its Up/Down handling is internal, and reaches it because the focused
    # widget gets first refusal on every key.

  events:
    on_mouse_down:
      if widget.disabled:
        return false
      let idx = int((event.mousePos.y - widget.bounds.y) / widget.pitch)
      if idx < 0 or idx >= widget.options.len:
        return false
      if idx != widget.selectedIndex:
        widget.selectedIndex = idx
        widget.isDirty = true
        if widget.onSelect != nil:
          widget.onSelect(idx)
      return true

    on_mouse_move:
      if widget.disabled:
        return false
      let idx = int((event.mousePos.y - widget.bounds.y) / widget.pitch)
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
        if widget.onSelect != nil:
          widget.onSelect(newIndex)
      return true

  layout:
    let style = currentTheme.getThemeProps(widget.intent).captionStyle(BLACK)
    if widget.bounds.height <= 0:
      widget.bounds.height = float32(widget.options.len) * widget.pitch
    if widget.bounds.width <= 0:
      var widest = 0.0'f32
      for option in widget.options:
        widest = max(widest, measureText(option, style).width)
      widget.bounds.width = currentTheme.indicatorSize + Gap + widest

  render:
    let size = currentTheme.indicatorSize
    for i, option in widget.options:
      # Per option, not per widget: the group draws its own rows, so hover
      # and focus are about this row rather than about the group.
      let props = currentTheme.getThemeProps(widget.intent,
        visualState(widget.disabled, pressed = false,
                    hovered = i == widget.hoverIndex,
                    focused = widget.focused and i == widget.selectedIndex,
                    ladder = currentTheme.ladderFor(crPointer)))

      let rowY = widget.bounds.y + float32(i) * widget.pitch
      let midY = rowY + widget.pitch / 2
      drawRadioButton(Rect(x: widget.bounds.x, y: midY - size / 2,
                           width: size, height: size),
                      i == widget.selectedIndex, props,
                      hovered = i == widget.hoverIndex)

      let textColor = props.foregroundColor.get(Color(r: 60, g: 60, b: 60, a: 255))
      let style = props.captionStyle(textColor)
      drawStyledText(option, widget.bounds.x + size + Gap,
                     midY - style.fontSize / 2, style)

    if widget.disabled:
      drawDisabledOverlay(widget.bounds)
