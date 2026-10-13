## Pressing and dragging a vertical scroll bar, for widgets that scroll their own
## rows (ListView and friends) and draw the bar themselves.
##
## Pure geometry: given the bar's track, the content and view heights and the
## current offset, what a press does and where a drag puts the offset. The widget
## keeps two state fields (is a thumb drag under way, where on the thumb it was
## taken), captures the pointer while it lasts, and applies the answers.
##
## A press on the thumb starts a drag; a press on the track beside it pages toward
## the pointer (and keeps paging while the button stays down is left to the
## widget's repeat, if it wants one); a press anywhere else is not the bar's.

import rui_core
import containers/scroll_geometry
import virtual_rows

type BarPress* = enum
  bpNone      ## not on the bar
  bpThumb     ## on the thumb: start a drag
  bpPageUp    ## on the track above the thumb
  bpPageDown  ## on the track below it

proc thumbRect*(track: Rect, contentH, viewH, scrollY: float32): Rect =
  ## The thumb inside `track`; the whole track when everything fits.
  let maxScroll = max(0.0'f32, contentH - viewH)
  let len = thumbLength(track.height, viewH, contentH)
  Rect(x: track.x, y: track.y + thumbOffset(track.height, len, scrollY, maxScroll),
       width: track.width, height: len)

proc barPress*(track: Rect, contentH, viewH, scrollY: float32, p: Point):
    tuple[kind: BarPress, grab: float32] =
  ## What a press at `p` means. `grab` is how far down the thumb it was taken.
  if contentH <= viewH or not track.contains(p.x, p.y):
    return (bpNone, 0.0'f32)
  let thumb = thumbRect(track, contentH, viewH, scrollY)
  if p.y >= thumb.y and p.y <= thumb.y + thumb.height:
    (bpThumb, p.y - thumb.y)
  elif p.y < thumb.y:
    (bpPageUp, 0.0'f32)
  else:
    (bpPageDown, 0.0'f32)

proc barDragTo*(track: Rect, contentH, viewH, grab, pointerY: float32): float32 =
  ## The scroll offset that puts the thumb where a drag, begun `grab` pixels down
  ## the thumb, has taken it. Clamped to the content.
  let maxScroll = max(0.0'f32, contentH - viewH)
  let len = thumbLength(track.height, viewH, contentH)
  let travel = track.height - len
  if travel <= 0: return 0.0'f32
  clamp((pointerY - grab - track.y) / travel * maxScroll, 0.0'f32, maxScroll)

# ---------------------------------------------------------------------------
# The whole bar, for a widget that keeps one `VBar` as state
# ---------------------------------------------------------------------------

import rui_drawing
import raylib

type VBar* = object
  dragging*: bool     ## the thumb is held
  hover*: bool        ## the pointer is over the track
  grab*: float32      ## where on the thumb it was taken

proc shown*(track: Rect, contentH, viewH: float32): bool =
  contentH > viewH and track.height > 0

proc barMove*(bar: var VBar, track: Rect, contentH, viewH: float32,
              scrollY: var float32, p: Point): bool =
  ## Feed every pointer move. True when the bar used it (a drag in progress):
  ## the widget then skips its row hover. `bar.hover` follows the pointer.
  if bar.dragging:
    scrollY = barDragTo(track, contentH, viewH, bar.grab, p.y)
    return true
  bar.hover = shown(track, contentH, viewH) and track.contains(p.x, p.y)
  false

proc barDown*(bar: var VBar, track: Rect, contentH, viewH, page: float32,
              scrollY: var float32, p: Point): bool =
  ## Feed a press. True when it landed on the bar (thumb or track): the widget
  ## captures the pointer when `bar.dragging` is set and stops handling it.
  let press = barPress(track, contentH, viewH, scrollY, p)
  case press.kind
  of bpThumb:
    bar.dragging = true
    bar.grab = press.grab
    true
  of bpPageUp:
    scrollY = clamp(scrollY - page, 0.0'f32, max(0.0'f32, contentH - viewH)); true
  of bpPageDown:
    scrollY = clamp(scrollY + page, 0.0'f32, max(0.0'f32, contentH - viewH)); true
  of bpNone: false

proc barUp*(bar: var VBar): bool =
  ## True when a thumb drag just ended.
  result = bar.dragging
  bar.dragging = false

proc drawBar*(bar: VBar, track: Rect, contentH, viewH, scrollY: float32,
              props: ThemeProps) =
  ## The theme's scroll bar, its thumb strengthened while held or hovered.
  if not shown(track, contentH, viewH): return
  drawScrollbar(track, contentH, viewH, scrollY, props)
  if bar.dragging or bar.hover:
    let thumb = thumbRect(track, contentH, viewH, scrollY)
    drawRoundedRect(Rect(x: thumb.x + 1, y: thumb.y, width: thumb.width - 2,
                         height: thumb.height), (thumb.width - 2) / 2,
                    props.borderColor.get(GRAY).withAlpha(0.45'f32))

# ---------------------------------------------------------------------------
# What every scrolling row list does with the pointer
# ---------------------------------------------------------------------------
##
## ListView, ListBox, TreeView, DataTable and DataGrid each keep `scrollY` and a
## `vbar: VBar` and call these from their mouse handlers; the geometry (which
## rows, where the bar is) is the only thing each supplies.

template barTrack*(widget: untyped): Rect =
  ## The scroll bar's track: down the right edge, the full height.
  Rect(x: widget.bounds.x + widget.bounds.width - currentTheme.scrollbarThickness,
       y: widget.bounds.y, width: currentTheme.scrollbarThickness,
       height: widget.bounds.height)

proc rowsWheel*(w: Widget, vp: RowViewport, total: int, delta: float32,
                scrollY: var float32): bool =
  ## A wheel notch. True when the list is now near its end (to fetch more).
  let moved = vp.scrolledBy(delta, total)
  if moved != scrollY:
    scrollY = moved
    w.isDirty = true
  vp.nearEnd(total)

proc rowsMove*(w: Widget, bar: var VBar, scrollY: var float32, track: Rect,
               vp: RowViewport, total: int, p: Point): tuple[taken: bool, row: int] =
  ## A pointer move. `taken`: a thumb drag used it (the widget does nothing more).
  ## Otherwise `row` is the row under the pointer, or -1 over the bar or off the rows.
  let content = vp.contentHeight(total)
  let hoverWas = bar.hover
  if bar.barMove(track, content, vp.height, scrollY, p):
    w.isDirty = true
    return (true, -1)
  if bar.hover != hoverWas: w.isDirty = true
  (false, if bar.hover: -1 else: vp.rowAt(p.y, total))

proc rowsDown*(w: Widget, bar: var VBar, scrollY: var float32, track: Rect,
               vp: RowViewport, total: int, p: Point): bool =
  ## A press. True when it landed on the scroll bar (thumb: a drag begins and the
  ## widget holds the pointer; track: a page).
  let content = vp.contentHeight(total)
  let page = max(vp.height - vp.rowHeight, vp.rowHeight)
  if bar.barDown(track, content, vp.height, page, scrollY, p):
    if bar.dragging: capturePointer(w)
    w.isDirty = true
    return true
  false

proc rowsUp*(w: Widget, bar: var VBar): bool =
  ## A release. True when it ended a thumb drag.
  if bar.barUp():
    w.isDirty = true
    return true
  false
