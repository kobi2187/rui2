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
import ../hover
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
  themedSize(w.itemHeight, currentTheme.rowHeight(20.0))

const
  BufferItems = 5
  LoadAheadItems = 10
  LoadBatchSize = 100

template totalItems*(widget: untyped): int =
  ## Rows the list claims to have. With lazy loading that is more than the rows
  ## currently in `items`, which is what makes the scrollbar the right length
  ## before the tail has been fetched.
  (if widget.source != nil: widget.source.count
   elif widget.totalItemCount >= 0: widget.totalItemCount else: widget.items.len)

template viewportOf*(widget: untyped): RowViewport =
  ## A template, not a proc: the ListBox type does not exist until the macro
  ## below has expanded, and the widget body needs this.
  rowViewport(top = widget.bounds.y, height = widget.bounds.height,
              rowHeight = rowH(widget), scrollY = widget.scrollY)

definePrimitive(ListBox):
  props:
    items: seq[string] = @[]
    totalItemCount: int = -1     # -1 means use items.len, otherwise for lazy loading
    itemHeight: float32 = 0.0   # 0: the theme's row height
    visibleRows: int = 8
    multiSelect: bool = false
    disabled: bool = false
    intent: ThemeIntent = Default

  state:
    selection: HashSet[int]
    source: RowSource            # where the rows come from, instead of `items`
    scrollY: float32
    touch: RowsTouch             # a finger's tap or drag (scroll_drag.nim)
    vbar: VBar                   # the scroll bar's drag and hover
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
    widget.multiPointer = true
    widget.resetOnLeave:
      widget.hoverIndex = -1
      widget.vbar.hover = false
    widget.hoverIndex = -1       # nothing is under the pointer yet

  events:
    on_mouse_wheel:
      if widget.disabled:
        return false
      if widget.rowsWheel(viewportOf(widget), widget.totalItems, event.wheelDelta,
                          widget.scrollY) and widget.onScrollNearEnd != nil:
        widget.onScrollNearEnd()
      return true

    on_mouse_move:
      if widget.rowsTouch(widget.touch, event, widget.scrollY, viewportOf(widget),
                          widget.totalItems, widget.barTrack): return true
      if widget.disabled:
        return false
      let at = widget.rowsMove(widget.vbar, widget.scrollY, widget.barTrack,
                               viewportOf(widget), widget.totalItems, event.mousePos)
      if at.taken: return true
      if at.row != widget.hoverIndex:
        widget.hoverIndex = at.row
        widget.isDirty = true
      return false

    on_mouse_up:
      if widget.rowsTouch(widget.touch, event, widget.scrollY, viewportOf(widget),
                          widget.totalItems, widget.barTrack): return true
      return widget.rowsUp(widget.vbar)

    on_mouse_down:
      if widget.rowsTouch(widget.touch, event, widget.scrollY, viewportOf(widget),
                          widget.totalItems, widget.barTrack): return true
      if widget.disabled:
        return false
      if widget.rowsDown(widget.vbar, widget.scrollY, widget.barTrack,
                         viewportOf(widget), widget.totalItems, event.mousePos):
        return true
      let idx = viewportOf(widget).rowAt(event.mousePos.y, widget.totalItems)
      if idx < 0:
        return false

      # A single-select list ignores ctrl rather than quietly multi-selecting.
      let additive = widget.multiSelect and event.ctrl
      updateSelection(widget.selection, idx, additive)
      widget.focusIndex = idx
      widget.isDirty = true
      if widget.onSelect != nil:
        widget.onSelect(widget.selection)
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
        if widget.onItemActivate != nil:
          widget.onItemActivate(widget.focusIndex)
        if widget.onSelect != nil:
          widget.onSelect(widget.selection)
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
    widget.rowsFling(widget.touch, widget.scrollY, viewportOf(widget),
                     widget.totalItems)
    if widget.bounds.height <= 0:
      widget.bounds.height = float32(widget.visibleRows) * rowH(widget)
    if widget.bounds.width <= 0:
      let style = TextStyle(fontFamily: "", fontSize: 12.0, color: BLACK,
                            bold: false, italic: false, underline: false)
      var widest = if widget.source != nil: 240.0'f32 else: 0.0'f32
      for item in widget.items:
        widest = max(widest, measureText(item, style).width)
      widget.bounds.width = widest + 16.0

  render:
    let props = currentTheme.getThemeProps(widget.intent,
                                           if widget.disabled: Disabled else: Normal)
    let itemH = rowH(widget)
    let total = widget.totalItems
    let v = viewportOf(widget)

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
    let pendingProps = currentTheme.getThemeProps(widget.intent, Disabled)
    if widget.source != nil and visible.b >= visible.a:
      widget.source.want(visible.a, visible.b)
    for itemIdx in visible:
      let itemRect = Rect(x: widget.bounds.x, y: v.rowTop(itemIdx),
                          width: widget.bounds.width, height: itemH)
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

    widget.vbar.drawBar(widget.barTrack, v.contentHeight(total), widget.bounds.height,
                        widget.scrollY, props)
    drawThemedBorder(widget.bounds, props, widget.focused)
    if widget.disabled:
      drawDisabledOverlay(widget.bounds, currentTheme.canvasColor)

proc bindSource*(list: ListBox, source: RowSource) =
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
                         hover: list.hoverIndex, anchor: list.focusIndex,
                         scrollY: list.scrollY)
    let lost = place.followEdit(change, source.count, rowH(list), list.bounds.height)
    list.selection = place.selection
    list.focusIndex = place.focus
    list.hoverIndex = place.hover

    list.scrollY = place.scrollY
    list.isDirty = true
    if lost and list.onSelect != nil: list.onSelect(list.selection))

proc bindItems*(list: ListBox, source: LinkSeq[string]) =
  ## Show a LinkSeq, following its edits one by one (nothing is copied).
  let adapter = newLinkSeqSource(source)
  list.bindSource(adapter)
  list.disposers.add proc() = adapter.close()      # the adapter is this list's own

proc bindItems*(list: ListBox, source: RowSource) = list.bindSource(source)
  ## `ui:` spelling: `ListBox(items = -> source)`.
