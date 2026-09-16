## ListView Widget - RUI2
##
## A scrollable list view with item selection.
## Features:
## - Virtual rendering: only the visible slice is drawn, so millions of rows are fine
## - Lazy loading: onLoadMore is called as the viewport nears the loaded tail
## - Optional multi-selection (ctrl-click)
## - Mouse wheel scrolling
##
## Note: the pre-split version polled raylib for the mouse inside `render` and
## mutated selection there. Selection now happens in the event handlers and
## `render` only draws, which is what makes the dirty/repaint model work.

import rui_core
import rui_drawing
import ../virtual_rows
import ../list_input
import std/[options, sets]

import raylib

export virtual_rows, list_input

const
  ScrollbarWidth = 12.0'f32
  BufferItems = 5          ## Extra rows drawn above/below the viewport.
  LoadAheadItems = 10
  LoadBatchSize = 100

template totalItems*(widget: untyped): int =
  ## Rows the list claims to have, which with lazy loading exceeds `items.len`.
  (if widget.totalItemCount >= 0: widget.totalItemCount else: widget.items.len)

template viewportOf*(widget: untyped): RowViewport =
  ## A template, not a proc: the ListView type does not exist until the macro
  ## below has expanded, and the widget body needs this.
  rowViewport(top = widget.bounds.y, height = widget.bounds.height,
              rowHeight = widget.itemHeight, scrollY = widget.scrollY)

definePrimitive(ListView):
  props:
    items: seq[string] = @[]
    totalItemCount: int = -1     # -1 means use items.len, otherwise for lazy loading
    itemHeight: float32 = 24.0
    visibleRows: int = 8         # Used to size the widget when no height is given
    multiSelect: bool = false
    showScrollbar: bool = true
    disabled: bool = false
    intent: ThemeIntent = Default

  state:
    selection: HashSet[int]
    scrollY: float32
    visibleStart: int
    visibleEnd: int
    hoverIndex: int

  actions:
    onSelect(selection: HashSet[int])
    onItemClick(index: int)
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

      # GuiEvent carries no modifier state, so ctrl is read straight from the
      # keyboard. Fine here: it is an input query, not render-time polling.
      # A single-select list ignores ctrl rather than quietly multi-selecting.
      let additive = widget.multiSelect and
                     (isKeyDown(LeftControl) or isKeyDown(RightControl))
      updateSelection(widget.selection, idx, additive)

      widget.isDirty = true
      if widget.onItemClick.isSome:
        widget.onItemClick.get()(idx)
      if widget.onSelect.isSome:
        widget.onSelect.get()(widget.selection)
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
      widget.bounds.width = widest + 16.0 + ScrollbarWidth

  render:
    let props = currentTheme.getThemeProps(widget.intent,
                                           if widget.disabled: Disabled else: Normal)
    let itemH = widget.itemHeight
    let total = widget.totalItems
    let v = viewportOf(widget)
    let totalHeight = v.contentHeight(total)
    let viewHeight = widget.bounds.height

    # Virtual rendering: only touch the rows that can be on screen.
    let visible = v.visibleRange(total, buffer = BufferItems)
    widget.visibleStart = visible.a
    widget.visibleEnd = visible.b

    if widget.onLoadMore.isSome and visible.b >= widget.items.len - LoadAheadItems:
      let needCount = min(LoadBatchSize, total - widget.items.len)
      if needCount > 0:
        widget.onLoadMore.get()(widget.items.len, needCount)

    drawThemedBackground(widget.bounds, props)

    let clip = beginClip(widget.bounds)
    let listWidth = if widget.showScrollbar and totalHeight > viewHeight:
                      widget.bounds.width - ScrollbarWidth
                    else:
                      widget.bounds.width

    for itemIdx in visible:
      let itemRect = Rect(x: widget.bounds.x, y: v.rowTop(itemIdx),
                          width: listWidth, height: itemH)
      let text = if itemIdx < widget.items.len: widget.items[itemIdx] else: "Loading..."
      drawListItem(itemRect, text, props,
                   selected = itemIdx in widget.selection,
                   hovered = itemIdx == widget.hoverIndex)
    endClip(clip)

    if widget.showScrollbar and totalHeight > viewHeight:
      let barRect = Rect(
        x: widget.bounds.x + widget.bounds.width - ScrollbarWidth,
        y: widget.bounds.y,
        width: ScrollbarWidth,
        height: viewHeight
      )
      drawScrollbar(barRect, totalHeight, viewHeight, widget.scrollY, props)

    drawThemedBorder(widget.bounds, props, widget.focused)
    if widget.disabled:
      drawDisabledOverlay(widget.bounds)
