## One axis of a zoomable, pannable view, shared by everything that shows it.
##
## A waveform, the ruler over it, the playhead and selection on it, the lanes
## of a video editor, a Plot's x axis, a Timeline: each maps data units
## (seconds, samples, x) to pixels the same way, and when one zooms the others
## must follow. So the mapping is a value, `AxisView`, held in a `Link`, and
## every widget showing it takes the same Link:
##
## ```nim
## let time = newLink(wholeView(0.0, song.seconds))       # all of it, to start
## ui:
##   Column:
##     Ruler(view = time, ticks = timecodeTicks(25))
##     Waveform(source = song, view = time)
## ```
##
## The view is *data units per pixel* and *the data at the left edge*, so a
## wider window shows more, not the same stretched -- as in an audio or video
## editor. `wholeView` starts "fitted": all of `lo .. hi` at whatever width it
## is laid out at, until it is zoomed or panned.
##
## The gestures are the same everywhere, and a widget gets them with one line:
## a `ZoomPan` in its state, given every event it does not use itself:
##
## ```nim
## state:
##   zoom: ZoomPan
## events:
##   on_event: return widget.zoom.handle(widget, widget.view, event, widget.bounds)
## layout:
##   widget.followView(widget.view)       # redraw when anyone moves the view
## ```
##
## A drag pans, the wheel pans and Ctrl+wheel zooms about the pointer, two
## fingers pinch, the keys pan (Left/Right), go to the ends (Home/End) and zoom
## (+/-). Zooming keeps the data under the pointer where it is. Panning stays
## inside `lo .. hi`.

import std/[math, json]
import rui_core
import pointers
import value_input
import raylib

type
  AxisView* = object
    start*: float          ## the data at the left (or top) edge
    perPixel*: float       ## data units per pixel (0 while `fitted` and not laid out)
    lo*, hi*: float        ## the data's extent: panning and zooming out stay inside it
    minPerPixel*: float    ## the closest zoom (0: no limit)
    maxPerPixel*: float    ## the farthest zoom (0: all of lo .. hi)
    fitted*: bool          ## show all of lo .. hi at any width, until zoomed or panned

proc wholeView*(lo, hi: float, minPerPixel = 0.0, maxPerPixel = 0.0): AxisView =
  ## All of `lo .. hi`, however wide the widget turns out to be.
  AxisView(start: lo, lo: lo, hi: hi, minPerPixel: minPerPixel,
           maxPerPixel: maxPerPixel, fitted: true)

proc fixedView*(lo, hi, start, perPixel: float, minPerPixel = 0.0,
                maxPerPixel = 0.0): AxisView =
  ## `perPixel` data units to a pixel, `start` at the left edge.
  AxisView(start: start, perPixel: perPixel, lo: lo, hi: hi,
           minPerPixel: minPerPixel, maxPerPixel: maxPerPixel)

proc farthest(v: AxisView, width: float32): float =
  ## The most data a pixel may stand for: the whole extent across the width,
  ## or `maxPerPixel` if that is less.
  let whole = if width > 0 and v.hi > v.lo: (v.hi - v.lo) / float(width) else: Inf
  if v.maxPerPixel > 0: min(v.maxPerPixel, whole) else: whole

proc clampedTo*(v: AxisView, width: float32): AxisView =
  ## `v` made valid for a view `width` pixels wide: a fitted view resolved,
  ## the zoom within its limits, the start inside the extent.
  result = v
  if result.fitted or result.perPixel <= 0:
    result.perPixel = result.farthest(width)
    if result.perPixel == Inf: result.perPixel = 1
    result.start = result.lo
  let far = result.farthest(width)
  if far != Inf: result.perPixel = min(result.perPixel, far)
  if result.minPerPixel > 0: result.perPixel = max(result.perPixel, result.minPerPixel)
  let last = max(result.lo, result.hi - float(width) * result.perPixel)
  result.start = clamp(result.start, result.lo, last)

proc toPixel*(v: AxisView, x: float, left: float32): float32 =
  ## Screen position of data `x`, for a view whose left edge is at `left`.
  ## The view should be `clampedTo` the width first (`resolved` does both).
  if v.perPixel <= 0: return left
  left + float32((x - v.start) / v.perPixel)

proc toData*(v: AxisView, px: float32, left: float32): float =
  ## The data under screen position `px`.
  v.start + float(px - left) * v.perPixel

proc stop*(v: AxisView, width: float32): float =
  ## The data at the right edge.
  v.start + float(width) * v.perPixel

proc zoomedAt*(v: AxisView, factor: float, px, left, width: float32): AxisView =
  ## Zoomed in by `factor` (out, below 1), keeping the data under `px` there.
  let v = v.clampedTo(width)
  let anchor = v.toData(px, left)
  result = v
  result.fitted = false
  result.perPixel = v.perPixel / factor
  result = result.clampedTo(width)
  result.start = anchor - float(px - left) * result.perPixel
  result = result.clampedTo(width)

proc pannedBy*(v: AxisView, pixels, width: float32): AxisView =
  ## Moved `pixels` on (the data slides the other way), inside the extent.
  let v = v.clampedTo(width)
  result = v
  result.fitted = false
  result.start = v.start + float(pixels) * v.perPixel
  result = result.clampedTo(width)

proc showing*(v: AxisView, a, b: float, width: float32): AxisView =
  ## Zoomed to show `a .. b` across the width -- "zoom to selection".
  result = v
  result.fitted = false
  let lo = min(a, b)
  let hi = max(a, b)
  result.perPixel = if hi > lo and width > 0: (hi - lo) / float(width) else: v.perPixel
  result.start = lo
  result = result.clampedTo(width)

