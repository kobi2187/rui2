## ListBox Widget - RUI2
##
## A list box for single or multi-select from a list of items.
## Features:
## - Virtual rendering: only the visible slice is drawn
## - Lazy loading: onLoadMore is called as the viewport nears the loaded tail
## - Multi-selection (ctrl-click) and keyboard navigation
##
## ListBox is the keyboard-driven sibling of ListView: it keeps a focus row that
## arrow keys move and Enter activates.

import rui_core
import rui_drawing
import std/[options, sets]

import raylib

const
  BufferItems = 5
  LoadAheadItems = 10
  LoadBatchSize = 100

definePrimitive(ListBox):
  props:
    items: seq[string] = @[]
    totalItemCount: int = -1     # -1 means use items.len, otherwise for lazy loading
    itemHeight: float32 = 20.0
    visibleRows: int = 8
    multiSelect: bool = false
    disabled: bool = false
    intent: ThemeIntent = Default

  state:
    selection: HashSet[int]
    scrollY: float32
    visibleStart: int
    visibleEnd: int
    focusIndex: int
    hoverIndex: int

  actions:
    onSelect(selection: HashSet[int])
    onItemActivate(index: int)               # Enter on the focused row
    onLoadMore(startIndex: int, count: int)
    onScrollNearEnd()

  events:
    on_mouse_wheel:
      if widget.disabled:
        return false
      let totalItems = if widget.totalItemCount >= 0: widget.totalItemCount
                       else: widget.items.len
      let maxScroll = max(0.0'f32,
                          float32(totalItems) * widget.itemHeight - widget.bounds.height)
      let newScroll = clamp(widget.scrollY - event.wheelDelta * widget.itemHeight * 3.0,
                            0.0'f32, maxScroll)
      if newScroll != widget.scrollY:
        widget.scrollY = newScroll
        widget.isDirty = true

      let scrollRatio = if maxScroll > 0: widget.scrollY / maxScroll else: 0.0'f32
      if scrollRatio > 0.8 and widget.onScrollNearEnd.isSome:
        widget.onScrollNearEnd.get()()
      return true

    on_mouse_move:
      if widget.disabled:
        return false
      let idx = int((event.mousePos.y - widget.bounds.y + widget.scrollY) / widget.itemHeight)
      let totalItems = if widget.totalItemCount >= 0: widget.totalItemCount
                       else: widget.items.len
      let newHover = if idx >= 0 and idx < totalItems: idx else: -1
      if newHover != widget.hoverIndex:
        widget.hoverIndex = newHover
        widget.isDirty = true
      return false

    on_mouse_down:
      if widget.disabled:
        return false
      let idx = int((event.mousePos.y - widget.bounds.y + widget.scrollY) / widget.itemHeight)
      let totalItems = if widget.totalItemCount >= 0: widget.totalItemCount
                       else: widget.items.len
      if idx < 0 or idx >= totalItems:
        return false

      let ctrlDown = isKeyDown(LeftControl) or isKeyDown(RightControl)
      if widget.multiSelect and ctrlDown:
        if idx in widget.selection: widget.selection.excl(idx)
        else: widget.selection.incl(idx)
      else:
        widget.selection = [idx].toHashSet

      widget.focusIndex = idx
      widget.isDirty = true
      if widget.onSelect.isSome:
        widget.onSelect.get()(widget.selection)
      return true

    on_key_down:
      if widget.disabled:
        return false
      let totalItems = if widget.totalItemCount >= 0: widget.totalItemCount
                       else: widget.items.len
      if totalItems == 0:
        return false

      var newFocus = widget.focusIndex
      case event.key
      of Up:    newFocus = max(0, widget.focusIndex - 1)
      of Down:  newFocus = min(totalItems - 1, widget.focusIndex + 1)
      of Home:  newFocus = 0
      of End:   newFocus = totalItems - 1
      of PageUp:
        newFocus = max(0, widget.focusIndex - widget.visibleRows)
      of PageDown:
        newFocus = min(totalItems - 1, widget.focusIndex + widget.visibleRows)
      of Enter, KpEnter, Space:
        widget.selection = [widget.focusIndex].toHashSet
        widget.isDirty = true
        if widget.onItemActivate.isSome:
          widget.onItemActivate.get()(widget.focusIndex)
        if widget.onSelect.isSome:
          widget.onSelect.get()(widget.selection)
        return true
      else:
        return false

      if newFocus != widget.focusIndex:
        widget.focusIndex = newFocus
        # Keep the focused row inside the viewport.
        let rowTop = float32(newFocus) * widget.itemHeight
        let rowBottom = rowTop + widget.itemHeight
        if rowTop < widget.scrollY:
          widget.scrollY = rowTop
        elif rowBottom > widget.scrollY + widget.bounds.height:
          widget.scrollY = rowBottom - widget.bounds.height
        widget.isDirty = true
      return true

  layout:
    if widget.bounds.height <= 0:
      widget.bounds.height = float32(widget.visibleRows) * widget.itemHeight
    if widget.bounds.width <= 0:
      let style = TextStyle(fontFamily: "", fontSize: 12.0, color: BLACK,
                            bold: false, italic: false, underline: false)
      var widest = 0.0'f32
      for item in widget.items:
        widest = max(widest, measureText(item, style).width)
      widget.bounds.width = widest + 16.0

  render:
    let props = currentTheme.getThemeProps(widget.intent,
                                           if widget.disabled: Disabled else: Normal)
    let itemH = widget.itemHeight
    let totalItems = if widget.totalItemCount >= 0: widget.totalItemCount
                     else: widget.items.len
    let viewHeight = widget.bounds.height

    let visStart = max(0, int(widget.scrollY / itemH) - BufferItems)
    let visEnd = min(totalItems - 1, int((widget.scrollY + viewHeight) / itemH) + BufferItems)
    widget.visibleStart = visStart
    widget.visibleEnd = visEnd

    if widget.onLoadMore.isSome and visEnd >= widget.items.len - LoadAheadItems:
      let needCount = min(LoadBatchSize, totalItems - widget.items.len)
      if needCount > 0:
        widget.onLoadMore.get()(widget.items.len, needCount)

    drawThemedBackground(widget.bounds, props)

    let clip = beginClip(widget.bounds)
    for itemIdx in visStart..visEnd:
      if itemIdx >= totalItems:
        break
      let itemY = widget.bounds.y + float32(itemIdx) * itemH - widget.scrollY
      if itemY + itemH < widget.bounds.y or itemY > widget.bounds.y + viewHeight:
        continue

      let itemRect = Rect(x: widget.bounds.x, y: itemY,
                          width: widget.bounds.width, height: itemH)
      let text = if itemIdx < widget.items.len: widget.items[itemIdx] else: "Loading..."
      drawListItem(itemRect, text, props,
                   selected = itemIdx in widget.selection,
                   hovered = itemIdx == widget.hoverIndex,
                   focused = widget.focused and itemIdx == widget.focusIndex)
    endClip(clip)

    drawThemedBorder(widget.bounds, props, widget.focused)
    if widget.disabled:
      drawDisabledOverlay(widget.bounds)
