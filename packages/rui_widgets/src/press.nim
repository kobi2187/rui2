## One "press" behaviour for everything button-like: Button, ToolButton,
## IconButton, clickable Image, Checkbox, Switch, Hyperlink, an Expander's header.
##
## A press is: the button goes down on the widget (it becomes *armed* and takes
## the pointer, so the release arrives wherever the pointer is); the pointer
## leaving disarms it and coming back re-arms it (the hover tracker does that,
## see hover_tracker.nim); the release activates only if still armed and over the
## widget. Space/Enter on a focused one is a click too (`makePressable` marks it
## on_key_down: `pressKey`).
##
## A widget opts in with `widget.makePressable()` in `init:` and writes its two
## handlers as
##
## ```nim
## on_mouse_down: return widget.pressDown(event, not widget.disabled)
## on_mouse_up:   return widget.pressUp(event): widget.fire()
## on_key_down:   return widget.pressKey(event, not widget.disabled)
## ```
##
## so what differs between widgets -- what a click *does* -- is the only code a
## widget keeps; the state, the capture, the release-outside rule and the visuals
## are shared. `widget.isPressed` (types.nim) is the armed flag.

import rui_core
import raylib

proc makePressable*(widget: Widget, relayout = false, keyboard = true) =
  ## Call from `init:`. `relayout`: the widget works its colours out in `layout`
  ## (Button does), so a press or hover change must ask for one. `keyboard`: it can
  ## take focus (not for a mere clickable image).
  widget.focusable = keyboard
  widget.stealableDrag = true       # on a touch screen a drag through a button scrolls, it does not click
  widget.relayoutOnState = relayout

proc stateChanged*(widget: Widget) =
  ## The press or hover state changed: repaint (and re-layout if the look is made there).
  if widget.relayoutOnState: widget.layoutDirty = true
  widget.markDirtyToRoot()

proc pressDown*(widget: Widget, event: GuiEvent, enabled: bool,
                region = Rect()): bool =
  ## The button went down. `region` (empty: the whole widget) is where a press
  ## counts -- an Expander's header, say. True when it was taken.
  if not enabled: return false
  if region.width > 0 and not region.contains(event.mousePos.x, event.mousePos.y):
    return false
  widget.pressed = true
  capturePointer(widget)
  widget.stateChanged()
  true

template pressUp*(widget: Widget, event: GuiEvent, body: untyped): bool =
  ## The button came up. `body` runs when that is a click: armed, and released over
  ## the widget. Evaluates to whether the release was the widget's.
  block:
    let w = widget
    if not w.pressed:
      false
    else:
      w.pressed = false
      releasePointer()
      w.stateChanged()
      if w.bounds.contains(event.mousePos.x, event.mousePos.y):
        body
      true

proc pressKey*(widget: Widget, event: GuiEvent, enabled: bool,
               at = Point(x: -1.0'f32, y: -1.0'f32)): bool =
  ## Space or Enter on the focused widget is a click: the widget is sent the press
  ## and release of one (at `at`, default its middle) so its own handlers do the
  ## work and nothing is written twice.
  if not (enabled and widget.focused and event.kind == evKeyDown and
          event.key in {KeyboardKey.Space, KeyboardKey.Enter}):
    return false
  let p = if at.x >= 0: at
          else: Point(x: widget.bounds.x + widget.bounds.width / 2,
                      y: widget.bounds.y + widget.bounds.height / 2)
  discard widget.handleInput(GuiEvent(kind: evMouseDown, mousePos: p, timestamp: event.timestamp))
  discard widget.handleInput(GuiEvent(kind: evMouseUp, mousePos: p, timestamp: event.timestamp))
  widget.markDirtyToRoot()
  true
