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

proc flex*[T: Widget](widget: T, weight = 1.0'f32): T =
  ## Take `weight` shares of the leftover main-axis space in a VStack or
  ## HStack (CSS flex-grow). `flex(0)` turns it off.
  widget.flexGrow = weight
  widget.layoutDirty = true
  widget
