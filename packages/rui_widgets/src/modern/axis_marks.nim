## Marks on a view: a playhead, a selection, markers -- and snapping to them.
##
## Not a widget: a `Marks` is the marks themselves, handed to whatever shows a
## view (`Waveform(marks = ...)`, `Lanes(marks = ...)`). Hand the same one to
## two widgets and they share the playhead and the selection.
##
## ```nim
## let marks = newMarks(playhead = newLink(0.0), selection = newLink(noSpan()),
##                      markers = @[marker(12.5, "Chorus")], snapStep = 0.5)
## ui:
##   Waveform(source = song, view = time, marks = marks,
##            onSeek = proc(at: float) = echo "seek ", at)
## ```
##
## With the pointer, on a widget showing them:
## - a click moves the playhead there and clears the selection;
## - a drag selects; Shift+click extends the selection;
## - a drag on an edge of the selection moves that edge;
## - a drag on a marker's flag moves the marker.
## The playhead, the selection and the markers are Links: every widget showing
## them redraws when they change, whoever changed them.
## Positions snap (axis_snap.nim) to the markers, the playhead and the
## selection's edges within a few pixels, else to `snapStep`; Alt turns it off.
##
## In your own primitive on a view: `widget.showMarks(marks)` in `layout:`,
## `marks.draw(view, area)` in `render:`, and in a pointer handler
## `marks.handle(...)`, which changes the marks and says what it did
## (`MarksDone`) -- it calls nothing of yours, so the handler decides what
## follows (an `onSeek` of its own, the view's zooming when it was not used).

import rui_core
import rui_drawing
import std/[options, json]
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

  MarksDid* = enum
    mdNothing      ## not the marks' event: leave it to the view
    mdBusy         ## used, mid-gesture: nothing to report yet
    mdSought       ## the playhead was put at `at`
    mdSelected     ## the selection changed (it is in `selection`)
    mdMoved        ## marker `index` moved to `at`

  MarksDone* = object
    did*: MarksDid
    at*: float
    index*: int

  Marks* = ref object
    playhead*: Link[float]       ## nil: no playhead
    selection*: Link[AxisSpan]   ## nil: no selection
    markers*: Link[seq[AxisMarker]]
    snapStep*: float             ## snap to this grid (0: only to marks nearby)
    drag: MarksDrag
    anchor: float                ## where a selection drag began (data)
    pressX: float32
    markerIndex: int

proc noSpan*(): AxisSpan = AxisSpan(lo: 0, hi: 0)
proc span*(a, b: float): AxisSpan = AxisSpan(lo: min(a, b), hi: max(a, b))
proc isEmpty*(s: AxisSpan): bool = s.hi <= s.lo
proc marker*(at: float, label = "", color = none(Color)): AxisMarker =
  AxisMarker(at: at, label: label, color: color)

proc newMarks*(playhead: Link[float] = nil, selection: Link[AxisSpan] = nil,
               markers: seq[AxisMarker] = @[], snapStep = 0.0): Marks =
  Marks(playhead: playhead, selection: selection, markers: newLink(markers),
        snapStep: snapStep)

proc used*(d: MarksDone): bool = d.did != mdNothing

proc `%`*(m: Marks): JsonNode =
  ## What scripting sees: the marks, not the callbacks or the widgets.
  if m == nil: return newJNull()
  result = %*{"markers": m.markers.value.len, "snapStep": m.snapStep}
  if m.playhead != nil: result["playhead"] = %m.playhead.value
  if m.selection != nil: result["selection"] = %*[m.selection.value.lo, m.selection.value.hi]

const
  EdgeGrab = 5'f32                ## pixels either side of an edge that take it
  FlagHeight* = 16'f32            ## a marker's flag at the top

proc showMarks*(w: Widget, m: Marks) =
  ## `w` draws `m`: redraw it whenever the playhead, the selection or a
  ## marker moves. Call it in `layout:`.
  if m == nil: return
  if m.playhead != nil and not m.playhead.hasDependent(w): m.playhead.addDependent(w)
  if m.selection != nil and not m.selection.hasDependent(w): m.selection.addDependent(w)
  if not m.markers.hasDependent(w): m.markers.addDependent(w)

proc targets*(m: Marks, skip = -1, edges = true): seq[float] =
  ## What a position snaps to: the markers (but `skip`), the playhead and,
  ## with `edges`, the selection's edges.
  if m == nil: return
  for i, mk in m.markers.value:
    if i != skip: result.add mk.at
  if m.playhead != nil: result.add m.playhead.value
  if edges and m.selection != nil and not m.selection.value.isEmpty:
    result.add m.selection.value.lo
    result.add m.selection.value.hi

proc snapAt(m: Marks, v: AxisView, x, left: float32, e: GuiEvent): float =
  # A selection being drawn or resized does not snap to its own edges.
  let t = m.targets(if m.drag == mdMarker: m.markerIndex else: -1,
                    edges = m.drag notin {mdLo, mdHi, mdSelect})
  let raw = clamp(v.toData(x, left), v.lo, v.hi)
  clamp(snapTo(m.snapStep, 6, t).snapped(raw, v.perPixel, off = e.alt), v.lo, v.hi)

proc setSelection(m: Marks, s: AxisSpan): MarksDone =
  if m.selection != nil: m.selection.value = s
  MarksDone(did: mdSelected)

