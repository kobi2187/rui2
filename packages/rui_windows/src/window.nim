## Window: a movable, resizable, closable panel on the overlay layer.
##
## One App, one Store, one widget tree: a window is a floating child of a host
## widget, drawn and hit-tested on the overlay layer, so its content shares
## state, theme and the event loop with everything else -- "several windows"
## is several roots of the same app, not several apps.
##
## ```nim
## import rui, rui_windows
##
## let w = newWindow(title = "Inspector", x = 40, y = 60, width = 300, height = 240)
## w.addChild(Column(...))
## host.openWindow(w)           # shown on top and active, focus inside it
## w.closeWindow()              # off screen, out of the tree, fully released
## ```
##
## Dragging the title bar moves it, the border (when `resizable`) resizes it,
## the title bar's buttons maximise and close it, a press anywhere inside
## raises it, and while it is active Tab stays inside it. Windows are kept
## reachable: a drag cannot take the title bar off screen.

import rui_core
import rui_drawing
import std/options
import raylib
import window_geometry, window_manager

# Used by the event handlers below, defined after the type they work on.
proc cursorFor(edges: Edges): CursorShape
proc closeWindow*(w: Widget)
proc toggleMaximized*(wid: Widget)
proc moveBy(wid: Widget, dx, dy: float32)
proc resizeBy(wid: Widget, dx, dy: float32)

definePrimitive(Window):
  props:
    title: string = "Window"
    x: float32 = 80.0
    y: float32 = 80.0
    width: float32 = 320.0
    height: float32 = 220.0
    minWidth: float32 = 160.0
    minHeight: float32 = 100.0
    resizable: bool = true
    closable: bool = true
    maximizable: bool = true
    closeOnEscape: bool = false

  state:
    maximized: bool
    restoreRect: Rect       # where it was before maximising
    dragging: bool
    resizeEdges: Edges
    grabStart: Point        # pointer at the start of a drag or resize
    rectStart: Rect         # window at the start of a drag or resize
    closed: bool

  actions:
    onClose()
    onMove(x: float32, y: float32)
    onResize(width: float32, height: float32)

  init:
    widget.floating = true
    widget.takesText = false

  events:
    on_mouse_down:
      let p = event.mousePos
      let r = widget.bounds
      if widget.closable and titleButton(r, 0).contains(p.x, p.y):
        closeWindow(widget)
        return true
      if widget.maximizable and titleButton(r, if widget.closable: 1 else: 0).contains(p.x, p.y):
        toggleMaximized(widget)
        return true
      let edges = if widget.resizable and not widget.maximized: edgesAt(r, p) else: {}
      if edges != {}:
        widget.resizeEdges = edges
        widget.grabStart = p
        widget.rectStart = r
        capturePointer(widget)
      elif p.y < r.y + titleHeight and not widget.maximized:
        widget.dragging = true
        widget.grabStart = p
        widget.rectStart = r
        capturePointer(widget)
      return true                        # opaque: nothing falls through to the page

    on_mouse_move:
      let p = event.mousePos
      if widget.dragging:
        moveBy(widget, p.x - widget.grabStart.x, p.y - widget.grabStart.y)
        return true
      if widget.resizeEdges != {}:
        resizeBy(widget, p.x - widget.grabStart.x, p.y - widget.grabStart.y)
        return true
      widget.cursorShape = cursorFor(
        if widget.resizable and not widget.maximized: edgesAt(widget.bounds, p) else: {})
      return false

    on_mouse_up:
      if not widget.dragging and widget.resizeEdges == {}: return false
      widget.dragging = false
      widget.resizeEdges = {}
      return true

    on_key_down:
      if widget.closeOnEscape and event.key == KeyboardKey.Escape:
        closeWindow(widget)
        return true
      return false

  layout:
    var r = Rect(x: widget.x, y: widget.y, width: widget.width, height: widget.height)
    if renderView.isSome:
      r = if widget.maximized: renderView.get else: r.clampedTo(renderView.get)
    widget.bounds = r
    if widget.children.len > 0:
      widget.children[0].arrange(contentRect(r))

  render:
    let props = currentTheme.getThemeProps(Default, Normal)
    let active = activeWindow() == widget
    drawShadow(widget.bounds, Shadow(offsetX: 3.0, offsetY: 3.0, blur: 0.0, spread: 0.0,
                                     color: Color(r: 0, g: 0, b: 0, a: if active: 80 else: 40)))
    drawThemedBackground(widget.bounds, props)
    drawThemedBorder(widget.bounds, props)
    let bar = Rect(x: widget.bounds.x, y: widget.bounds.y,
                   width: widget.bounds.width, height: titleHeight)
    let titleProps = currentTheme.getThemeProps(Default, if active: Selected else: Normal)
    drawThemedBackground(bar, titleProps, hovered = false)
    drawThemedPaddedText(widget.title, bar, props)   # body ink: legible on every theme's active bar
    let ink = props.foregroundColor.get(BLACK)
    if widget.closable:
      let c = titleButton(widget.bounds, 0)
      let m = Point(x: c.x + c.width / 2, y: c.y + c.height / 2)
      drawLine(m.x - 5, m.y - 5, m.x + 5, m.y + 5, ink, 2)
      drawLine(m.x - 5, m.y + 5, m.x + 5, m.y - 5, ink, 2)
    if widget.maximizable:
      let b = titleButton(widget.bounds, if widget.closable: 1 else: 0)
      drawRectangleLines(int32(b.x + 8), int32(b.y + 8), int32(b.width - 16),
                         int32(b.height - 16), ink)

