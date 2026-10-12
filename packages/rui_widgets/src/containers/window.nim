## SPIKE -- Window: a movable, closable panel on the overlay layer.
##
## One App, one Store, one tree: a window is a floating child of a host widget
## (the root), drawn and hit-tested on the overlay layer, so its content shares
## state, theme and the event loop with everything else. The overlay layer's
## order *is* the z-order; raising a window is hide + show.
##
## Throwaway: written to find out what breaks (leaks, focus, hit-testing).

import rui_core
import rui_drawing
import std/options

const
  TitleH = 26.0'f32
  Pad = 8.0'f32

proc contentRect(w: Rect): Rect =
  Rect(x: w.x + Pad, y: w.y + TitleH + Pad, width: max(0.0'f32, w.width - Pad * 2),
       height: max(0.0'f32, w.height - TitleH - Pad * 2))

proc closeBox(w: Rect): Rect =
  Rect(x: w.x + w.width - TitleH, y: w.y, width: TitleH, height: TitleH)

proc closeWindow*(w: Widget)       # defined below; the close button needs it

var activeWindow*: Widget     # the window drawn as active (topmost, last raised)

proc raiseWindow*(w: Widget) =
  ## Bring a window above every other overlay.
  if w == nil: return
  hideOverlay(w)
  showOverlay(w, interactive = true)
  activeWindow = w

proc windowOf*(widget: Widget): Widget =
  ## The floating window `widget` is inside (or is), nil when none.
  var w = widget
  while w != nil:
    if w.floating and w.getTypeName == "Window": return w
    w = w.parent
  nil

definePrimitive(Window):
  props:
    title: string = "Window"
    x: float32 = 80.0
    y: float32 = 80.0
    width: float32 = 320.0
    height: float32 = 220.0

  state:
    dragging: bool
    grabX: float32
    grabY: float32

  actions:
    onClose()

  init:
    widget.floating = true

  events:
    on_mouse_down:
      let p = event.mousePos
      if closeBox(widget.bounds).contains(p.x, p.y):
        closeWindow(widget)
        return true
      if p.y < widget.bounds.y + TitleH:
        widget.dragging = true
        widget.grabX = p.x - widget.bounds.x
        widget.grabY = p.y - widget.bounds.y
      return true                        # opaque: nothing falls through to the page

    on_mouse_move:
      if not widget.dragging: return false
      let p = event.mousePos
      widget.x = p.x - widget.grabX
      widget.y = p.y - widget.grabY
      if renderView.isSome:
        let v = renderView.get
        widget.x = clamp(widget.x, v.x - widget.width + 60, v.x + v.width - 60)
        widget.y = clamp(widget.y, v.y, v.y + v.height - TitleH)
      widget.layoutDirty = true
      widget.isDirty = true
      return true

    on_mouse_up:
      if not widget.dragging: return false
      widget.dragging = false
      return true

  layout:
    widget.bounds = Rect(x: widget.x, y: widget.y, width: widget.width,
                         height: widget.height)
    if widget.children.len > 0:
      widget.children[0].arrange(contentRect(widget.bounds))

  render:
    let props = currentTheme.getThemeProps(Default, Normal)
    let active = activeWindow == widget
    drawShadow(widget.bounds, Shadow(offsetX: 3.0, offsetY: 3.0, blur: 0.0, spread: 0.0,
                                     color: Color(r: 0, g: 0, b: 0, a: 60)))
    drawThemedBackground(widget.bounds, props)
    drawThemedBorder(widget.bounds, props)
    let bar = Rect(x: widget.bounds.x, y: widget.bounds.y, width: widget.bounds.width,
                   height: TitleH)
    let titleProps = currentTheme.getThemeProps(Default, if active: Selected else: Normal)
    drawThemedBackground(bar, titleProps, hovered = false)
    drawThemedPaddedText(widget.title, bar, titleProps, selected = active)
    let c = closeBox(widget.bounds)
    let mid = Point(x: c.x + c.width / 2, y: c.y + c.height / 2)
    drawLine(mid.x - 5, mid.y - 5, mid.x + 5, mid.y + 5,
             titleProps.foregroundColor.get(BLACK), 2)
    drawLine(mid.x - 5, mid.y + 5, mid.x + 5, mid.y - 5,
             titleProps.foregroundColor.get(BLACK), 2)

proc openWindow*(host: Widget, w: Window) =
  ## Add `w` under `host` and show it on top.
  host.addChild(w)
  raiseWindow(w)

proc closeWindow*(w: Widget) =
  ## Remove a window for good: off the overlay layer, out of the tree, and
  ## disposed so nothing keeps it alive.
  let window = Window(w)
  hideOverlay(window)
  if activeWindow == window: activeWindow = nil
  let host = window.parent
  if host != nil: host.removeChild(window)
  disposeTree(window)
  if window.onClose != nil: window.onClose()

onPointerPress = proc(target: Widget) =
  ## A press anywhere inside a window raises it first -- even on a child that
  ## then consumes the click, which a handler on the window itself never sees.
  let w = windowOf(target)
  if w != nil and w != activeWindow: raiseWindow(w)
