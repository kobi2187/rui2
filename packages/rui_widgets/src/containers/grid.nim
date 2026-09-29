## Grid Container Widget
##
## Children in rows and columns, placed row-major: the first `columns.len`
## children are the first row, and so on. Each column is a track:
##
## - `px(120)`  -- exactly 120 wide
## - `fit()`    -- as wide as its widest child (fit-content)
## - `star(2)`  -- two shares of whatever width the grid has left over
##
## A cell's child fills the column's width; each row is as tall as its tallest
## cell. With no width of its own the grid has nothing left over to share, so
## star columns size like fit ones.
##
## ```nim
## ui:
##   Grid(columns = @[fit(), star()], colSpacing = 12.0):
##     Label(text = "Name")
##     TextInput()
##     Label(text = "Email")
##     TextInput()
## ```
##
## Not yet: cells spanning several columns or rows.

import rui_core

type
  TrackKind* = enum
    tkFixed, tkAuto, tkStar

  GridTrack* = object
    kind*: TrackKind
    value*: float32   ## pixels for tkFixed, weight for tkStar

proc px*(width: float32): GridTrack = GridTrack(kind: tkFixed, value: width)
proc fit*(): GridTrack = GridTrack(kind: tkAuto)
proc star*(weight = 1.0'f32): GridTrack = GridTrack(kind: tkStar, value: weight)

proc resolveTracks*(tracks: openArray[GridTrack], natural: openArray[float32],
                    available: float32): seq[float32] =
  ## The width of each column. `natural` is the widest child in each column;
  ## `available` is the room for the tracks themselves (spacing already
  ## taken off), or <= 0 when the grid sizes to its content.
  result = newSeq[float32](tracks.len)
  var used, stars = 0.0'f32
  for i, t in tracks:
    case t.kind
    of tkFixed: result[i] = t.value
    of tkAuto: result[i] = natural[i]
    of tkStar:
      stars += max(t.value, 0.0)
      continue
    used += result[i]
  let spare = available - used
  for i, t in tracks:
    if t.kind == tkStar:
      result[i] = if available > 0 and stars > 0:
                    max(0.0'f32, spare) * max(t.value, 0.0) / stars
                  else: natural[i]

proc effectiveTracks*(columns: seq[GridTrack], cols: int): seq[GridTrack] =
  ## The declared columns, or `cols` equal star columns when none were given.
  if columns.len > 0:
    return columns
  for _ in 0 ..< max(1, cols):
    result.add star()

defineWidget(Grid):
  props:
    columns: seq[GridTrack] = @[]
    cols: int = 2                # used when `columns` is empty: that many star()s
    colSpacing: float32 = 8.0
    rowSpacing: float32 = 8.0
    padding: float32 = 0.0
    # Where a cell sits within a taller row -- centred, so a label lines up
    # with the input beside it.
    rowAlign: CrossAxisAlignment = CrossCenter

  layout:
    let tracks = effectiveTracks(widget.columns, widget.cols)
    let n = tracks.len
    let pad = widget.padding
    let hasWidth = widget.bounds.width > 0

    # Measure: every child at its natural size, for the fit columns.
    var natural = newSeq[float32](n)
    for i, child in widget.children:
      child.bounds.width = 0
      child.layout()
      natural[i mod n] = max(natural[i mod n], child.bounds.width)

    let gaps = widget.colSpacing * float32(max(0, n - 1))
    let available = if hasWidth: widget.bounds.width - pad * 2 - gaps else: 0.0'f32
    let widths = resolveTracks(tracks, natural, available)

    # Arrange: a row at a time, since a row's height is its tallest cell.
    var y = widget.bounds.y + pad
    var i = 0
    while i < widget.children.len:
      var x = widget.bounds.x + pad
      var rowHeight = 0.0'f32
      let last = min(i + n, widget.children.len) - 1
      for c in 0 .. last - i:
        let child = widget.children[i + c]
        child.bounds.x = x
        child.bounds.y = y
        child.bounds.width = widths[c]
        child.layout()
        rowHeight = max(rowHeight, child.bounds.height)
        x += widths[c] + widget.colSpacing
      alignCross(widget.children[i .. last], faHorizontal, widget.rowAlign,
                 rowHeight)
      y += rowHeight + widget.rowSpacing
      i += n

    let contentBottom = if widget.children.len > 0: y - widget.rowSpacing
                        else: widget.bounds.y + pad
    if not hasWidth:
      var total = gaps + pad * 2
      for w in widths: total += w
      widget.bounds.width = total
    if widget.bounds.height <= 0:
      widget.bounds.height = contentBottom - widget.bounds.y + pad
