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
import ../seq_follow
import ../scroll_drag
import ../sources
import std/[options, sets]

import raylib

export virtual_rows, list_input

template rowH(w: untyped): float32 =
  ## This widget's row height: its own prop, else the theme's.
  themedSize(w.itemHeight, currentTheme.rowHeight(24.0))

const
  BufferItems = 5          ## Extra rows drawn above/below the viewport.
  LoadAheadItems = 10
  LoadBatchSize = 100

template totalItems*(widget: untyped): int =
  ## Rows the list claims to have, which with lazy loading exceeds `items.len`.
  (if widget.source != nil: widget.source.count
   elif widget.totalItemCount >= 0: widget.totalItemCount else: widget.items.len)

template viewportOf*(widget: untyped): RowViewport =
  ## A template, not a proc: the ListView type does not exist until the macro
  ## below has expanded, and the widget body needs this.
  rowViewport(top = widget.bounds.y, height = widget.bounds.height,
              rowHeight = rowH(widget), scrollY = widget.scrollY)

template barTrack(widget: untyped): Rect =
  ## The scroll bar's track: down the right edge, the full height.
  Rect(x: widget.bounds.x + widget.bounds.width - currentTheme.scrollbarThickness,
       y: widget.bounds.y, width: currentTheme.scrollbarThickness,
       height: widget.bounds.height)

template barShown(widget: untyped): bool =
  widget.showScrollbar and viewportOf(widget).contentHeight(widget.totalItems) >
    widget.bounds.height

