## AxisMarks -- the playhead, the selection and the markers on a view, laid
## over whatever shows it: a Waveform, Lanes, a Plot.
##
## ```nim
## let time = newLink(wholeView(0.0, song.seconds))
## let playhead = newLink(0.0)
## let selection = newLink(noSpan())
## ui:
##   Stack(fit = StackFit.expand):
##     Waveform(source = song, view = time)
##     AxisMarks(view = time, playhead = playhead, selection = selection,
##               markers = @[marker(12.5, "Chorus")], snapStep = 0.5)
## ```
##
## It draws only the marks: the rest is see-through. With the pointer:
## - a click moves the playhead there (`onSeek`) and clears the selection;
## - a drag selects from where it began (`onSelect`); Shift+click extends the
##   selection to the pointer;
## - a drag on an edge of the selection moves that edge;
## - a drag on a marker's flag moves the marker (`onMarkerMoved`);
## - the wheel zooms and pans the view (view_range.nim).
## Positions snap (axis_snap.nim) to the markers, the playhead and the
## selection's edges within a few pixels, else to `snapStep`; Alt turns it off.
## The playhead, the selection and the view are Links: anything else -- a
## transport, a Ruler's `onSeek`, a menu's "select all" -- can set them too.

import rui_core
import rui_drawing
import std/[options, math]
import raylib
import ../view_range
import axis_snap
export axis_snap

type
  AxisSpan* = object
    lo*, hi*: float              ## empty when hi <= lo

  AxisMarker* = object
    at*: float
    label*: string
    color*: Option[Color]        ## the theme's warning colour when unset

  MarksDrag = enum
    mdNone, mdSeek, mdSelect, mdLo, mdHi, mdMarker

proc noSpan*(): AxisSpan = AxisSpan(lo: 0, hi: 0)
proc span*(a, b: float): AxisSpan = AxisSpan(lo: min(a, b), hi: max(a, b))
proc isEmpty*(s: AxisSpan): bool = s.hi <= s.lo
proc marker*(at: float, label = "", color = none(Color)): AxisMarker =
  AxisMarker(at: at, label: label, color: color)

proc snapAt(widget: Widget, x: float32, e: GuiEvent): float
proc setSelection(widget: Widget, s: AxisSpan)

const
  EdgeGrab = 5'f32                ## pixels either side of an edge that take it
  FlagHeight = 16'f32             ## a marker's flag at the top

