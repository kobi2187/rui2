## Switch -- an on/off toggle, with the thumb sliding across.
##
## Like a Checkbox for a setting that takes effect at once ("Dark mode",
## "Airplane mode"). Click it, or press Space or Enter while it has focus.
## `initialOn` seeds the state `on`; `onToggle(on)` reports changes.
##
## ```nim
## Switch(text = "Notifications", initialOn = true, onToggle = proc(on: bool) = ...)
## ```
##
## The thumb eases across over the theme's `transitionMs` (see animation.nim);
## reduced motion makes it jump.

import rui_core
import rui_drawing
import std/options
import raylib

proc switchTrack*(height: float32): tuple[width, height: float32] =
  ## A switch's track: pill-shaped, a little under twice as wide as tall.
  (height * 1.8'f32, height)

proc thumbX*(track: Rect, t: float32): float32 =
  ## Left edge of the thumb for progress `t` (0 off, 1 on): it travels the
  ## track's width less its own diameter, inside a 2px margin.
  let d = track.height - 4
  track.x + 2 + clamp(t, 0.0'f32, 1.0'f32) * (track.width - 4 - d)

definePrimitive(Switch):
  props:
    text: string = ""
    initialOn: bool = false
    disabled: bool = false
    intent: ThemeIntent = Default

  state:
    on: bool
    thumb: Animated[float32]       # 0..1, the thumb's progress
    thumbT: float32                # this frame's value, read by render

  actions:
    onToggle(on: bool)

  init:
    widget.focusable = true

  events:
    on_mouse_down:
      if widget.disabled: return false
      widget.on = not widget.on
      if widget.onToggle != nil: widget.onToggle(widget.on)
      return true

    on_key_down:
      if widget.disabled or not widget.focused: return false
      if event.key == KeyboardKey.Space or event.key == KeyboardKey.Enter:
        widget.on = not widget.on
        if widget.onToggle != nil: widget.onToggle(widget.on)
        return true
      return false

  layout:
    let props = widget.themeProps(widget.intent, crPointer, disabled = widget.disabled)
    let h = max(currentTheme.indicatorSize * 1.2'f32, 18.0'f32)
    let track = switchTrack(h)
    let m = measureText(widget.text, props.captionStyle(BLACK))
    if widget.bounds.height <= 0:
      widget.bounds.height = max(h, m.height)
    if widget.bounds.width <= 0:
      widget.bounds.width = track.width + (if widget.text.len > 0: props.spacing.get(8.0'f32) + m.width else: 0.0'f32)
    # Where the thumb is this frame; asks for more frames only while it moves.
    widget.thumbT = widget.thumb.follow(widget, (if widget.on: 1.0'f32 else: 0.0'f32),
                                        currentTheme.transitionSeconds)

  render:
    let props = widget.themeProps(widget.intent, crPointer, disabled = widget.disabled)
    let accent = props.activeColor.get(Color(r: 80, g: 120, b: 255, a: 255))
    let off = props.borderColor.get(Color(r: 190, g: 190, b: 190, a: 255))
    let h = max(currentTheme.indicatorSize * 1.2'f32, 18.0'f32)
    let dims = switchTrack(h)
    let track = Rect(x: widget.bounds.x,
                     y: widget.bounds.y + (widget.bounds.height - dims.height) / 2,
                     width: dims.width, height: dims.height)
    let color = lerp(off, accent, widget.thumbT)
    drawBox(track, track.height / 2, color, props.borderColor.get(color),
            if widget.on: 0.0'f32 else: props.strokeWidth)
    let d = track.height - 4
    drawBox(Rect(x: thumbX(track, widget.thumbT), y: track.y + 2, width: d, height: d),
            d / 2, props.backgroundColor.get(WHITE), props.borderColor.get(color), 0)
    if widget.focused:
      drawBox(Rect(x: track.x - 3, y: track.y - 3, width: track.width + 6, height: track.height + 6),
              track.height / 2 + 3, Color(r: 0, g: 0, b: 0, a: 0),
              props.focusColor.get(accent), props.focusRingWidth.get(2.0'f32))
    if widget.text.len > 0:
      let style = props.captionStyle(props.foregroundColor.get(BLACK))
      drawStyledText(widget.text, track.x + track.width + props.spacing.get(8.0'f32),
                     widget.bounds.y + (widget.bounds.height - style.fontSize) / 2, style)
