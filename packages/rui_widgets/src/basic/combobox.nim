## ComboBox Widget - RUI2
##
## A dropdown selection widget. Shows the selected item in a closed box and
## expands an item list below it when open.

import rui_core
import rui_drawing
import std/[options, strutils]
# rui_core does not re-export KeyboardKey: its Menu/Down/Up fields collide with
# the Menu widget and with rui_drawing's ArrowDirection. A widget that reads
# keys asks for it by name -- which is also what keeps `of Down:` below meaning
# the key rather than the arrow glyph.
from raylib import KeyboardKey

proc themedFieldHeight*(): float32 =
  ## A one-line field's height under the current theme: its caption line, the
  ## field inset above and below, and at least the theme's control height.
  ## TextInput comes out the same, so a combo box lines up with the inputs
  ## beside it in a form.
  let props = currentTheme.getThemeProps(ThemeIntent.Default)
  let line = measureText("Ag", props.captionStyle(BLACK)).height
  max(currentTheme.controlHeight, line + 2 * props.fieldInset)

template closedHeight*(w: untyped): float32 =
  (if w.boxHeight > 0: w.boxHeight else: themedFieldHeight())

proc letterMatch(items: openArray[string], event: GuiEvent, after: int): int =
  ## The next item after `after` that starts with the letter or digit
  ## pressed (ignoring case), wrapping round; -1 when none does.
  let k = ord(event.key)
  if event.mods * {kmCtrl, kmAlt} != {} or
     not (k in ord('A') .. ord('Z') or k in ord('0') .. ord('9')):
    return -1
  let c = chr(k).toLowerAscii
  for step in 1 .. items.len:
    let i = (after + step + items.len) mod items.len
    if items[i].len > 0 and items[i][0].toLowerAscii == c:
      return i
  -1

template pick(widget: untyped, index: int) =
  ## Choose item `index`, telling whoever listens if it changed.
  block:
    let i = index
    if i != widget.selectedIndex:
      widget.selectedIndex = i
      if widget.onSelect != nil:
        widget.onSelect(i)
    widget.isDirty = true

template setOpen(widget: untyped, open: bool) =
  ## Show or hide the list. Open, it is a popup: a click anywhere else
  ## closes it. The list is drawn inside this widget's render texture, so a
  ## change of size has to re-run layout or it gets clipped away.
  block:
    let w = widget
    if w.isOpen != open:
      w.isOpen = open
      w.isDirty = true
      w.layoutDirty = true
      if open:
        w.hoverIndex = w.selectedIndex
        openPopup(w, scope = w, close = proc() =
          w.isOpen = false
          w.isDirty = true
          w.layoutDirty = true)
      else:
        closedPopup(w)

