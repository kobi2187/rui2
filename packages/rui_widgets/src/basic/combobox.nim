## ComboBox Widget - RUI2
##
## A dropdown selection widget. Shows the selected item in a closed box and
## expands an item list below it when open.

import rui_core
import rui_drawing
import std/options

definePrimitive(ComboBox):
  props:
    items: seq[string] = @[]
    # Named to match the state field `selectedIndex`: the DSL seeds state from
    # a prop called initial<StateField>, so the old `initialSelected` was simply
    # ignored and the widget always started on item 0.
    initialSelectedIndex: int = -1
    placeholder: string = "Select..."
    itemHeight: float32 = 24.0
    boxHeight: float32 = 28.0    # Height of the closed box (bounds grow when open)
    disabled: bool = false
    intent: ThemeIntent = Default

  state:
    selectedIndex: int
    isOpen: bool
    hoverIndex: int

  actions:
    onSelect(index: int)

  events:
    on_mouse_down:
      if widget.disabled:
        return false

      # A click inside the expanded list picks an item; anywhere else toggles.
      if widget.isOpen and event.mousePos.y > widget.bounds.y + widget.boxHeight:
        let offset = event.mousePos.y - (widget.bounds.y + widget.boxHeight)
        let idx = int(offset / widget.itemHeight)
        if idx >= 0 and idx < widget.items.len:
          widget.selectedIndex = idx
          widget.isOpen = false
          widget.isDirty = true
          widget.layoutDirty = true
          if widget.onSelect.isSome:
            widget.onSelect.get()(idx)
          return true

      widget.isOpen = not widget.isOpen
      widget.isDirty = true
      # The dropdown is drawn inside this widget's render texture, which is sized
      # to `bounds`. Opening it has to re-run layout or the list gets clipped away.
      widget.layoutDirty = true
      return true

    on_mouse_move:
      if not widget.isOpen or widget.disabled:
        return false
      let offset = event.mousePos.y - (widget.bounds.y + widget.boxHeight)
      let idx = if offset < 0: -1 else: int(offset / widget.itemHeight)
      let newHover = if idx >= 0 and idx < widget.items.len: idx else: -1
      if newHover != widget.hoverIndex:
        widget.hoverIndex = newHover
        widget.isDirty = true
      return false

    on_key_down:
      if widget.disabled or widget.items.len == 0:
        return false
      case event.key
      of Down:
        widget.selectedIndex = min(widget.items.len - 1, widget.selectedIndex + 1)
      of Up:
        widget.selectedIndex = max(0, widget.selectedIndex - 1)
      of Escape:
        widget.isOpen = false
        widget.isDirty = true
        widget.layoutDirty = true
        return true
      else:
        return false
      widget.isDirty = true
      if widget.onSelect.isSome:
        widget.onSelect.get()(widget.selectedIndex)
      return true

  layout:
    let style = TextStyle(fontFamily: "", fontSize: 14.0, color: BLACK,
                          bold: false, italic: false, underline: false)
    # Height always covers the popup, so the render texture is big enough for it.
    widget.bounds.height =
      if widget.isOpen: widget.boxHeight + float32(widget.items.len) * widget.itemHeight
      else: widget.boxHeight
    if widget.bounds.width <= 0:
      # Wide enough for the longest item, so opening the list never clips text.
      var widest = measureText(widget.placeholder, style).width
      for item in widget.items:
        widest = max(widest, measureText(item, style).width)
      widget.bounds.width = widest + 40.0   # padding + arrow gutter

  render:
    let state = if widget.disabled: Disabled
                elif widget.isOpen: Pressed
                elif widget.focused: Focused
                elif widget.hovered: Hovered
                else: Normal
    let props = currentTheme.getThemeProps(widget.intent, state)

    let text = if widget.selectedIndex >= 0 and widget.selectedIndex < widget.items.len:
                 widget.items[widget.selectedIndex]
               else:
                 widget.placeholder
    let boxRect = Rect(x: widget.bounds.x, y: widget.bounds.y,
                       width: widget.bounds.width, height: widget.boxHeight)
    drawComboBox(boxRect, text, props, widget.isOpen,
                 widget.hovered, widget.focused)

    if widget.isOpen and widget.items.len > 0:
      # The list overlays whatever is below, so it is drawn after the box.
      for i, item in widget.items:
        let itemRect = Rect(
          x: widget.bounds.x,
          y: widget.bounds.y + widget.boxHeight + float32(i) * widget.itemHeight,
          width: widget.bounds.width,
          height: widget.itemHeight
        )
        drawListItem(itemRect, item, props,
                     selected = i == widget.selectedIndex,
                     hovered = i == widget.hoverIndex)

    if widget.disabled:
      drawDisabledOverlay(boxRect)
