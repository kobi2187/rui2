## HoverReveal -- controls that show only when the pointer comes for them.
##
## For a page that should stay clean -- a book, a photo, a video -- with its
## controls out of the way until they are wanted. Hidden, the container is no
## more than a faint outline of its bounds: its contents are not drawn and
## take no clicks. When the pointer comes within `reach` pixels, the container
## and everything in it fade in and work as usual; when the pointer has been
## away for `hideDelay` seconds, they fade out again. They stay while
## something inside has keyboard focus (tabbed to, not clicked), or while the pointer is over a popup
## (a dropdown opened from inside). On a touch screen, where nothing hovers,
## the first tap on it only reveals it, and a tap elsewhere hides it.
##
## It fills the area it is given; put it in a Stack over the page and place it
## with Positioned:
##
## ```nim
## Stack(fit = StackFit.expand):
##   BookPage()
##   Positioned(left = 80, right = 80, bottom = 16, height = 52):
##     HoverReveal():
##       Row(spacing = 8.0):
##         Button(text = "Prev")
##         Slider()
##         Button(text = "Next")
## ```
##
## The fade follows the user's motion preference (instant with `reduced` or
## `none`). Hidden or fully shown it costs nothing per frame.

import rui_core
import rui_drawing
import std/[monotimes, times, options]

proc reveal*(widget: Widget, show: bool)
proc watchPointer(widget: Widget): bool

definePrimitive(HoverReveal):
  props:
    reach: float32 = 24.0        ## how near the pointer reveals it, px beyond its bounds
    hideDelay: float = 1.0       ## seconds after the pointer leaves before it fades out
    padding: float32 = 8.0       ## inside its panel, round the content
    intent: ThemeIntent = Default

  state:
    shown: bool                  ## wanted visible now
    fade: Animated[float32]
    level: float32               ## 0 hidden .. 1 shown, as drawn this frame
    awaySince: MonoTime          ## when the pointer left (for hideDelay)
    away: bool
    pollerId: int

  init:
    let w = widget
    widget.pollerId = addPoller(proc(): bool = w.watchPointer())
    widget.disposers.add proc() = removePoller(w.pollerId)

  events:
    on_mouse_down:
      # Hidden, a press only reveals it -- what a tap on a touch screen does,
      # where no hover came first. Its contents are hidden, so they cannot
      # have taken it.
      if not widget.shown:
        widget.reveal(true)
        return true
      return false

  layout:
    let target = if widget.shown: 1.0'f32 else: 0.0'f32
    widget.level = widget.fade.follow(widget, target, currentTheme.transitionSeconds * 1.5)
    if widget.children.len > 0:
      let content = widget.children[0]
      # Not there at all while hidden: not drawn, not hit-tested, not focusable.
      content.visible = widget.level > 0.01
      content.transparency = 1'f32 - widget.level
      let p = widget.padding
      content.arrange(Rect(x: widget.bounds.x + p, y: widget.bounds.y + p,
                           width: max(0'f32, widget.bounds.width - 2 * p),
                           height: max(0'f32, widget.bounds.height - 2 * p)))

  render:
    let props = currentTheme.getThemeProps(widget.intent, Normal)
    let r = props.cornerRadius.get(6.0)
    let surface = props.backgroundColor.get(Color(r: 240, g: 240, b: 240, a: 255))
    let edge = props.borderColor.get(Color(r: 128, g: 128, b: 128, a: 255))
    # Shown, a panel behind the controls so they read over the page; hidden,
    # only a faint outline of where they are.
    let k = widget.level
    let fill = Color(r: surface.r, g: surface.g, b: surface.b,
                     a: uint8(surface.a.float32 * 0.92 * k))
    let lineAlpha = 0.28'f32 + 0.72'f32 * k
    let line = Color(r: edge.r, g: edge.g, b: edge.b, a: uint8(edge.a.float32 * lineAlpha))
    drawRoundedRect(widget.bounds, r, fill)
    drawRoundedRectLines(widget.bounds, r, 1.0, line)

proc focusWithin(w: Widget): bool =
  if w.focused: return true
  for c in w.children:
    if c.focusWithin: return true

proc reveal*(widget: Widget, show: bool) =
  ## Show or hide it from code, as the pointer would.
  let widget = HoverReveal(widget)
  if widget.shown == show: return
  widget.shown = show
  widget.away = false
  widget.layoutDirty = true
  widget.markDirtyToRoot()

proc pointerNear(widget: HoverReveal): bool =
  let p = pointerPos()
  let b = widget.bounds
  let m = widget.reach
  p.x >= b.x - m and p.x <= b.x + b.width + m and
    p.y >= b.y - m and p.y <= b.y + b.height + m

proc watchPointer(widget: Widget): bool =
  ## Each frame: the pointer near (or a popup from inside under it, or focus
  ## inside) keeps it shown; away for hideDelay hides it.
  let widget = HoverReveal(widget)
  if not widget.visible or widget.bounds.width <= 0: return false
  let overPopup = widget.shown and overlayAt(pointerPos().x, pointerPos().y) != nil
  # Keyboard focus inside holds it open; focus a click left behind does not.
  let tabbedIn = keyboardDriving and widget.focusWithin
  let wanted = widget.pointerNear or tabbedIn or overPopup
  if wanted:
    widget.away = false
    if not widget.shown:
      widget.reveal(true)
      return true
    return false
  if not widget.shown: return false
  let now = getMonoTime()
  if not widget.away:
    widget.away = true
    widget.awaySince = now
  let waited = (now - widget.awaySince).inMilliseconds.float / 1000
  if waited >= widget.hideDelay:
    widget.reveal(false)
    return true
  # Nothing else wakes an idle loop when the delay is up.
  widget.repaintAfter(widget.hideDelay - waited + 0.01)
  false

method computeSize*(widget: HoverReveal, c: Constraints): Size =
  ## The content's size and its padding -- the same hidden or shown, so
  ## revealing never moves anything.
  let p = widget.padding * 2
  var s = Size()
  if widget.children.len > 0:
    let inner = (if c.tightWidth: unbounded().withWidth(max(0'f32, c.minWidth - p)) else: unbounded())
    s = widget.children[0].measure(inner)
  Size(width: (if c.tightWidth: c.minWidth else: s.width + p),
       height: (if c.tightHeight: c.minHeight else: s.height + p))
