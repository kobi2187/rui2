## Virtual row scrolling — the arithmetic behind every scrollable row list.
##
## ListBox, ListView, TreeView, DataTable, DataGrid, FileDialog and FilePicker
## all show a window onto a list that is taller than they are. Each of them had
## its own copy of the same four calculations: which row is under the pointer,
## how far the list can scroll, which slice needs drawing, and where to scroll
## so a given row is on screen. Seven copies of arithmetic that is easy to get
## subtly wrong and impossible to test through a widget.
##
## A `RowViewport` is a plain value, so all of it is testable without a window.

type
  RowViewport* = object
    ## A window onto a uniform-height row list.
    top*: float32         ## Screen y of the first row's top edge
    height*: float32      ## Visible height
    rowHeight*: float32
    scrollY*: float32     ## How far the list is scrolled, in pixels

proc rowViewport*(top, height, rowHeight, scrollY: float32): RowViewport =
  ## Rows of zero height would map every pointer position to row 0, so that is
  ## the one input worth refusing outright.
  assert rowHeight > 0, "rowHeight must be positive"
  RowViewport(top: top, height: height, rowHeight: rowHeight, scrollY: scrollY)

proc rowAt*(v: RowViewport, mouseY: float32, rowCount: int): int =
  ## Row under `mouseY`, or -1 when the pointer is above the list or past the
  ## last row. Callers can index straight into their data with the result.
  assert v.rowHeight > 0
  if mouseY < v.top:
    return -1
  let idx = int((mouseY - v.top + v.scrollY) / v.rowHeight)
  if idx < 0 or idx >= rowCount: -1 else: idx

proc contentHeight*(v: RowViewport, rowCount: int): float32 =
  assert rowCount >= 0
  float32(rowCount) * v.rowHeight

proc maxScroll*(v: RowViewport, rowCount: int): float32 =
  ## Largest useful scroll offset. Zero when everything already fits.
  max(0.0'f32, v.contentHeight(rowCount) - v.height)

proc clampScroll*(v: RowViewport, scrollY: float32, rowCount: int): float32 =
  clamp(scrollY, 0.0'f32, v.maxScroll(rowCount))

proc scrolledBy*(v: RowViewport, wheelDelta: float32, rowCount: int,
                 rowsPerNotch = 3.0'f32): float32 =
  ## New scroll offset after a wheel notch, already clamped.
  v.clampScroll(v.scrollY - wheelDelta * v.rowHeight * rowsPerNotch, rowCount)

proc rowTop*(v: RowViewport, index: int): float32 =
  ## Screen y of row `index`, which may be outside the visible area.
  v.top + float32(index) * v.rowHeight - v.scrollY

proc isRowVisible*(v: RowViewport, index: int): bool =
  let y = v.rowTop(index)
  y + v.rowHeight >= v.top and y <= v.top + v.height

proc visibleRange*(v: RowViewport, rowCount: int, buffer = 0): Slice[int] =
  ## The rows worth drawing, padded by `buffer` rows either side so a scroll of
  ## a few pixels does not expose an undrawn edge. Empty when there are no rows.
  if rowCount <= 0:
    return 1 .. 0            # empty slice: `for i in 1..0` runs zero times
  let first = max(0, int(v.scrollY / v.rowHeight) - buffer)
  let last = min(rowCount - 1,
                 int((v.scrollY + v.height) / v.rowHeight) + buffer)
  if last < first: 1 .. 0 else: first .. last

proc scrollToShow*(v: RowViewport, index, rowCount: int): float32 =
  ## Smallest scroll offset that puts row `index` fully on screen. Scrolls up
  ## when the row is above the window, down when below, and leaves the offset
  ## alone when it is already visible — which is what keyboard navigation wants.
  let rowStart = float32(index) * v.rowHeight
  let rowEnd = rowStart + v.rowHeight
  if rowStart < v.scrollY:
    v.clampScroll(rowStart, rowCount)
  elif rowEnd > v.scrollY + v.height:
    v.clampScroll(rowEnd - v.height, rowCount)
  else:
    v.scrollY

proc nearEnd*(v: RowViewport, rowCount: int, threshold = 0.8'f32): bool =
  ## Is the view scrolled into the last `1 - threshold` of the content? Lazy
  ## loaders use this to fetch the next page.
  let limit = v.maxScroll(rowCount)
  if limit <= 0:
    return false
  v.scrollY / limit > threshold