definePrimitive(AxisMarks):
  props:
    view: Link[AxisView] = nil
    playhead: Link[float] = nil
    selection: Link[AxisSpan] = nil
    markers: seq[AxisMarker] = @[]
    snapStep: float = 0.0         ## snap to this grid (0: only to marks nearby)
    intent: ThemeIntent = Default

  state:
    drag: MarksDrag
    anchor: float                 ## where a selection drag began (data)
    pressX: float32
    markerIndex: int

  actions:
    onSeek(at: float)
    onSelect(lo: float, hi: float)
    onMarkerMoved(index: int, at: float)

  events:
    on_mouse_wheel:
      if widget.view == nil: return false
      return viewWheel(widget.view, event, widget.bounds.x, widget.bounds.width)

    on_mouse_down:
      if widget.view == nil or event.pointerId != 0: return false
      let v = widget.view.resolved(widget.bounds.width)
      let x = event.mousePos.x
      let at = widget.snapAt(x, event)
      widget.pressX = x
      capturePointer(widget)
      # A marker's flag, then an edge of the selection, then empty space.
      for i, m in widget.markers:
        let mx = v.toPixel(m.at, widget.bounds.x)
        if abs(mx - x) <= EdgeGrab and event.mousePos.y <= widget.bounds.y + FlagHeight:
          widget.drag = mdMarker
          widget.markerIndex = i
          return true
      if widget.selection != nil and not widget.selection.value.isEmpty:
        let s = widget.selection.value
        if abs(v.toPixel(s.lo, widget.bounds.x) - x) <= EdgeGrab:
          widget.drag = mdLo
          return true
        if abs(v.toPixel(s.hi, widget.bounds.x) - x) <= EdgeGrab:
          widget.drag = mdHi
          return true
        if event.shift:
          let next = span(min(s.lo, at), max(s.hi, at))
          widget.setSelection(next)
          widget.drag = if at < s.lo: mdLo else: mdHi
          return true
      widget.anchor = at
      widget.drag = mdSeek          # a selection once it moves
      return true

    on_mouse_move:
      if widget.drag == mdNone: return false
      let at = widget.snapAt(event.mousePos.x, event)
      case widget.drag
      of mdSeek:
        if abs(event.mousePos.x - widget.pressX) >= 3:
          widget.drag = mdSelect
          widget.setSelection(span(widget.anchor, at))
      of mdSelect: widget.setSelection(span(widget.anchor, at))
      of mdLo, mdHi:
        let s = widget.selection.value
        let other = if widget.drag == mdLo: s.hi else: s.lo
        if (widget.drag == mdLo and at > other) or (widget.drag == mdHi and at < other):
          widget.drag = if widget.drag == mdLo: mdHi else: mdLo   # dragged past the other edge
        widget.setSelection(span(other, at))
      of mdMarker:
        widget.markers[widget.markerIndex].at = at
        widget.isDirty = true
        if widget.onMarkerMoved != nil: widget.onMarkerMoved(widget.markerIndex, at)
      of mdNone: discard
      return true

    on_mouse_up:
      if widget.drag == mdNone: return false
      if widget.drag == mdSeek:
        let at = widget.anchor
        if widget.playhead != nil: widget.playhead.value = at
        widget.setSelection(noSpan())
        if widget.onSeek != nil: widget.onSeek(at)
      widget.drag = mdNone
      widget.isDirty = true
      return true

  layout:
    widget.followView(widget.view)
    if widget.playhead != nil and not widget.playhead.hasDependent(widget):
      widget.playhead.addDependent(widget)
    if widget.selection != nil and not widget.selection.hasDependent(widget):
      widget.selection.addDependent(widget)

  render:
    if widget.view == nil: return
    let props = currentTheme.getThemeProps(widget.intent, Normal)   # a view: no hover tint
    let b = widget.bounds
    let v = widget.view.resolved(b.width)
    let accent = props.activeColor.get(props.foregroundColor.get(BLACK))
    let clip = beginClip(b)
    if widget.selection != nil and not widget.selection.value.isEmpty:
      let s = widget.selection.value
      let x0 = max(b.x, v.toPixel(s.lo, b.x))
      let x1 = min(b.x + b.width, v.toPixel(s.hi, b.x))
      if x1 > x0:
        drawRect(Rect(x: x0, y: b.y, width: x1 - x0, height: b.height), accent.withAlpha(0.18))
      drawLine(v.toPixel(s.lo, b.x), b.y, v.toPixel(s.lo, b.x), b.y + b.height, accent.withAlpha(0.7))
      drawLine(v.toPixel(s.hi, b.x), b.y, v.toPixel(s.hi, b.x), b.y + b.height, accent.withAlpha(0.7))
    let warn = currentTheme.getThemeProps(Warning).activeColor.get(accent)
    var style = props.captionStyle(props.foregroundColor.get(BLACK))
    style.fontSize = max(10'f32, style.fontSize - 3)
    for m in widget.markers:
      let x = v.toPixel(m.at, b.x)
      if x < b.x - 100 or x > b.x + b.width: continue
      let c = m.color.get(warn)
      drawLine(x, b.y, x, b.y + b.height, c.withAlpha(0.8))
      let w = (if m.label.len > 0: measureText(m.label, style).width else: 0'f32) + 8
      drawRect(Rect(x: x, y: b.y, width: w, height: FlagHeight), c)
      if m.label.len > 0:
        var onFlag = style
        onFlag.color = if contrastRatio(c, BLACK) >= contrastRatio(c, WHITE): BLACK else: WHITE
        drawStyledText(m.label, x + 4, b.y + 1, onFlag)
    if widget.playhead != nil:
      let x = v.toPixel(widget.playhead.value, b.x)
      let c = currentTheme.getThemeProps(Danger).activeColor.get(accent)
      drawLine(x, b.y, x, b.y + b.height, c, 2)
      drawTriangleAnyWinding(Vector2(x: x - 6, y: b.y), Vector2(x: x, y: b.y + 8),
                             Vector2(x: x + 6, y: b.y), c)
    endClip(clip)

proc snapAt(widget: Widget, x: float32, e: GuiEvent): float =
  ## The data under screen `x`, snapped to the marks nearby or the grid.
  let widget = AxisMarks(widget)
  let v = widget.view.resolved(widget.bounds.width)
  var targets: seq[float]
  for i, m in widget.markers:
    if not (widget.drag == mdMarker and i == widget.markerIndex): targets.add m.at
  if widget.playhead != nil: targets.add widget.playhead.value
  if widget.selection != nil and not widget.selection.value.isEmpty and
     widget.drag notin {mdLo, mdHi, mdSelect}:
    targets.add widget.selection.value.lo
    targets.add widget.selection.value.hi
  let raw = clamp(v.toData(x, widget.bounds.x), v.lo, v.hi)
  clamp(snapTo(widget.snapStep, 6, targets).snapped(raw, v.perPixel, off = e.alt), v.lo, v.hi)

proc setSelection(widget: Widget, s: AxisSpan) =
  let widget = AxisMarks(widget)
  if widget.selection != nil: widget.selection.value = s
  widget.isDirty = true
  if widget.onSelect != nil: widget.onSelect(s.lo, s.hi)
