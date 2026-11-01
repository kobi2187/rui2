## BottomSheet -- a panel that slides up from the bottom over the screen:
## options for the item you tapped, a player's queue, a form.
##
## ```nim
## var sheet: BottomSheet
## ui:
##   Stack(fit = StackFit.expand):
##     thePage()
##     sheet = BottomSheet(snaps = @[0.4, 0.9]):
##       Column: (the sheet's content)
## sheet.open()          # from a button
## ```
##
## Its child is its content. Open, it rises to the first of `snaps` (shares of
## the screen's height) over a scrim that dims the page. Dragging its handle
## moves it; let go, it settles at the nearest snap -- or, dragged well below
## the lowest, closes. A tap on the scrim, or Escape, closes it too. It slides
## (animation.nim: at once with motion reduced or none), and while it is open
## it is above the page for the pointer, as a dialog is (modal.nim's layer).

import rui_core
import rui_drawing
import ../dialogs/modal
import std/[options, math]
import raylib

const Handle = 28'f32               ## the strip at the top that drags it

proc nearestSnap*(height, screen: float32, snaps: seq[float32], dismissible: bool): float32 =
  ## Where a sheet let go at `height` settles: the nearest snap (in pixels), or
  ## 0 (closed) when dismissible and below half the lowest snap.
  if snaps.len == 0: return height
  let lowest = snaps[0] * screen
  if dismissible and height < lowest * 0.5: return 0
  result = lowest
  for s in snaps:
    if abs(s * screen - height) < abs(result - height): result = s * screen

proc sheetRect(widget: Widget, h: float32): Rect
proc settle(widget: Widget, target: float32)

defineWidget(BottomSheet):
  props:
    snaps: seq[float32] = @[0.5'f32, 0.9]   ## shares of the screen, lowest first
    dismissible: bool = true
    scrim: bool = true
    intent: ThemeIntent = Default

  state:
    isOpen: bool
    target: float32                 ## the height it is heading for (px)
    shown: Animated[float32]        ## the height it is at
    height: float32                 ## this frame's height
    dragging: bool
    grabY: float32
    grabHeight: float32

  actions:
    onClose()

  init:
    widget.visible = false
    widget.focusable = true
    widget.hitLayer = ModalLayer

  events:
    on_mouse_down:
      let r = widget.sheetRect(widget.height)
      if event.mousePos.y < r.y:                      # the scrim
        if widget.dismissible: widget.settle(0)
        return true
      if event.mousePos.y <= r.y + Handle:
        widget.dragging = true
        widget.grabY = event.mousePos.y
        widget.grabHeight = widget.height
        capturePointer(widget)
        return true
      return true                                     # the sheet's own background

    on_mouse_move:
      if not widget.dragging: return false
      let screen = widget.bounds.height
      let h = clamp(widget.grabHeight + (widget.grabY - event.mousePos.y), 0, screen)
      widget.target = h
      widget.shown.jump(h)                            # under the finger: no easing
      widget.layoutDirty = true
      widget.markDirtyToRoot()
      return true

    on_mouse_up:
      if not widget.dragging: return false
      widget.dragging = false
      widget.settle(nearestSnap(widget.height, widget.bounds.height, widget.snaps,
                                widget.dismissible))
      return true

    on_key_down:
      if event.key == KeyboardKey.Escape and widget.isOpen:   # bubbles from inside
        widget.settle(0)
        return true
      return false

  layout:
    if widget.parent != nil and widget.bounds.width <= 0:
      widget.bounds = widget.parent.bounds
    widget.height = widget.shown.follow(widget, widget.target, 0.22)
    if not widget.isOpen and widget.height <= 0.5:
      widget.visible = false
      if widget.parent != nil: widget.parent.layoutDirty = true   # out of the hit-test tree
      return
    let r = widget.sheetRect(widget.height)
    if widget.children.len > 0:
      widget.children[0].visible = true
      widget.children[0].arrange(Rect(x: r.x + 16, y: r.y + Handle, width: r.width - 32,
                                      height: max(0'f32, r.height - Handle - 8)))

  render:
    let props = currentTheme.getThemeProps(widget.intent, Normal)
    let ink = props.foregroundColor.get(BLACK)
    let b = widget.bounds
    let screen = max(1'f32, b.height)
    if widget.scrim:
      let low = if widget.snaps.len > 0: widget.snaps[0] * screen else: screen
      let k = clamp(widget.height / max(1'f32, low), 0, 1)       # dims as it rises
      drawRect(b, BLACK.withAlpha(0.35 * k))
    let r = widget.sheetRect(widget.height)
    let radius = 16'f32
    discard drawSdfShadow(r, radius, 0, -2, 10, 0, BLACK.withAlpha(0.2))
    let bg = props.backgroundColor.get(WHITE)
    discard drawSdfBox(Rect(x: r.x, y: r.y, width: r.width, height: r.height + radius),
                       radius, 0, bg, bg)
    let grip = Rect(x: r.x + r.width / 2 - 18, y: r.y + 10, width: 36, height: 4)
    discard drawSdfBox(grip, 2, 0, ink.withAlpha(0.3), ink.withAlpha(0.3))

proc sheetRect(widget: Widget, h: float32): Rect =
  let b = widget.bounds
  Rect(x: b.x, y: b.y + b.height - h, width: b.width, height: h)

proc settle(widget: Widget, target: float32) =
  ## Head for `target` px (0: closed).
  let widget = BottomSheet(widget)
  widget.target = target
  if target <= 0 and widget.isOpen:
    widget.isOpen = false
    if widget.onClose != nil: widget.onClose()
  widget.layoutDirty = true
  widget.markDirtyToRoot()

proc open*(widget: BottomSheet) =
  ## Rise to the first snap.
  widget.isOpen = true
  widget.visible = true
  let screen = if widget.parent != nil: widget.parent.bounds.height else: widget.bounds.height
  widget.target = (if widget.snaps.len > 0: widget.snaps[0] else: 0.5'f32) * screen
  wantFocus(widget)
  widget.layoutDirty = true
  if widget.parent != nil: widget.parent.layoutDirty = true
  widget.markDirtyToRoot()

proc close*(widget: BottomSheet) =
  widget.settle(0)
