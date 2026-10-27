## Ruler -- the scale over (or beside) anything on a view: numbers, seconds,
## timecode, samples, or bars and beats.
##
## ```nim
## let time = newLink(wholeView(0.0, song.seconds))
## ui:
##   Ruler(view = time, ticks = timecodeTicks(25),
##         onSeek = proc(at: float) = playhead.value = at)
##   Waveform(source = song, view = time)
## ```
##
## The marks come from `axisTicks` (axis_ticks.nim): a labelled one about
## every `labelSpacing` pixels, on a step that is round for the format, and
## small ones between. The ruler takes the view's gestures (the wheel pans,
## Ctrl+wheel zooms, view_range.nim). A press or a drag on it is a seek --
## `onSeek` with the data under the pointer, which is how a playhead is moved;
## with no `onSeek` a drag pans instead.

import rui_core
import rui_drawing
import std/options
import raylib
import ../view_range
import ../pointers
import axis_ticks
export axis_ticks

definePrimitive(Ruler):
  props:
    view: Link[AxisView] = nil
    ticks: TickFormat = plainTicks()
    labelSpacing: float32 = 80.0     ## about this many pixels between labels
    intent: ThemeIntent = Default

  state:
    input: ViewInput
    seeking: bool

  actions:
    onSeek(at: float)

  init:
    widget.multiPointer = true

  events:
    on_mouse_wheel:
      if widget.view == nil: return false
      return viewWheel(widget.view, event, widget.bounds.x, widget.bounds.width)

    on_mouse_down:
      if widget.view == nil: return false
      if widget.onSeek != nil and event.pointerId == 0:
        widget.seeking = true
        capturePointer(widget)
        widget.onSeek(widget.view.resolved(widget.bounds.width).toData(
          event.mousePos.x, widget.bounds.x))
        return true
      return widget.input.viewDown(widget, event)

    on_mouse_move:
      if widget.view == nil: return false
      if widget.seeking:
        let v = widget.view.resolved(widget.bounds.width)
        widget.onSeek(clamp(v.toData(event.mousePos.x, widget.bounds.x), v.lo, v.hi))
        return true
      return widget.input.viewMove(widget.view, event, widget.bounds.x, widget.bounds.width)

    on_mouse_up:
      if widget.seeking:
        widget.seeking = false
        return true
      return widget.input.viewUp(event)

  layout:
    widget.followView(widget.view)
    if widget.bounds.width <= 0: widget.bounds.width = 400
    if widget.bounds.height <= 0: widget.bounds.height = 26

  render:
    let props = currentTheme.getThemeProps(widget.intent, Normal)   # a view: no hover tint
    let ink = props.foregroundColor.get(BLACK)
    drawRect(widget.bounds, props.backgroundColor.get(WHITE))
    let b = widget.bounds
    let bottom = b.y + b.height
    drawLine(b.x, bottom - 0.5, b.x + b.width, bottom - 0.5, ink.withAlpha(0.5))
    if widget.view == nil: return
    var style = props.captionStyle(ink)
    style.fontSize = max(10'f32, style.fontSize - 3)
    let clip = beginClip(b)
    for t in axisTicks(widget.ticks, widget.view.value, b.x, b.width, widget.labelSpacing):
      let h = if t.major: b.height * 0.45 else: b.height * 0.2
      drawLine(t.x, bottom - h, t.x, bottom, ink.withAlpha(if t.major: 0.7 else: 0.4))
      if t.major:
        drawStyledText(t.label, t.x + 3, b.y + 2, style)
    endClip(clip)