definePrimitive(ComboBox):
  props:
    items: seq[string] = @[]
    # Named to match the state field `selectedIndex`: the DSL seeds state from
    # a prop called initial<StateField>, so the old `initialSelected` was simply
    # ignored and the widget always started on item 0.
    initialSelectedIndex: int = -1
    placeholder: string = "Select..."
    itemHeight: float32 = 24.0
    boxHeight: float32 = 0.0     # Closed box height; 0 takes the theme's field height
    disabled: bool = false
    intent: ThemeIntent = Default

  state:
    selectedIndex: int
    isOpen: bool
    hoverIndex: int

  actions:
    onSelect(index: int)

  init:
    widget.focusable = true

  events:
    on_mouse_down:
      if widget.disabled:
        return false

      # A click inside the expanded list picks an item; anywhere else toggles.
      if widget.isOpen and event.mousePos.y > widget.bounds.y + widget.closedHeight:
        let offset = event.mousePos.y - (widget.bounds.y + widget.closedHeight)
        let idx = int(offset / widget.itemHeight)
        if idx >= 0 and idx < widget.items.len:
          widget.setOpen(false)
          widget.pick(idx)
          return true

      widget.setOpen(not widget.isOpen)
      return true

    on_mouse_move:
      if not widget.isOpen or widget.disabled:
        return false
      let offset = event.mousePos.y - (widget.bounds.y + widget.closedHeight)
      let idx = if offset < 0: -1 else: int(offset / widget.itemHeight)
      let newHover = if idx >= 0 and idx < widget.items.len: idx else: -1
      if newHover != widget.hoverIndex:
        widget.hoverIndex = newHover
        widget.isDirty = true
      return false

    on_key_down:
      # Closed: Up/Down, Home/End and a letter change the choice at once;
      # Enter, Space, F4 or Alt+Down open the list. Open: Up/Down move the
      # highlight, Enter picks it, Escape closes without a change.
      if widget.disabled or widget.items.len == 0:
        return false
      let n = widget.items.len
      if widget.isOpen:
        case event.key
        of Down: widget.hoverIndex = min(n - 1, max(0, widget.hoverIndex + 1))
        of Up: widget.hoverIndex = max(0, widget.hoverIndex - 1)
        of Home: widget.hoverIndex = 0
        of End: widget.hoverIndex = n - 1
        of Enter, KpEnter, Space:
          let chosen = widget.hoverIndex
          widget.setOpen(false)
          if chosen >= 0: widget.pick(chosen)
          return true
        of Escape, F4:
          widget.setOpen(false)
          return true
        else:
          let i = letterMatch(widget.items, event, widget.hoverIndex)
          if i < 0: return false
          widget.hoverIndex = i
        widget.isDirty = true
        return true
      case event.key
      of Enter, KpEnter, Space, F4:
        widget.setOpen(true)
      of Down:
        if kmAlt in event.mods: widget.setOpen(true)
        else: widget.pick(min(n - 1, widget.selectedIndex + 1))
      of Up: widget.pick(max(0, widget.selectedIndex - 1))
      of Home: widget.pick(0)
      of End: widget.pick(n - 1)
      else:
        let i = letterMatch(widget.items, event, widget.selectedIndex)
        if i < 0: return false
        widget.pick(i)
      return true

  layout:
    let props = widget.themeProps(widget.intent, crText, disabled = widget.disabled)
    let style = props.captionStyle(BLACK)
    # Height always covers the popup, so the render texture is big enough for it.
    widget.bounds.height =
      if widget.isOpen: widget.closedHeight + float32(widget.items.len) * widget.itemHeight
      else: widget.closedHeight
    if widget.bounds.width <= 0:
      # Wide enough for the longest item, so opening the list never clips text.
      var widest = measureText(widget.placeholder, style).width
      for item in widget.items:
        widest = max(widest, measureText(item, style).width)
      widget.bounds.width = widest + props.fieldInset * 2 + 24.0   # + arrow gutter

  render:
    let props = widget.themeProps(widget.intent, crText,
                                  disabled = widget.disabled,
                                  pressed = widget.isOpen)

    let text = if widget.selectedIndex >= 0 and widget.selectedIndex < widget.items.len:
                 widget.items[widget.selectedIndex]
               else:
                 widget.placeholder
    let boxRect = Rect(x: widget.bounds.x, y: widget.bounds.y,
                       width: widget.bounds.width, height: widget.closedHeight)
    drawComboBox(boxRect, text, props, widget.isOpen,
                 widget.hovered, widget.focused)

    if widget.isOpen and widget.items.len > 0:
      # The list overlays whatever is below, so it is drawn after the box.
      for i, item in widget.items:
        let itemRect = Rect(
          x: widget.bounds.x,
          y: widget.bounds.y + widget.closedHeight + float32(i) * widget.itemHeight,
          width: widget.bounds.width,
          height: widget.itemHeight
        )
        drawListItem(itemRect, item, props,
                     selected = i == widget.selectedIndex,
                     hovered = i == widget.hoverIndex)

    if widget.disabled:
      drawDisabledOverlay(boxRect)