definePrimitive(ListView):
  props:
    items: seq[string] = @[]
    totalItemCount: int = -1     # -1 means use items.len, otherwise for lazy loading
    itemHeight: float32 = 0.0   # 0: the theme's row height
    visibleRows: int = 8         # Used to size the widget when no height is given
    multiSelect: bool = false
    showScrollbar: bool = true
    disabled: bool = false
    intent: ThemeIntent = Default

  state:
    selection: HashSet[int]
    source: RowSource            # where the rows come from, instead of `items`
    scrollY: float32
    visibleStart: int
    visibleEnd: int
    hoverIndex: int
    focusIndex: int              # the keyboard's row
    anchorIndex: int             # where a Shift range starts
    barDragging: bool            # the scroll bar's thumb is held
    barGrab: float32             # where on the thumb it was taken
    barHover: bool               # the pointer is over the bar

  actions:
    onSelect(selection: HashSet[int])
    onItemClick(index: int)
    onLoadMore(startIndex: int, count: int)
    onScrollNearEnd()

  init:
    widget.focusable = true
    # The pointer leaving the widget is not a move the widget ever hears.
    widget.onPointerLeave = proc() =
      widget.hoverIndex = -1; widget.barHover = false
      widget.markDirtyToRoot()
    widget.hoverIndex = -1       # nothing is under the pointer yet

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

      if v.nearEnd(total) and widget.onScrollNearEnd != nil:
        widget.onScrollNearEnd()
      return true

    on_mouse_move:
      if widget.disabled:
        return false
      if widget.barDragging:
        let v = viewportOf(widget)
        widget.scrollY = barDragTo(widget.barTrack, v.contentHeight(widget.totalItems),
                                   widget.bounds.height, widget.barGrab, event.mousePos.y)
        widget.isDirty = true
        return true
      let overBar = widget.barShown and widget.barTrack.contains(event.mousePos.x, event.mousePos.y)
      if overBar != widget.barHover:
        widget.barHover = overBar
        widget.isDirty = true
      if overBar:
        if widget.hoverIndex != -1:
          widget.hoverIndex = -1
          widget.isDirty = true
        return false
      let newHover = viewportOf(widget).rowAt(event.mousePos.y, widget.totalItems)
      if newHover != widget.hoverIndex:
        widget.hoverIndex = newHover
        widget.isDirty = true
      return false

    on_mouse_up:
      if widget.barDragging:
        widget.barDragging = false
        widget.isDirty = true
        return true
      return false

    on_mouse_down:
      if widget.disabled:
        return false
      if widget.barShown:
        let v = viewportOf(widget)
        let content = v.contentHeight(widget.totalItems)
        let press = barPress(widget.barTrack, content, widget.bounds.height,
                             widget.scrollY, event.mousePos)
        case press.kind
        of bpThumb:
          widget.barDragging = true
          widget.barGrab = press.grab
          capturePointer(widget)          # the drag follows the pointer off the bar
          widget.isDirty = true
          return true
        of bpPageUp, bpPageDown:
          let page = max(widget.bounds.height - rowH(widget), rowH(widget))
          widget.scrollY = v.clampScroll(widget.scrollY +
            (if press.kind == bpPageUp: -page else: page), widget.totalItems)
          widget.isDirty = true
          return true
        of bpNone: discard
      let idx = viewportOf(widget).rowAt(event.mousePos.y, widget.totalItems)
      if idx < 0:
        return false

      # A single-select list ignores ctrl rather than quietly multi-selecting.
      if widget.multiSelect and event.shift:
        discard keyboardSelect(widget.selection, widget.anchorIndex, idx,
                               true, shift = true, ctrl = false)
      else:
        let additive = widget.multiSelect and event.ctrl
        updateSelection(widget.selection, idx, additive)
        widget.anchorIndex = idx
      widget.focusIndex = idx

      widget.isDirty = true
      if widget.onItemClick != nil:
        widget.onItemClick(idx)
      if widget.onSelect != nil:
        widget.onSelect(widget.selection)
      return true

    on_key_down:
      # Arrows, Home/End and PageUp/PageDown move the focus row and the
      # selection with it (Shift: a range, Ctrl: the focus alone); Space
      # selects -- or toggles, in a multi-select list; Enter activates;
      # Ctrl+A selects everything.
      if widget.disabled or not widget.focused:
        return false
      let total = widget.totalItems
      if total == 0:
        return false
      let multi = widget.multiSelect
      var changed = false
      if event.ctrl and event.key == KeyboardKey.A and multi:
        let before = widget.selection
        widget.selection.clear()
        for i in 0 ..< total: widget.selection.incl i
        changed = widget.selection != before
      elif event.key == KeyboardKey.Space:
        let before = widget.selection
        updateSelection(widget.selection, widget.focusIndex, multi)
        widget.anchorIndex = widget.focusIndex
        changed = widget.selection != before
      elif event.key in {KeyboardKey.Enter, KeyboardKey.KpEnter}:
        if widget.onItemClick != nil: widget.onItemClick(widget.focusIndex)
        return true
      else:
        let v = viewportOf(widget)
        let moved = nextFocusIndex(event.key, widget.focusIndex, total,
                                   max(1, int(widget.bounds.height / rowH(widget)) - 1))
        if moved.isNone:
          return false
        widget.focusIndex = moved.get
        changed = keyboardSelect(widget.selection, widget.anchorIndex, moved.get,
                                 multi, event.shift, event.ctrl)
        widget.scrollY = v.scrollToShow(moved.get, total)
        if v.nearEnd(total) and widget.onScrollNearEnd != nil:
          widget.onScrollNearEnd()
      widget.isDirty = true
      if changed and widget.onSelect != nil:
        widget.onSelect(widget.selection)
      return true

  layout:
    if widget.bounds.height <= 0:
      widget.bounds.height = float32(widget.visibleRows) * rowH(widget)
    if widget.bounds.width <= 0:
      let style = TextStyle(fontFamily: "", fontSize: 12.0, color: BLACK,
                            bold: false, italic: false, underline: false)
      var widest = if widget.source != nil: 240.0'f32 else: 0.0'f32
      for item in widget.items:
        widest = max(widest, measureText(item, style).width)
      widget.bounds.width = widest + 16.0 + currentTheme.scrollbarThickness

  render:
    let props = currentTheme.getThemeProps(widget.intent,
                                           if widget.disabled: Disabled else: Normal)
    let itemH = rowH(widget)
    let total = widget.totalItems
    let v = viewportOf(widget)
    let totalHeight = v.contentHeight(total)
    let viewHeight = widget.bounds.height

    # Virtual rendering: only touch the rows that can be on screen.
    let visible = v.visibleRange(total, buffer = BufferItems)
    widget.visibleStart = visible.a
    widget.visibleEnd = visible.b

    if widget.source == nil and widget.onLoadMore != nil and
       visible.b >= widget.items.len - LoadAheadItems:
      let needCount = min(LoadBatchSize, total - widget.items.len)
      if needCount > 0:
        widget.onLoadMore(widget.items.len, needCount)

    drawThemedBackground(widget.bounds, props, well = true)

    let clip = beginClip(widget.bounds)
    let listWidth = if widget.showScrollbar and totalHeight > viewHeight:
                      widget.bounds.width - currentTheme.scrollbarThickness
                    else:
                      widget.bounds.width

    let pendingProps = currentTheme.getThemeProps(widget.intent, Disabled)
    if widget.source != nil and visible.b >= visible.a:
      widget.source.want(visible.a, visible.b)
    for itemIdx in visible:
      let itemRect = Rect(x: widget.bounds.x, y: v.rowTop(itemIdx),
                          width: listWidth, height: itemH)
      if widget.source != nil and widget.source.rowState(itemIdx) == rsPending:
        # Known to exist, not here yet: a placeholder in the theme's disabled look.
        drawListItem(itemRect, "...", pendingProps)
        continue
      let text = if widget.source != nil: widget.source.text(itemIdx)
                 elif itemIdx < widget.items.len: widget.items[itemIdx]
                 else: "Loading..."
      drawListItem(itemRect, text, props,
                   selected = itemIdx in widget.selection,
                   hovered = itemIdx == widget.hoverIndex,
                   focused = widget.focused and itemIdx == widget.focusIndex)
    endClip(clip)

    if widget.showScrollbar and totalHeight > viewHeight:
      let barRect = Rect(
        x: widget.bounds.x + widget.bounds.width - currentTheme.scrollbarThickness,
        y: widget.bounds.y,
        width: currentTheme.scrollbarThickness,
        height: viewHeight
      )
      drawScrollbar(barRect, totalHeight, viewHeight, widget.scrollY, props)
      if widget.barDragging or widget.barHover:     # the thumb, strengthened
        let thumb = thumbRect(barRect, totalHeight, viewHeight, widget.scrollY)
        drawRoundedRect(Rect(x: thumb.x + 1, y: thumb.y, width: thumb.width - 2,
                             height: thumb.height), (thumb.width - 2) / 2,
                        props.borderColor.get(GRAY).withAlpha(0.45'f32))

    drawThemedBorder(widget.bounds, props, widget.focused)
    if widget.disabled:
      drawDisabledOverlay(widget.bounds)

proc bindSource*(list: ListView, source: RowSource) =
  ## Show the rows of `source`, asking it only for the ones on screen. Rows it
  ## has not got yet are drawn as placeholders in the theme's disabled look.
  ## Edits it reports keep the selection, focus and scroll position on the rows
  ## they were on.
  list.source = source
  list.items = @[]
  list.selection.clear()
  list.layoutDirty = true
  source.attach(list, proc(change: SeqChange) =
    var place = RowPlace(selection: list.selection, focus: list.focusIndex,
                         hover: list.hoverIndex, anchor: list.anchorIndex,
                         scrollY: list.scrollY)
    let lost = place.followEdit(change, source.count, rowH(list), list.bounds.height)
    list.selection = place.selection
    list.focusIndex = place.focus
    list.hoverIndex = place.hover
    list.anchorIndex = place.anchor
    list.scrollY = place.scrollY
    list.isDirty = true
    if lost and list.onSelect != nil: list.onSelect(list.selection))

proc bindItems*(list: ListView, source: LinkSeq[string]) =
  ## Show a LinkSeq, following its edits one by one (nothing is copied).
  let adapter = newLinkSeqSource(source)
  list.bindSource(adapter)
  list.disposers.add proc() = adapter.close()      # the adapter is this list's own

proc bindItems*(list: ListView, source: RowSource) = list.bindSource(source)
  ## `ui:` spelling: `ListView(items = -> source)`.
