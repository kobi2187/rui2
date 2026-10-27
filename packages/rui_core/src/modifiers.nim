## Layout modifiers: how a widget states the size and share it wants.
##
## Position and size belong to the layout primitives. A widget does not write
## its own `bounds` -- the container it sits in does -- but it can *ask*: for a
## fixed size, for limits, for a share of spare room. These set those requests
## and return the widget, so they chain, and they work inside `ui:`:
##
## ```nim
## let canvas = newCanvas().frame(width = 580, height = 260)
##
## ui:
##   VStack(spacing = 8.0):
##     Canvas().frame(height = 260)       # full width, fixed height
##     TextArea().flex()                  # takes the rest
##     Button(text = "OK").frame(minWidth = 96)
## ```
##
## A requested dimension overrides whatever the parent assigns (an explicit
## width beats stretch, as in CSS); min/max clamp the final size either way.
## 0 leaves a value as it was, so `frame(height = 40)` keeps any width request.

import types
from raylib import KeyboardKey

proc frame*[T: Widget](widget: T, width = 0.0'f32, height = 0.0'f32,
                       minWidth = 0.0'f32, minHeight = 0.0'f32,
                       maxWidth = 0.0'f32, maxHeight = 0.0'f32): T =
  ## Request a size and/or limits. Any argument left at 0 is unchanged.
  if width > 0: widget.sizeRequest.width = width
  if height > 0: widget.sizeRequest.height = height
  if minWidth > 0: widget.sizeMin.width = minWidth
  if minHeight > 0: widget.sizeMin.height = minHeight
  if maxWidth > 0: widget.sizeMax.width = maxWidth
  if maxHeight > 0: widget.sizeMax.height = maxHeight
  widget.layoutDirty = true
  widget

proc size*[T: Widget](widget: T, width, height: float32): T =
  ## yui's `size: 120x40`: `.size(120, 40)` is `.frame(width = 120, height = 40)`.
  widget.frame(width = width, height = height)

proc named*[T: Widget](widget: T, id: string): T =
  ## Give the widget the id scripts, tests and the inspector find it by:
  ## `TextInput(...).named("email")`.
  widget.stringId = id
  widget

proc unframe*[T: Widget](widget: T): T =
  ## Drop every size request and limit: size to content again. A dimension
  ## that came from a request is cleared too, or the size it left behind
  ## would read as one a parent assigned and never be re-measured.
  if widget.sizeRequest.width > 0: widget.bounds.width = 0
  if widget.sizeRequest.height > 0: widget.bounds.height = 0
  widget.sizeRequest = Size()
  widget.sizeMin = Size()
  widget.sizeMax = Size()
  widget.layoutDirty = true
  widget

proc animateLayout*[T: Widget](widget: T, on = true): T =
  ## Ease the children to their new places when this container reflows (a
  ## panel growing, its siblings giving way) instead of snapping them. Snaps
  ## anyway when the user's preferences say `motion: reduced`.
  widget.animateLayout = on
  widget.layoutDirty = true
  widget

proc flex*[T: Widget](widget: T, weight = 1.0'f32): T =
  ## Take `weight` shares of the leftover main-axis space in a VStack or
  ## HStack (CSS flex-grow). `flex(0)` turns it off.
  widget.flexGrow = weight
  widget.layoutDirty = true
  widget

proc shortcut*[T: Widget](widget: T, chord: string): T =
  ## A key chord that activates this widget, like a click: `Ctrl+S`, `F5`,
  ## `Alt+N`. The help overlay (F1 or ?) shows it next to the widget. A chord
  ## that is really typing (a bare letter) is ignored while a text field has
  ## focus. Chords are checked when written, so a typo fails here, not silently.
  widget.hotkey = chord
  widget

proc hint*[T: Widget](widget: T, text: string): T =
  ## Text the help overlay (F1 or ?) shows beside this widget, wherever it is on
  ## screen: a key, or any note. It is only a label -- to make a key *do*
  ## something, use `.shortcut(...)`, which also supplies the hint.
  ##
  ##   Button(text = "Save").hint("Ctrl+S")
  ##   Slider(...).hint("← → adjust")
  widget.hint = text
  widget

proc focusable*[T: Widget](widget: T, on = true): T =
  ## Let it take the keyboard focus (a Tab stop), so the keys reach it --
  ## for a container made interactive with `onKey`.
  widget.focusable = on
  widget

proc onEvent*[T: Widget](widget: T, handler: proc(event: GuiEvent): bool): T {.discardable.} =
  ## Handle input on any widget, without a widget type of its own: `handler`
  ## gets each event the widget's own handlers did not take (pointer events
  ## over it, keys while it has focus or bubbling up to it) and returns true
  ## for the ones it used. A second call adds to the first.
  let before = widget.eventHook
  if before == nil:
    widget.eventHook = handler
  else:
    widget.eventHook = proc(event: GuiEvent): bool = before(event) or handler(event)
  widget

proc onKey*[T: Widget](widget: T, handler: proc(key: KeyboardKey): bool): T {.discardable.} =
  ## A key press on it (while it has focus, or one bubbling up to it):
  ## `handler` returns true for the keys it used. Pair with `.focusable()` on
  ## a container. (`from raylib import KeyboardKey` names the keys; rui does
  ## not re-export them, as their Menu/Up/Down would clash with its own.)
  widget.onEvent(proc(event: GuiEvent): bool =
    event.kind == evKeyDown and handler(event.key))

proc subpixel*[T: Widget](widget: T, on = true): T =
  ## Composite it at its exact position, smoothly filtered, rather than
  ## snapped to whole pixels: for something that glides by fractions of a
  ## pixel (a moving rule, a slow marker). Text in it would soften, so keep it
  ## to what moves.
  widget.subpixel = on
  widget.isDirty = true
  widget
