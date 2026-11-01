## BottomNav -- the row of destinations along the bottom of a phone-style
## screen: an icon and a label each, the current one marked, and a badge with
## a count where something is waiting.
##
## ```nim
## var pages: IndexedStack
## ui:
##   BottomNav(items = @[navItem("⌂", "Home"), navItem("✉", "Mail", badge = 3),
##                       navItem("⚙", "Settings")],
##             onSelect = proc(i: int) = pages.index = i)
## ```
##
## A press picks a destination (`onSelect`). Focused, Left/Right/Home/End move
## along it, as every pick-one control does (choice.nim).

import rui_core
import rui_drawing
import ../choice
import std/options
import raylib

type NavItem* = object
  icon*, label*: string
  badge*: int                     ## a count to show; 0 for none

proc navItem*(icon, label: string, badge = 0): NavItem =
  NavItem(icon: icon, label: label, badge: badge)

proc slotRect*(bounds: Rect, count, i: int): Rect =
  ## Destination `i` of `count`: equal shares of the width.
  let w = bounds.width / float32(max(1, count))
  Rect(x: bounds.x + float32(i) * w, y: bounds.y, width: w, height: bounds.height)

proc choose(widget: Widget, i: int)

definePrimitive(BottomNav):
  props:
    items: seq[NavItem] = @[]
    initialSelected: int = 0
    barHeight: float32 = 64.0
    intent: ThemeIntent = Default

  state:
    selected: int

  actions:
    onSelect(index: int)

  init:
    widget.focusable = true
    widget.selected = clamp(widget.initialSelected, 0, max(0, widget.items.high))

  events:
    on_mouse_down:
      for i in 0 ..< widget.items.len:
        if slotRect(widget.bounds, widget.items.len, i).contains(event.mousePos.x, event.mousePos.y):
          widget.choose(i)
          return true
      return false
    on_key_down:
      if not widget.focused: return false
      let m = choiceKey(event.key, widget.items.len, widget.selected, vertical = false)
      if not m.handled: return false
      widget.choose(m.index)
      return true

  layout:
    if widget.bounds.height <= 0: widget.bounds.height = widget.barHeight
    if widget.bounds.width <= 0: widget.bounds.width = 360

  render:
    let props = currentTheme.getThemeProps(widget.intent, Normal)
    let b = widget.bounds
    let ink = props.foregroundColor.get(BLACK)
    let accent = props.activeColor.get(ink)
    drawRect(b, props.backgroundColor.get(WHITE))
    drawLine(b.x, b.y + 0.5, b.x + b.width, b.y + 0.5, ink.withAlpha(0.12))
    for i, it in widget.items:
      let r = slotRect(b, widget.items.len, i)
      let here = i == widget.selected
      let c = if here: accent else: ink.withAlpha(0.65)
      let cx = r.x + r.width / 2
      let iconY = r.y + r.height * 0.18
      if here:                        # a pill behind the current icon
        let pill = Rect(x: cx - 28, y: iconY - 4, width: 56, height: 32)
        discard drawSdfBox(pill, 16, 0, accent.withAlpha(0.16), accent.withAlpha(0.16))
      var ic = props.captionStyle(c)
      ic.fontSize = 22
      let s = measureText(it.icon, ic)
      drawStyledText(it.icon, cx - s.width / 2, iconY, ic)
      var lab = props.captionStyle(c)
      lab.fontSize = max(10'f32, lab.fontSize - 3)
      lab.bold = here
      drawStyledText(it.label, cx, r.y + r.height * 0.64, lab, centered = true)
      if it.badge > 0:
        let danger = currentTheme.getThemeProps(Danger).activeColor.get(Color(r: 210, g: 50, b: 50, a: 255))
        let text = if it.badge > 99: "99+" else: $it.badge
        var bs = props.captionStyle(WHITE)
        bs.fontSize = 10
        bs.bold = true
        let tw = measureText(text, bs).width
        let bw = max(16'f32, tw + 8)
        let br = Rect(x: cx + 6, y: iconY - 6, width: bw, height: 16)
        discard drawSdfBox(br, 8, 0, danger, danger)
        drawStyledText(text, br.x + (bw - tw) / 2, br.y + 1, bs)
    if widget.focused: drawThemedFocusRing(slotRect(b, widget.items.len, widget.selected), props)

proc choose(widget: Widget, i: int) =
  let widget = BottomNav(widget)
  if i == widget.selected or i < 0 or i >= widget.items.len: return
  widget.selected = i
  widget.isDirty = true
  if widget.onSelect != nil: widget.onSelect(i)
