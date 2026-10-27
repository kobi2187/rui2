## Lanes -- rows on one shared time axis, holding clips that are dragged,
## trimmed and moved between rows: the body of a video editor, a DAW, a
## Gantt chart, a broadcast rundown.
##
## ```nim
## let time = newLink(wholeView(0.0, 120.0))
## ui:
##   Lanes(view = time, lanes = @[lane("Video"), lane("Music", 64)],
##         clips = @[clip("intro", 0, 0.0, 12.0, "Intro"),
##                   clip("song", 1, 2.0, 90.0, "Song", wave = song)],
##         snapStep = 1.0):
##     Label(text = "Video")                       # lane 0's header
##     Row: Label(text = "Music"); Switch()        # lane 1's: any widgets
## ```
##
## - **Headers are real widgets**: child *i* sits in the header column beside
##   lane *i* (`headerWidth` wide). A lane with no child shows its name.
## - **Clips** move with a drag on their body (to another lane, too), and are
##   trimmed by a drag on either edge. Edges snap (axis_snap.nim) to other
##   clips' edges and the playhead within a few pixels, else to `snapStep`;
##   Alt turns snapping off. Each change is reported (`onClipChanged`) after
##   it is made to `clips`.
## - A clip given samples (`wave`, from `waveOffset` seconds into them) draws
##   them inside it (wave_draw.nim): an audio clip shows its audio.
## - **The axis** is the shared view (view_range.nim), over the lanes' part
##   (right of the headers): a drag on empty space pans, the wheel pans,
##   Ctrl+wheel zooms. Put a Ruler above it, indented by `headerWidth`.
## - A click selects a clip (`selected`, `onClipSelect`); Delete asks for it
##   to go (`onClipDelete` -- the app decides).

import rui_core
import rui_drawing
import std/[options, math]
import raylib
import ../view_range
import ../pointers
import ../sources/samples
import axis_snap
import wave_draw

type
  Lane* = object
    name*: string
    height*: float32             ## 0: `laneHeight`

  LaneClip* = object
    id*: string
    lane*: int
    start*, length*: float       ## data units (seconds) on the view
    label*: string
    color*: Option[Color]        ## the theme's accent when unset
    wave*: SampleSource          ## samples to draw inside the clip, if any
    waveOffset*: float           ## where in `wave` the clip begins (seconds)

  ClipDrag = enum
    cdNone, cdMove, cdTrimStart, cdTrimEnd

