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