proc resolved*(link: Link[AxisView], width: float32): AxisView =
  ## The view as it is drawn at `width`: a fitted one worked out, all of it
  ## inside its limits. Each widget calls this when it lays out or draws.
  link.value.clampedTo(width)

# ---------------------------------------------------------------------------
# The gestures, the same in every widget on a view
# ---------------------------------------------------------------------------

type ZoomPan* = object
  ## A widget's zooming and panning of a view: keep one in `state:` and give
  ## it every event (`handle`). It remembers what a gesture needs between
  ## events -- a drag that is panning, the fingers of a pinch.
  fingers*: Pointers      ## the pointers down: two make a pinch
  panning*: bool          ## a drag that pans is under way
  lastX: float32

proc `%`*(z: ZoomPan): JsonNode =
  %*{"panning": z.panning, "pointers": z.fingers.count}

const
  WheelZoom* = 1.25       ## one Ctrl+wheel notch, one + or - key
  WheelPan* = 40.0'f32    ## pixels a plain wheel notch pans

proc change(link: Link[AxisView], next: AxisView): bool =
  ## Set the view if it moved. True when it did.
  if next == link.value: return false
  link.value = next
  true

proc wheel(link: Link[AxisView], e: GuiEvent, left, width: float32): bool =
  ## Ctrl+wheel zooms about the pointer; a plain wheel pans. False when a
  ## plain wheel could not pan (at an end): an enclosing scroll view gets it.
  if e.ctrl:
    discard link.change(link.value.zoomedAt(
      if e.wheelDelta > 0: WheelZoom else: 1 / WheelZoom, e.mousePos.x, left, width))
    return true
  link.change(link.value.pannedBy(-e.wheelDelta * WheelPan, width))

proc down(input: var ZoomPan, w: Widget, e: GuiEvent): bool =
  ## A press that pans (or, with a second finger, pinches). Call it once the
  ## widget has decided the press is not on one of its own things.
  let fed = input.fingers.feed(e)
  if fed.pinching or e.pointerId != 0:
    input.panning = false            # the pinch takes over
    return true
  input.panning = true
  input.lastX = e.mousePos.x
  capturePointer(w)
  true

proc move(input: var ZoomPan, link: Link[AxisView], e: GuiEvent,
               left, width: float32): bool =
  ## A move: pans while dragging, zooms and pans with two fingers. False when
  ## it was neither (the widget may use it for hover).
  let fed = input.fingers.feed(e)
  if fed.pinching:
    var v = link.value.zoomedAt(fed.change.scale, fed.change.anchor.x, left, width)
    v = v.pannedBy(-fed.change.pan.x, width)
    discard link.change(v)
    return true
  if e.pointerId != 0: return true
  if input.panning:
    discard link.change(link.value.pannedBy(input.lastX - e.mousePos.x, width))
    input.lastX = e.mousePos.x
    return true
  false

proc up(input: var ZoomPan, e: GuiEvent): bool =
  ## A release. True when it ended a pan or a finger of a pinch.
  discard input.fingers.feed(e)
  if e.pointerId != 0:
    if input.fingers.has(0):         # back to one finger: it pans on
      input.panning = true
      input.lastX = input.fingers.pos(0).x
    return true
  result = input.panning
  input.panning = false

proc key(link: Link[AxisView], e: GuiEvent, left, width: float32,
              step: float32 = 0): bool =
  ## Left/Right pan `step` pixels (an eighth of the view by default),
  ## Home/End go to the ends, + and - zoom about the middle.
  let step = if step > 0: step else: max(1'f32, width / 8)
  case e.key
  of KeyboardKey.Left: discard link.change(link.value.pannedBy(-step, width))
  of KeyboardKey.Right: discard link.change(link.value.pannedBy(step, width))
  of KeyboardKey.Home:
    var v = link.value.clampedTo(width)
    v.fitted = false
    v.start = v.lo
    discard link.change(v.clampedTo(width))
  of KeyboardKey.End:
    var v = link.value.clampedTo(width)
    v.fitted = false
    v.start = v.hi
    discard link.change(v.clampedTo(width))
  else:
    let dir = e.key.zoomDirection
    if dir == 0: return false
    discard link.change(link.value.zoomedAt(
      if dir > 0: WheelZoom else: 1 / WheelZoom, left + width / 2, left, width))
  true

proc followView*(w: Widget, link: Link[AxisView]) =
  ## Redraw `w` whenever the view changes, whoever changed it. Call it in
  ## `layout:`.
  if link != nil and not link.hasDependent(w): link.addDependent(w)

proc handle*(z: var ZoomPan, w: Widget, view: Link[AxisView], e: GuiEvent,
             area: Rect, keyStep = 0'f32): bool =
  ## Any event, for zooming and panning `view` across `area` (its x and
  ## width): the one call a widget on a view makes, from `on_event:`. True
  ## when the event was used.
  ##
  ## A drag pans; the wheel pans and Ctrl+wheel zooms about the pointer (a
  ## plain wheel at an end is left to an enclosing scroll view); two fingers
  ## pinch; when `w` is focused, Left/Right pan (`keyStep` pixels, an eighth
  ## of the view by default), Home/End go to the ends and +/- zoom.
  if view == nil: return false
  case e.kind
  of evMouseWheel: wheel(view, e, area.x, area.width)
  of evMouseDown:
    if e.pointerId == 0 and not area.contains(e.mousePos.x, e.mousePos.y): false
    else: z.down(w, e)
  of evMouseMove: z.move(view, e, area.x, area.width)
  of evMouseUp: z.up(e)
  of evKeyDown: w.focused and key(view, e, area.x, area.width, keyStep)
  else: false