proc lane*(name: string, height = 0'f32): Lane = Lane(name: name, height: height)
proc clip*(id: string, lane: int, start, length: float, label = "",
           color = none(Color), wave: SampleSource = nil, waveOffset = 0.0): LaneClip =
  LaneClip(id: id, lane: lane, start: start, length: length, label: label,
           color: color, wave: wave, waveOffset: waveOffset)

proc laneTop(widget: Widget, i: int): float32
proc laneAt(widget: Widget, y: float32): int
proc clipRect(widget: Widget, i: int): Rect
proc snapEdge(widget: Widget, at: float, e: GuiEvent): float
proc changed(widget: Widget, i: int)

const
  EdgeGrab = 6'f32
  MinClipPixels = 4'f32

template areaLeft(widget: untyped): float32 = widget.bounds.x + widget.headerWidth
template areaWidth(widget: untyped): float32 = max(1'f32, widget.bounds.width - widget.headerWidth)

definePrimitive(Lanes):
  props:
    view: Link[AxisView] = nil
    lanes: seq[Lane] = @[]
    clips: seq[LaneClip] = @[]
    playhead: Link[float] = nil   ## drawn across the lanes; clip edges snap to it
    headerWidth: float32 = 120.0
    laneHeight: float32 = 48.0
    snapStep: float = 0.0
    intent: ThemeIntent = Default

  state:
    selected: int                 ## the selected clip's index; -1: none
    drag: ClipDrag
    grabAt: float                 ## data under the pointer when the drag began
    grabStart: float
    grabLength: float
    input: ViewInput

  actions:
    onClipSelect(index: int)
    onClipChanged(index: int, clip: LaneClip)
    onClipDelete(index: int)

  init:
    widget.focusable = true
    widget.multiPointer = true
    widget.selected = -1

  events:
    on_mouse_wheel:
      if widget.view == nil: return false
      return viewWheel(widget.view, event, widget.areaLeft, widget.areaWidth)

    on_mouse_down:
      if widget.view == nil: return false
      if event.mousePos.x < widget.areaLeft: return false     # the headers' own
      if event.pointerId == 0 and widget.input.fingers.count == 0:
        let v = widget.view.resolved(widget.areaWidth)
        for i in countdown(widget.clips.high, 0):              # topmost first
          let r = widget.clipRect(i)
          if not r.contains(event.mousePos.x, event.mousePos.y): continue
          widget.selected = i
          widget.grabAt = v.toData(event.mousePos.x, widget.areaLeft)
          widget.grabStart = widget.clips[i].start
          widget.grabLength = widget.clips[i].length
          widget.drag = if event.mousePos.x - r.x <= EdgeGrab: cdTrimStart
                        elif r.x + r.width - event.mousePos.x <= EdgeGrab: cdTrimEnd
                        else: cdMove
          capturePointer(widget)
          widget.isDirty = true
          if widget.onClipSelect != nil: widget.onClipSelect(i)
          return true
        if widget.selected >= 0:
          widget.selected = -1
          widget.isDirty = true
          if widget.onClipSelect != nil: widget.onClipSelect(-1)
      return widget.input.viewDown(widget, event)

    on_mouse_move:
      if widget.view == nil: return false
      if widget.drag == cdNone:
        return widget.input.viewMove(widget.view, event, widget.areaLeft, widget.areaWidth)
      let v = widget.view.resolved(widget.areaWidth)
      let i = widget.selected
      let delta = v.toData(event.mousePos.x, widget.areaLeft) - widget.grabAt
      let minLength = float(MinClipPixels) * v.perPixel
      var c = widget.clips[i]
      case widget.drag
      of cdMove:
        # Whichever edge needs the smaller nudge to snap decides.
        let start = widget.grabStart + delta
        let byStart = widget.snapEdge(start, event)
        let byEnd = widget.snapEdge(start + c.length, event) - c.length
        c.start = max(v.lo, if abs(byStart - start) <= abs(byEnd - start): byStart else: byEnd)
        let l = widget.laneAt(event.mousePos.y)
        if l >= 0: c.lane = l
      of cdTrimStart:
        let stop = widget.grabStart + widget.grabLength
        let start = min(widget.snapEdge(widget.grabStart + delta, event), stop - minLength)
        c.start = max(v.lo, start)
        c.length = stop - c.start
        c.waveOffset = widget.clips[i].waveOffset + (c.start - widget.clips[i].start)
      of cdTrimEnd:
        let stop = max(widget.snapEdge(widget.grabStart + widget.grabLength + delta, event),
                       c.start + minLength)
        c.length = stop - c.start
      of cdNone: discard
      if c != widget.clips[i]:
        widget.clips[i] = c
        widget.changed(i)
      return true

    on_mouse_up:
      if widget.drag != cdNone:
        widget.drag = cdNone
        return true
      return widget.input.viewUp(event)

    on_key_down:
      if not widget.focused or widget.view == nil: return false
      if event.key in {KeyboardKey.Delete, KeyboardKey.Backspace} and widget.selected >= 0:
        if widget.onClipDelete != nil: widget.onClipDelete(widget.selected)
        return true
      return viewKey(widget.view, event, widget.areaLeft, widget.areaWidth)

  layout:
    widget.followView(widget.view)
    if widget.playhead != nil and not widget.playhead.hasDependent(widget):
      widget.playhead.addDependent(widget)
    if widget.bounds.width <= 0: widget.bounds.width = 600
    if widget.bounds.height <= 0:
      widget.bounds.height = widget.laneTop(widget.lanes.len) - widget.bounds.y
    for i, child in widget.children:
      if i >= widget.lanes.len:
        child.visible = false
        continue
      let top = widget.laneTop(i)
      child.arrange(Rect(x: widget.bounds.x + 6, y: top + 4, width: widget.headerWidth - 12,
                         height: widget.laneTop(i + 1) - top - 8))
    if widget.selected >= widget.clips.len: widget.selected = -1

  render:
    let props = currentTheme.getThemeProps(widget.intent, Normal)   # a view: no hover tint
    let ink = props.foregroundColor.get(BLACK)
    let b = widget.bounds
    drawRect(b, props.backgroundColor.get(WHITE))
    let accent = props.activeColor.get(ink)
    var style = props.captionStyle(ink)
    # Lanes and their header column.
    for i in 0 ..< widget.lanes.len:
      let top = widget.laneTop(i)
      let bottom = widget.laneTop(i + 1)
      if i mod 2 == 1:
        drawRect(Rect(x: b.x, y: top, width: b.width, height: bottom - top), ink.withAlpha(0.04))
      drawLine(b.x, bottom - 0.5, b.x + b.width, bottom - 0.5, ink.withAlpha(0.15))
      if i >= widget.children.len:
        drawStyledText(widget.lanes[i].name, b.x + 8, top + 6, style)
    drawLine(widget.areaLeft - 0.5, b.y, widget.areaLeft - 0.5, b.y + b.height, ink.withAlpha(0.3))
    if widget.view == nil: return
    let v = widget.view.resolved(widget.areaWidth)
    let area = Rect(x: widget.areaLeft, y: b.y, width: widget.areaWidth, height: b.height)
    let clip = beginClip(area)
    for i, c in widget.clips:
      let r = widget.clipRect(i)
      if r.x > area.x + area.width or r.x + r.width < area.x or r.height <= 0: continue
      let fill = c.color.get(accent)
      drawBox(r, min(4'f32, r.width / 2), fill.withAlpha(0.85), ink, 0)
      if c.wave != nil:
        c.wave.drawnBy(widget)
        var wv = v
        wv.start = v.start - c.start + c.waveOffset    # the clip's own time, in its samples
        let inner = Rect(x: r.x, y: r.y + 14, width: r.width, height: max(1'f32, r.height - 16))
        let saved = beginClip(Rect(x: max(r.x, area.x), y: r.y,
                                   width: min(r.x + r.width, area.x + area.width) - max(r.x, area.x),
                                   height: r.height))
        drawWave(c.wave, 0, fixedView(wv.lo, wv.hi, wv.start, wv.perPixel),
                 Rect(x: area.x, y: inner.y, width: area.width, height: inner.height),
                 -1.0, 1.0, ink.withAlpha(0.6))
        endClip(saved)
      if c.label.len > 0:
        var onClip = style
        onClip.color = if contrastRatio(fill, BLACK) >= contrastRatio(fill, WHITE): BLACK else: WHITE
        onClip.fontSize = max(10'f32, style.fontSize - 2)
        drawStyledText(c.label, max(r.x, area.x) + 4, r.y + 1, onClip)
      if i == widget.selected:
        drawBox(r, min(4'f32, r.width / 2), Color(), ink, 2)
    if widget.playhead != nil:
      let x = v.toPixel(widget.playhead.value, area.x)
      let c = currentTheme.getThemeProps(Danger).activeColor.get(accent)
      drawLine(x, b.y, x, b.y + b.height, c, 2)
    endClip(clip)
    if widget.focused: drawThemedFocusRing(b, props)

proc laneTop(widget: Widget, i: int): float32 =
  ## Screen y where lane `i` begins (or, for i = lanes.len, where the last ends).
  let widget = Lanes(widget)
  result = widget.bounds.y
  for k in 0 ..< min(i, widget.lanes.len):
    result += (if widget.lanes[k].height > 0: widget.lanes[k].height else: widget.laneHeight)

proc laneAt(widget: Widget, y: float32): int =
  ## The lane under screen `y`, the nearest end one beyond them.
  let widget = Lanes(widget)
  if widget.lanes.len == 0: return -1
  for i in 0 ..< widget.lanes.len:
    if y < widget.laneTop(i + 1): return i
  widget.lanes.high

proc clipRect(widget: Widget, i: int): Rect =
  ## Where clip `i` is drawn -- and where a press finds it.
  let widget = Lanes(widget)
  let c = widget.clips[i]
  if c.lane < 0 or c.lane >= widget.lanes.len or widget.view == nil: return Rect()
  let v = widget.view.resolved(widget.areaWidth)
  let x0 = v.toPixel(c.start, widget.areaLeft)
  let x1 = v.toPixel(c.start + c.length, widget.areaLeft)
  let top = widget.laneTop(c.lane)
  Rect(x: x0, y: top + 3, width: max(MinClipPixels, x1 - x0),
       height: widget.laneTop(c.lane + 1) - top - 6)

proc snapEdge(widget: Widget, at: float, e: GuiEvent): float =
  ## `at` snapped to the other clips' edges, the playhead, or the grid.
  let widget = Lanes(widget)
  var targets: seq[float]
  for i, c in widget.clips:
    if i == widget.selected: continue
    targets.add c.start
    targets.add c.start + c.length
  if widget.playhead != nil: targets.add widget.playhead.value
  let v = widget.view.resolved(widget.areaWidth)
  snapTo(widget.snapStep, 6, targets).snapped(at, v.perPixel, off = e.alt)

proc changed(widget: Widget, i: int) =
  let widget = Lanes(widget)
  widget.isDirty = true
  if widget.onClipChanged != nil: widget.onClipChanged(i, widget.clips[i])
