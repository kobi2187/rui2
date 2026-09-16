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
import ../virtual_rows
import ../list_input
import std/[options, sets]

import raylib

export virtual_rows, list_input

const
  BufferItems = 5
  LoadAheadItems = 10
  LoadBatchSize = 100

template totalItems*(widget: untyped): int =
  ## Rows the list claims to have. With lazy loading that is more than the rows
  ## currently in `items`, which is what makes the scrollbar the right length
  ## before the tail has been fetched.
  (if widget.totalItemCount >= 0: widget.totalItemCount else: widget.items.len)

template viewportOf*(widget: untyped): RowViewport =
  ## A template, not a proc: the ListBox type does not exist until the macro
  ## below has expanded, and the widget body needs this.
  rowViewport(top = widget.bounds.y, height = widget.bounds.height,
              rowHeight = widget.itemHeight, scrollY = widget.scrollY)

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

  init:
    widget.focusable = true

  events:
    on_mouse_wheel:
      if widget.disabled:
        return false
      let v = viewportOf(widget)
      let total = widget.totalItems
      let newScroll = v.scrolledBy(event.wheelDelta, total)
      if newScroll != widget.scrollY:
        widget.scrollY = newScroll
        widget.isDirty = true

      if v.nearEnd(total) and widget.onScrollNearEnd.isSome:
        widget.onScrollNearEnd.get()()
      return true

    on_mouse_move:
      if widget.disabled:
        return false
      let newHover = viewportOf(widget).rowAt(event.mousePos.y, widget.totalItems)
      if newHover != widget.hoverIndex:
        widget.hoverIndex = newHover
        widget.isDirty = true
      return false

    on_mouse_down:
      if widget.disabled:
        return false
      let idx = viewportOf(widget).rowAt(event.mousePos.y, widget.totalItems)
      if idx < 0:
        return false

      # A single-select list ignores ctrl rather than quietly multi-selecting.
      let additive = widget.multiSelect and
                     (isKeyDown(LeftControl) or isKeyDown(RightControl))
      updateSelection(widget.selection, idx, additive)
      widget.focusIndex = idx
      widget.isDirty = true
      if widget.onSelect.isSome:
        widget.onSelect.get()(widget.selection)
      return true

    on_key_down:
      if widget.disabled:
        return false
      let total = widget.totalItems
      if total == 0:
        return false

      if event.key in ActivateKeys:
        widget.selection = [widget.focusIndex].toHashSet
        widget.isDirty = true
        if widget.onItemActivate.isSome:
          widget.onItemActivate.get()(widget.focusIndex)
        if widget.onSelect.isSome:
          widget.onSelect.get()(widget.selection)
        return true

      # none means the key does not navigate, so the event stays unhandled
      # rather than this list swallowing every key press.
      let moved = nextFocusIndex(event.key, widget.focusIndex, total,
                                 widget.visibleRows)
      if moved.isNone:
        return false
      if moved.get() != widget.focusIndex:
        widget.focusIndex = moved.get()
        # Keep the focused row inside the viewport.
        widget.scrollY = viewportOf(widget).scrollToShow(moved.get(), total)
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
    let total = widget.totalItems
    let v = viewportOf(widget)

    let visible = v.visibleRange(total, buffer = BufferItems)
    widget.visibleStart = visible.a
    widget.visibleEnd = visible.b

    if widget.onLoadMore.isSome and visible.b >= widget.items.len - LoadAheadItems:
      let needCount = min(LoadBatchSize, total - widget.items.len)
      if needCount > 0:
        widget.onLoadMore.get()(widget.items.len, needCount)

    drawThemedBackground(widget.bounds, props)

    let clip = beginClip(widget.bounds)
    for itemIdx in visible:
      let itemRect = Rect(x: widget.bounds.x, y: v.rowTop(itemIdx),
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
