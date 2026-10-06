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

# The open list. It floats on the overlay layer, so opening it moves
# nothing on the page and it can hang below the box over whatever follows.
# What it shows comes from its ComboBox (`source`); what happens in it goes
# back there (`onPick`, `onHover`).
type ComboSource* = proc(): tuple[items: seq[string], selected, hover: int] {.closure.}
  ## What an open ComboList shows, asked of its ComboBox when it paints.

definePrimitive(ComboList):
  props:
    itemHeight: float32 = 24.0
    intent: ThemeIntent = Default

  state:
    source: ComboSource
    fieldProps: ThemeProps

  actions:
    onPick(index: int)
    onHover(index: int)

  init:
    widget.floating = true

  events:
    on_mouse_move:
      let i = int((event.mousePos.y - widget.bounds.y) / widget.itemHeight)
      if widget.onHover != nil: widget.onHover(i)
      widget.isDirty = true
      return true

    on_mouse_down:
      let i = int((event.mousePos.y - widget.bounds.y) / widget.itemHeight)
      if widget.onPick != nil: widget.onPick(i)
      return true

  render:
    if widget.source == nil: return
    let s = widget.source()
    let props = widget.fieldProps
    drawThemedBackground(widget.bounds, props)
    for i, item in s.items:
      drawListItem(Rect(x: widget.bounds.x, y: widget.bounds.y + float32(i) * widget.itemHeight,
                        width: widget.bounds.width, height: widget.itemHeight),
                   item, props, selected = i == s.selected, hovered = i == s.hover)
    drawThemedBorder(widget.bounds, props)

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
  ## Show or hide the list. Open, it floats on the overlay layer and is a
  ## popup: a click anywhere else closes it.
  block:
    let w = widget
    let wanted = open                # evaluated once: it may read isOpen
    if w.isOpen != wanted:
      w.isOpen = wanted
      w.isDirty = true
      w.layoutDirty = true
      if wanted:
        w.hoverIndex = w.selectedIndex
        openPopup(w, scope = w, close = proc() =
          w.isOpen = false
          hideOverlay(w.list)
          w.isDirty = true
          w.layoutDirty = true)
        showOverlay(w.list, interactive = true)
      else:
        closedPopup(w)
        hideOverlay(w.list)

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
    list: ComboList              # the open list, floating below the box

  actions:
    onSelect(index: int)

  init:
    widget.focusable = true
    let box = widget
    widget.list = newComboList(itemHeight = widget.itemHeight, intent = widget.intent)
    widget.list.source = proc(): tuple[items: seq[string], selected, hover: int] =
      (box.items, box.selectedIndex, box.hoverIndex)
    widget.list.onPick = proc(i: int) =
      if i >= 0 and i < box.items.len:
        box.setOpen(false)
        box.pick(i)
    widget.list.onHover = proc(i: int) =
      let h = if i >= 0 and i < box.items.len: i else: -1
      if h != box.hoverIndex:
        box.hoverIndex = h
        box.isDirty = true
    widget.addChild widget.list

  events:
    on_mouse_down:
      if widget.disabled:
        return false

      # The box toggles the list; picks in the list arrive from the list.
      widget.setOpen(not widget.isOpen)
      return true

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
    # Just the box: the open list floats on the overlay layer.
    widget.bounds.height = widget.closedHeight
    if widget.bounds.width <= 0:
      # Wide enough for the longest item, so opening the list never clips text.
      var widest = measureText(widget.placeholder, style).width
      for item in widget.items:
        widest = max(widest, measureText(item, style).width)
      widget.bounds.width = widest + props.fieldInset * 2 + 24.0   # + arrow gutter

    # The list hangs below the box -- or above it, when the window has no
    # room below.
    let listH = float32(widget.items.len) * widget.itemHeight
    var top = widget.bounds.y + widget.bounds.height
    if renderView.isSome:
      let view = renderView.get
      if top + listH > view.y + view.height and widget.bounds.y - listH >= view.y:
        top = widget.bounds.y - listH
    widget.list.bounds = Rect(x: widget.bounds.x, y: top,
                              width: widget.bounds.width, height: listH)
    widget.list.itemHeight = widget.itemHeight

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

    if widget.isOpen:
      # The list paints itself on the overlay layer, after the tree: tell
      # it the field's look and that what it shows may have changed.
      widget.list.fieldProps = widget.themeProps(widget.intent, crText)
      widget.list.isDirty = true

    if widget.disabled:
      drawDisabledOverlay(boxRect)