proc cursorFor(edges: Edges): CursorShape =
  if edges == {}: csDefault
  elif edges <= {edgeLeft, edgeRight}: csResizeH
  elif edges <= {edgeTop, edgeBottom}: csResizeV
  else: csMove

proc changed(w: Widget) =
  w.layoutDirty = true
  w.isDirty = true
  w.markDirtyToRoot()

proc moveBy(wid: Widget, dx, dy: float32) =
  let w = Window(wid)
  w.x = w.rectStart.x + dx
  w.y = w.rectStart.y + dy
  if renderView.isSome:
    let r = Rect(x: w.x, y: w.y, width: w.width, height: w.height).clampedTo(renderView.get)
    w.x = r.x
    w.y = r.y
  w.changed()
  if w.onMove != nil: w.onMove(w.x, w.y)

proc resizeBy(wid: Widget, dx, dy: float32) =
  let w = Window(wid)
  var r = resized(w.rectStart, w.resizeEdges, dx, dy, w.minWidth, w.minHeight)
  if renderView.isSome: r = r.clampedTo(renderView.get)
  w.x = r.x; w.y = r.y; w.width = r.width; w.height = r.height
  w.changed()
  if w.onResize != nil: w.onResize(w.width, w.height)

proc toggleMaximized*(wid: Widget) =
  let w = Window(wid)
  ## Fill the window area, or go back to where it was.
  if w.maximized:
    w.maximized = false
    w.x = w.restoreRect.x; w.y = w.restoreRect.y
    w.width = w.restoreRect.width; w.height = w.restoreRect.height
  else:
    w.restoreRect = Rect(x: w.x, y: w.y, width: w.width, height: w.height)
    w.maximized = true
  w.changed()

proc firstFocusable(w: Widget): Widget =
  if not w.visible or not w.enabled: return nil
  if w.focusable: return w
  for c in w.children:
    let f = firstFocusable(c)
    if f != nil: return f
  nil

proc openWindow*(host: Widget, w: Window) =
  ## Add `w` under `host`, show it on top and active, and put the keyboard
  ## focus on the first thing inside it that takes it.
  host.addChild(w)
  addWindow(w)
  let first = firstFocusable(w)
  if first != nil: wantFocus(first)

proc closeWindow*(w: Widget) =
  ## Close a window for good: off the overlay layer, out of the tree and
  ## disposed, so no Link, focus chain or texture keeps it alive. Closing twice
  ## is harmless. Fires `onClose` once.
  let window = Window(w)
  if window.closed: return
  window.closed = true
  removeWindow(window)
  let host = window.parent
  if host != nil: host.removeChild(window)
  disposeTree(window)
  if window.onClose != nil: window.onClose()
