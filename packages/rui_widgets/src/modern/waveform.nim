## Waveform -- samples drawn as a wave, a lane per channel, on a shared view.
##
## ```nim
## let song = openWav("take3.wav")
## let time = newLink(wholeView(0.0, song.seconds))
## ui:
##   Ruler(view = time, ticks = secondTicks())
##   Waveform(source = song, view = time)
## ```
##
## All of a long recording draws at once from summaries built in the
## background (samples.nim); zoomed in, a line through the samples, then a dot
## on each (wave_draw.nim). It takes the view's gestures (view_range.nim): the
## wheel pans, Ctrl+wheel and a pinch zoom, a drag pans, and when focused the
## arrows, Home/End and +/-. Give it `marks` (axis_marks.nim) for a playhead,
## a selection and markers: a click seeks and a drag selects then.

import rui_core
import rui_drawing
import std/options
import raylib
import ../view_range
import ../pointers
import ../sources/samples
import wave_draw
import axis_marks

definePrimitive(Waveform):
  props:
    source: SampleSource = nil
    view: Link[AxisView] = nil      ## seconds; made over the whole source if not given
    channelGap: float32 = 4.0
    marks: Marks = nil              ## a playhead, a selection, markers over it (axis_marks)
    intent: ThemeIntent = Default

  state:
    zoom: ZoomPan

  actions:
    onSeek(at: float)
    onSelect(span: AxisSpan)
    onMarkerMoved(index: int, at: float)

  init:
    widget.focusable = true
    widget.multiPointer = true

  events:
    on_event:
      # The marks first (a click seeks, a drag selects), then the view.
      let done = widget.marks.handle(widget, widget.view, event, widget.bounds)
      case done.did
      of mdSought:
        if widget.onSeek != nil: widget.onSeek(done.at)
      of mdSelected:
        if widget.onSelect != nil: widget.onSelect(widget.marks.selection.value)
      of mdMoved:
        if widget.onMarkerMoved != nil: widget.onMarkerMoved(done.index, done.at)
      of mdBusy: discard
      of mdNothing:
        return widget.zoom.handle(widget, widget.view, event, widget.bounds)
      return true

  layout:
    if widget.bounds.width <= 0: widget.bounds.width = 400
    if widget.bounds.height <= 0: widget.bounds.height = 120
    if widget.source != nil:
      if widget.view == nil:
        widget.view = newLink(wholeView(0.0, widget.source.seconds))
      widget.source.drawnBy(widget)
    widget.followView(widget.view)
    widget.showMarks(widget.marks)

  render:
    let props = currentTheme.getThemeProps(widget.intent, Normal)   # a view: no hover tint
    let ink = props.foregroundColor.get(BLACK)
    let b = widget.bounds
    drawRect(b, props.backgroundColor.get(WHITE))
    if widget.source == nil or widget.view == nil: return
    let s = widget.source
    let v = widget.view.resolved(b.width)
    let n = max(1, s.channels)
    let laneH = (b.height - widget.channelGap * float32(n - 1)) / float32(n)
    let color = props.activeColor.get(ink)
    let clip = beginClip(b)
    for ch in 0 ..< n:
      let lane = Rect(x: b.x, y: b.y + float32(ch) * (laneH + widget.channelGap),
                      width: b.width, height: laneH)
      let mid = lane.y + lane.height / 2
      drawLine(lane.x, mid, lane.x + lane.width, mid, ink.withAlpha(0.2))
      drawWave(s, ch, v, lane, -1.0, 1.0, color, max(1'f32, props.strokeWidth))
    endClip(clip)
    widget.marks.draw(v, b, widget.intent)
    if widget.focused: drawThemedFocusRing(b, props)
