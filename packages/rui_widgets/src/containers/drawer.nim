## Drawer -- a side panel that slides open and shut.
##
## It sits in the flow like any child: put it first in a Row, with the main
## content after it, and the content gives way as the drawer opens. `open`
## starts it open or closed and `setOpen` / `toggle` change it; the width eases
## over the theme's transition time (instantly with reduced motion). `side`
## decides which edge the content hugs. Closed, it takes no room at all.
##
## ```nim
## Row():
##   Drawer(width = 240):
##     Label(text = "Menu")
##   Expanded(): Content()
## ```

import rui_core
import rui_drawing
import std/options

type DrawerSide* = enum dsLeft, dsRight

definePrimitive(Drawer):
  props:
    width: float32 = 240.0
    initialOpen: bool = true
    side: DrawerSide = dsLeft
    intent: ThemeIntent = Default

  state:
    open: bool
    slide: Animated[float32]
    shown: float32

  layout:
    widget.shown = widget.slide.follow(widget, (if widget.open: 1.0'f32 else: 0.0'f32),
                                       currentTheme.transitionSeconds)
    let w = widget.width * widget.shown
    let h = if widget.bounds.height > 0: widget.bounds.height
            elif widget.children.len > 0: widget.children[0].measure(unbounded().withWidth(widget.width)).height
            else: 0.0'f32
    widget.bounds.width = w
    widget.bounds.height = h
    if widget.children.len > 0:
      let child = widget.children[0]
      child.visible = w > 1
      let x = if widget.side == dsLeft: widget.bounds.x else: widget.bounds.x + w - widget.width
      child.arrange(Rect(x: x, y: widget.bounds.y, width: widget.width, height: h))
    widget.childClip = some(Rect(x: 0, y: 0, width: w, height: h))   # widget-local

  render:
    if widget.shown > 0.01:
      drawThemedRect(widget.bounds, currentTheme.getThemeProps(widget.intent, Normal))

method computeSize*(widget: Drawer, c: Constraints): Size =
  # Where the slide is now, not where it is going: the content beside it
  # gives way as it moves rather than jumping to the end.
  let t = widget.slide.follow(widget, (if widget.open: 1.0'f32 else: 0.0'f32),
                              currentTheme.transitionSeconds)
  var h = 0.0'f32
  if widget.children.len > 0:
    h = widget.children[0].measure(unbounded().withWidth(widget.width)).height
  Size(width: widget.width * t, height: (if c.tightHeight: c.minHeight else: h))

proc setOpen*(widget: Drawer, open: bool) =
  if widget.open == open: return
  widget.open = open
  widget.layoutDirty = true
  widget.markDirtyToRoot()

proc toggle*(widget: Drawer) = widget.setOpen(not widget.open)
