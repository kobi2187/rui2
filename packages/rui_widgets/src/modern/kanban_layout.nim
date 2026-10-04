## The geometry and move arithmetic of a kanban board: where columns and cards
## sit, which card a point is on, where a dragged card would land, and what the
## columns look like after it does. Pure functions over plain values, so every
## rule is decidable without a widget or a window.

import std/options
import rui_core

type
  KanbanCard* = object
    id*: string        ## stable identity, reported by onMove and onCardClick
    title*: string
    detail*: string    ## an optional second line
    tag*: string       ## an optional short label shown at the card's right

  KanbanColumn* = object
    title*: string
    cards*: seq[KanbanCard]

  KanbanGeometry* = object
    origin*: tuple[x, y: float32]   ## top-left of the board
    height*: float32
    columnWidth*, columnGap*: float32
    headerHeight*: float32
    cardHeight*, cardGap*, pad*: float32

  CardSpot* = tuple[column, index: int]

proc `==`*(a, b: KanbanCard): bool =
  a.id == b.id and a.title == b.title and a.detail == b.detail and a.tag == b.tag

proc `==`*(a, b: KanbanColumn): bool =
  a.title == b.title and a.cards == b.cards

proc card*(id, title: string, detail = "", tag = ""): KanbanCard =
  KanbanCard(id: id, title: title, detail: detail, tag: tag)

proc column*(title: string, cards: varargs[KanbanCard]): KanbanColumn =
  KanbanColumn(title: title, cards: @cards)

proc columnRect*(g: KanbanGeometry, i: int): Rect =
  Rect(x: g.origin.x + float32(i) * (g.columnWidth + g.columnGap), y: g.origin.y,
       width: g.columnWidth, height: g.height)

proc cardRect*(g: KanbanGeometry, column, index: int, scrollY = 0.0'f32): Rect =
  ## A card's rectangle; `scrollY` is how far its column is scrolled.
  let col = g.columnRect(column)
  Rect(x: col.x + g.pad,
       y: col.y + g.headerHeight + g.pad + float32(index) * (g.cardHeight + g.cardGap) - scrollY,
       width: g.columnWidth - 2 * g.pad, height: g.cardHeight)

proc contentHeight*(g: KanbanGeometry, count: int): float32 =
  ## Height of `count` cards stacked, with the padding round them.
  g.pad * 2 + float32(count) * g.cardHeight + float32(max(0, count - 1)) * g.cardGap

proc maxScroll*(g: KanbanGeometry, count: int): float32 =
  max(0.0'f32, g.contentHeight(count) - (g.height - g.headerHeight))

proc columnAt*(g: KanbanGeometry, count: int, x: float32): Option[int] =
  ## The column whose strip (the gap after it included) holds x.
  for i in 0 ..< count:
    let r = g.columnRect(i)
    if x >= r.x and x < r.x + r.width + g.columnGap:
      return some(i)

proc cardAt*(g: KanbanGeometry, columns: seq[KanbanColumn],
             scrolls: seq[float32], x, y: float32): Option[CardSpot] =
  ## The card under a point, if any.
  let col = g.columnAt(columns.len, x)
  if col.isNone: return
  let c = col.get
  if y < g.origin.y + g.headerHeight or y > g.origin.y + g.height: return
  let scroll = if c < scrolls.len: scrolls[c] else: 0.0'f32
  for i in 0 ..< columns[c].cards.len:
    let r = g.cardRect(c, i, scroll)
    if x >= r.x and x < r.x + r.width and y >= r.y and y < r.y + r.height:
      return some((c, i))

proc dropTarget*(g: KanbanGeometry, columns: seq[KanbanColumn],
                 scrolls: seq[float32], x, y: float32): Option[CardSpot] =
  ## Where a card dropped at this point would be inserted: the column under x
  ## and the number of its cards whose middle lies above y.
  let col = g.columnAt(columns.len, x)
  if col.isNone: return
  let c = col.get
  let scroll = if c < scrolls.len: scrolls[c] else: 0.0'f32
  var index = 0
  for i in 0 ..< columns[c].cards.len:
    let r = g.cardRect(c, i, scroll)
    if y > r.y + r.height / 2:
      index = i + 1
  some((c, index))

proc applyMove*(columns: seq[KanbanColumn], fromSpot, toSpot: CardSpot): seq[KanbanColumn] =
  ## The columns after taking the card at `fromSpot` and inserting it at
  ## `toSpot`, whose index counts the destination as it was *before* the card
  ## left (what `dropTarget` returns). Dropping a card where it already is
  ## changes nothing.
  result = columns
  if fromSpot.column notin 0 ..< columns.len or toSpot.column notin 0 ..< columns.len:
    return
  if fromSpot.index notin 0 ..< columns[fromSpot.column].cards.len:
    return
  var at = clamp(toSpot.index, 0, columns[toSpot.column].cards.len)
  if fromSpot.column == toSpot.column:
    if at == fromSpot.index or at == fromSpot.index + 1:
      return                                     # already there
    if at > fromSpot.index:
      dec at                                     # the card's own slot goes away
  let moved = result[fromSpot.column].cards[fromSpot.index]
  result[fromSpot.column].cards.delete(fromSpot.index)
  result[toSpot.column].cards.insert(moved, at)
