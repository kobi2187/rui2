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
## arrows, Home/End and +/-. Put AxisMarks over it (in a Stack) for a playhead
## and a selection; they take the drag then.

import rui_core
import rui_drawing
import std/options
import raylib
import ../view_range
import ../pointers
import ../sources/samples
import wave_draw

definePrimitive(Waveform):
  props:
    source: SampleSource = nil
    view: Link[AxisView] = nil      ## seconds; made over the whole source if not given
    channelGap: float32 = 4.0
    intent: ThemeIntent = Default

  state:
    input: ViewInput

  init:
    widget.focusable = true
    widget.multiPointer = true

  events:
    on_mouse_wheel:
      if widget.view == nil: return false
      return viewWheel(widget.view, event, widget.bounds.x, widget.bounds.width)
    on_mouse_down:
      if widget.view == nil: return false
      return widget.input.viewDown(widget, event)
    on_mouse_move:
      if widget.view == nil: return false
      return widget.input.viewMove(widget.view, event, widget.bounds.x, widget.bounds.width)
    on_mouse_up:
      return widget.input.viewUp(event)
    on_key_down:
      if widget.view == nil or not widget.focused: return false
      return viewKey(widget.view, event, widget.bounds.x, widget.bounds.width)

  layout:
    if widget.bounds.width <= 0: widget.bounds.width = 400
    if widget.bounds.height <= 0: widget.bounds.height = 120
    if widget.source != nil:
      if widget.view == nil:
        widget.view = newLink(wholeView(0.0, widget.source.seconds))
      widget.source.drawnBy(widget)
    widget.followView(widget.view)

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
    if widget.focused: drawThemedFocusRing(b, props)