proc handle*(m: Marks, w: Widget, view: Link[AxisView], e: GuiEvent, area: Rect): MarksDone =
  ## A press, move or release on `w`, which shows the marks over `area`: the
  ## marks changed, and what was done. `mdNothing` for an event that is not
  ## theirs (leave it to the view's zooming). Calls nothing of the caller's.
  if m == nil or view == nil or (m.playhead == nil and m.selection == nil and
                                 m.markers.value.len == 0):
    return MarksDone(did: mdNothing)
  let v = view.resolved(area.width)
  let busy = MarksDone(did: mdBusy)
  case e.kind
  of evMouseDown:
    if e.pointerId != 0 or not area.contains(e.mousePos.x, e.mousePos.y):
      return MarksDone(did: mdNothing)
    let x = e.mousePos.x
    let at = m.snapAt(v, x, area.x, e)
    m.pressX = x
    capturePointer(w)
    for i, mk in m.markers.value:    # a marker's flag first
      if abs(v.toPixel(mk.at, area.x) - x) <= EdgeGrab and e.mousePos.y <= area.y + FlagHeight:
        m.drag = mdMarker
        m.markerIndex = i
        return busy
    if m.selection != nil and not m.selection.value.isEmpty:
      let s = m.selection.value
      if abs(v.toPixel(s.lo, area.x) - x) <= EdgeGrab: (m.drag = mdLo; return busy)
      if abs(v.toPixel(s.hi, area.x) - x) <= EdgeGrab: (m.drag = mdHi; return busy)
      if e.shift:
        m.drag = if at < s.lo: mdLo else: mdHi
        return m.setSelection(span(min(s.lo, at), max(s.hi, at)))
    m.anchor = at
    m.drag = mdSeek                  # a selection, once it moves
    busy
  of evMouseMove:
    if m.drag == mdNone: return MarksDone(did: mdNothing)
    let at = m.snapAt(v, e.mousePos.x, area.x, e)
    case m.drag
    of mdSeek:
      if abs(e.mousePos.x - m.pressX) >= 3 and m.selection != nil:
        m.drag = mdSelect
        return m.setSelection(span(m.anchor, at))
      busy
    of mdSelect: m.setSelection(span(m.anchor, at))
    of mdLo, mdHi:
      let s = m.selection.value
      let other = if m.drag == mdLo: s.hi else: s.lo
      if (m.drag == mdLo and at > other) or (m.drag == mdHi and at < other):
        m.drag = if m.drag == mdLo: mdHi else: mdLo   # dragged past the other edge
      m.setSelection(span(other, at))
    of mdMarker:
      var next = m.markers.value
      next[m.markerIndex].at = at
      m.markers.value = next
      MarksDone(did: mdMoved, at: at, index: m.markerIndex)
    of mdNone: busy
  of evMouseUp:
    if m.drag == mdNone: return MarksDone(did: mdNothing)
    let was = m.drag
    m.drag = mdNone
    if was == mdSeek:
      if m.selection != nil: m.selection.value = noSpan()
      if m.playhead != nil: m.playhead.value = m.anchor
      return MarksDone(did: mdSought, at: m.anchor)
    busy
  else: MarksDone(did: mdNothing)

proc draw*(m: Marks, view: AxisView, area: Rect, intent = ThemeIntent.Default) =
  ## The selection, the markers and the playhead over `area`. `view` must be
  ## resolved for `area.width`.
  if m == nil: return
  let props = currentTheme.getThemeProps(intent, Normal)
  let ink = props.foregroundColor.get(BLACK)
  let accent = props.activeColor.get(ink)
  let b = area
  let clip = beginClip(b)
  if m.selection != nil and not m.selection.value.isEmpty:
    let s = m.selection.value
    let x0 = view.toPixel(s.lo, b.x)
    let x1 = view.toPixel(s.hi, b.x)
    let l = max(b.x, x0)
    let r = min(b.x + b.width, x1)
    if r > l: drawRect(Rect(x: l, y: b.y, width: r - l, height: b.height), accent.withAlpha(0.18))
    drawLine(x0, b.y, x0, b.y + b.height, accent.withAlpha(0.7))
    drawLine(x1, b.y, x1, b.y + b.height, accent.withAlpha(0.7))
  let warn = currentTheme.getThemeProps(Warning).activeColor.get(accent)
  var style = props.captionStyle(ink)
  style.fontSize = max(10'f32, style.fontSize - 3)
  for mk in m.markers.value:
    let x = view.toPixel(mk.at, b.x)
    if x < b.x - 100 or x > b.x + b.width: continue
    let c = mk.color.get(warn)
    drawLine(x, b.y, x, b.y + b.height, c.withAlpha(0.8))
    let w = (if mk.label.len > 0: measureText(mk.label, style).width else: 0'f32) + 8
    drawRect(Rect(x: x, y: b.y, width: w, height: FlagHeight), c)
    if mk.label.len > 0:
      var onFlag = style
      onFlag.color = if contrastRatio(c, BLACK) >= contrastRatio(c, WHITE): BLACK else: WHITE
      drawStyledText(mk.label, x + 4, b.y + 1, onFlag)
  if m.playhead != nil:
    let x = view.toPixel(m.playhead.value, b.x)
    let c = currentTheme.getThemeProps(Danger).activeColor.get(accent)
    drawLine(x, b.y, x, b.y + b.height, c, 2)
    drawTriangleAnyWinding(Vector2(x: x - 6, y: b.y), Vector2(x: x, y: b.y + 8),
                           Vector2(x: x + 6, y: b.y), c)
  endClip(clip)
