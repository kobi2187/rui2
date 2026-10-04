## KanbanBoard -- columns of cards that you drag between columns.
##
## One widget, one job: show columns of cards and let the user move them. It
## owns the order (`columns`) and reports every move; it is not a task manager.
## A card is an id, a title, an optional detail line and an optional tag.
##
## ```nim
## ui:
##   KanbanBoard(columns = @[
##     column("Todo",  card("t1", "Write docs", "docs/themes.md", "docs"),
##                     card("t2", "Fix culling")),
##     column("Doing", card("t3", "Plot widget")),
##     column("Done")]).frame(height = 360)
## ```
##
## Press a card and drag: a gap opens where it would land, and releasing drops
## it there (`onMove(cardId, fromColumn, toColumn, toIndex)`). A press that does
## not move is a click (`onCardClick(cardId)`). The wheel scrolls the column
## under the pointer. Sizes and strokes come from the theme.

import rui_core
import rui_drawing
import std/options
import raylib
import kanban_layout
export kanban_layout

const DragThreshold = 4.0'f32     # pixels before a press becomes a drag

template geometryOf*(widget: untyped): KanbanGeometry =
  ## The board's geometry under the current theme and bounds.
  block:
    let props = currentTheme.getThemeProps(widget.intent)
    var style = props.captionStyle(BLACK, action = true)
    let line = measureText("Ag", style).height
    let pad = props.fieldInset
    var hasDetail = false
    for col in widget.columns:
      for c in col.cards:
        if c.detail.len > 0: hasDetail = true
    var detail = style
    detail.fontSize = max(10.0'f32, style.fontSize - 2)
    let cardH = if widget.cardHeight > 0: widget.cardHeight
                else: line + (if hasDetail: measureText("Ag", detail).height + 2 else: 0.0'f32) + pad * 2
    KanbanGeometry(
      origin: (x: widget.bounds.x, y: widget.bounds.y),
      height: widget.bounds.height,
      columnWidth: (if widget.columnWidth > 0: widget.columnWidth else: 220.0'f32),
      columnGap: max(8.0'f32, pad), headerHeight: line + pad * 2,
      cardHeight: cardH, cardGap: max(4.0'f32, pad * 0.6), pad: pad)

definePrimitive(KanbanBoard):
  props:
    columns: seq[KanbanColumn] = @[]
    columnWidth: float32 = 0.0     # 0: 220
    cardHeight: float32 = 0.0      # 0: from the text and the theme
    intent: ThemeIntent = Default

  state:
    scrolls: seq[float32]          # per column
    held: bool                     # a card is held down...
    dragging: bool                 # ...and has moved far enough to drag
    grabbed: CardSpot
    pressAt: Point
    pointer: Point
    target: Option[CardSpot]

  actions:
    onMove(cardId: string, fromColumn: int, toColumn: int, toIndex: int)
    onCardClick(cardId: string)

  init:
    widget.focusable = true

  events:
    on_mouse_down:
      let g = geometryOf(widget)
      let hit = g.cardAt(widget.columns, widget.scrolls, event.mousePos.x, event.mousePos.y)
      if hit.isNone:
        return false
      widget.held = true
      widget.dragging = false
      widget.grabbed = hit.get
      widget.pressAt = event.mousePos
      widget.pointer = event.mousePos
      return true

    on_mouse_move:
      if not widget.held:
        return false
      widget.pointer = event.mousePos
      if not widget.dragging:
        let dx = event.mousePos.x - widget.pressAt.x
        let dy = event.mousePos.y - widget.pressAt.y
        if dx * dx + dy * dy < DragThreshold * DragThreshold:
          return true
        widget.dragging = true
      let g = geometryOf(widget)
      widget.target = g.dropTarget(widget.columns, widget.scrolls,
                                   event.mousePos.x, event.mousePos.y)
      widget.isDirty = true
      return true

    on_mouse_up:
      if not widget.held:
        return false
      let from0 = widget.grabbed
      let wasDragging = widget.dragging
      let target = widget.target
      widget.held = false
      widget.dragging = false
      widget.target = none(CardSpot)
      widget.isDirty = true
      if wasDragging and target.isSome:
        let to0 = target.get
        let moved = applyMove(widget.columns, from0, to0)
        if moved != widget.columns:
          let id = widget.columns[from0.column].cards[from0.index].id
          widget.columns = moved
          widget.layoutDirty = true
          if widget.onMove != nil:
            widget.onMove(id, from0.column, to0.column,
                          # where it ended up, after the card left its old slot
                          (if from0.column == to0.column and to0.index > from0.index:
                             to0.index - 1 else: to0.index))
      elif not wasDragging and widget.onCardClick != nil:
        widget.onCardClick(widget.columns[from0.column].cards[from0.index].id)
      return true

    on_mouse_wheel:
      let g = geometryOf(widget)
      let col = g.columnAt(widget.columns.len, event.mousePos.x)
      if col.isNone:
        return false
      let c = col.get
      while widget.scrolls.len < widget.columns.len:
        widget.scrolls.add 0.0'f32
      let limit = g.maxScroll(widget.columns[c].cards.len)
      let next = clamp(widget.scrolls[c] - event.wheelDelta * 30.0'f32, 0.0'f32, limit)
      if next == widget.scrolls[c]:
        return false
      widget.scrolls[c] = next
      widget.isDirty = true
      return true

  layout:
    let g = geometryOf(widget)
    let n = max(1, widget.columns.len)
    if widget.bounds.width <= 0:
      widget.bounds.width = float32(n) * g.columnWidth + float32(n - 1) * g.columnGap
    if widget.bounds.height <= 0:
      var tallest = 0
      for col in widget.columns:
        tallest = max(tallest, col.cards.len)
      widget.bounds.height = g.headerHeight + g.contentHeight(max(1, tallest))
    while widget.scrolls.len < widget.columns.len:
      widget.scrolls.add 0.0'f32
    for i in 0 ..< widget.columns.len:      # a shorter column cannot stay scrolled
      widget.scrolls[i] = clamp(widget.scrolls[i], 0.0'f32,
        geometryOf(widget).maxScroll(widget.columns[i].cards.len))

  render:
    let props = widget.themeProps(widget.intent)
    let g = geometryOf(widget)
    let ink = props.foregroundColor.get(BLACK)
    let surface = props.backgroundColor.get(WHITE)
    let border = props.borderColor.get(ink.withAlpha(0.3))
    let radius = props.cornerRadius.get(4.0)
    let stroke = props.strokeWidth
    var titleStyle = props.captionStyle(ink, action = true)
    var detailStyle = props.captionStyle(ink.withAlpha(0.65))
    detailStyle.fontSize = max(10.0'f32, detailStyle.fontSize - 2)
    var tagStyle = detailStyle
    tagStyle.color = ink.withAlpha(0.8)
    let lineH = measureText("Ag", titleStyle).height
    let canvas = currentTheme.canvasColor

    proc drawCard(r: Rect, c: KanbanCard, lifted: bool) =
      if lifted:
        drawBox(Rect(x: r.x + 3, y: r.y + 4, width: r.width, height: r.height),
                radius, Color(r: 0, g: 0, b: 0, a: 60), ink, 0)
      drawBox(r, radius, surface, border, stroke)
      let tagW = if c.tag.len > 0: measureText(c.tag, tagStyle).width + 12 else: 0.0'f32
      # Text stops short of the tag chip rather than running under it.
      let clip = beginClip(Rect(x: r.x + g.pad, y: r.y,
                                width: r.width - g.pad * 2 - (if tagW > 0: tagW + 6 else: 0.0'f32),
                                height: r.height))
      drawStyledText(c.title, r.x + g.pad, r.y + g.pad, titleStyle)
      if c.detail.len > 0:
        drawStyledText(c.detail, r.x + g.pad, r.y + g.pad + lineH + 2, detailStyle)
      endClip(clip)
      if tagW > 0:
        let chip = Rect(x: r.x + r.width - g.pad - tagW, y: r.y + g.pad - 1,
                        width: tagW, height: tagStyle.fontSize + 6)
        drawBox(chip, chip.height / 2, props.activeColor.get(ink).withAlpha(0.18),
                ink, 0)
        drawStyledText(c.tag, chip.x + 6, chip.y + 3, tagStyle)

    for i, col in widget.columns:
      let r = g.columnRect(i)
      drawBox(r, radius, mix(canvas, ink, 0.05), border, stroke)
      drawStyledText(col.title & "  " & $col.cards.len, r.x + g.pad, r.y + g.pad, titleStyle)
      let scroll = if i < widget.scrolls.len: widget.scrolls[i] else: 0.0'f32
      let clip = beginClip(Rect(x: r.x, y: r.y + g.headerHeight, width: r.width,
                                height: r.height - g.headerHeight))
      for j, c in col.cards:
        if widget.dragging and widget.grabbed == (i, j):
          continue                                    # lifted: drawn under the pointer
        drawCard(g.cardRect(i, j, scroll), c, false)
      if widget.dragging and widget.target.isSome and
         widget.target.get.column == i:
        let idx = widget.target.get.index
        let y = g.cardRect(i, idx, scroll).y - g.cardGap / 2
        drawRect(Rect(x: r.x + g.pad, y: y - 1.5, width: r.width - 2 * g.pad, height: 3),
                 props.activeColor.get(ink))
      endClip(clip)

    if widget.dragging:
      let c = widget.columns[widget.grabbed.column].cards[widget.grabbed.index]
      let start = g.cardRect(widget.grabbed.column, widget.grabbed.index,
                             (if widget.grabbed.column < widget.scrolls.len:
                                widget.scrolls[widget.grabbed.column] else: 0.0'f32))
      drawCard(Rect(x: start.x + widget.pointer.x - widget.pressAt.x,
                    y: start.y + widget.pointer.y - widget.pressAt.y,
                    width: start.width, height: start.height), c, true)
