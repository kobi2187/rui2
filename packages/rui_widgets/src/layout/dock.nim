## Dock -- the app-window layout, from the original layout design.
##
## Children are docked to an edge in order, each taking a strip off what is
## left: a toolbar docked top, a status bar bottom, a sidebar left, and the
## last child filling the middle. This was `DockContainer` in the old
## modules/layout, the one container there with no Flutter counterpart (the
## nearest is Scaffold); it is kept because desktop apps are built this way.
##
## ```nim
## ui:
##   Dock():
##     Docked(side = DockSide.top):
##       ToolBar()
##     Docked(side = DockSide.bottom):
##       StatusBar()
##     Docked(side = DockSide.left):
##       SizedBox(width = 200):
##         TreeView()
##     TextArea()                 # not docked: fills what is left
## ```

import rui_core

type DockSide* {.pure.} = enum
  left, top, right, bottom

# Docks its one child to a side of the enclosing Dock.
defineWidget(Docked):
  props:
    side: DockSide = DockSide.top

  layout:
    wrapChild(widget)

type DockPlan = object
  rects: seq[Rect]      # each child, relative to the Dock's corner
  own: Size

proc planDock(widget: Widget, c: Constraints): DockPlan =
  ## Docked children take their side in order, each from what the ones
  ## before left free; anything else fills the rest. A free side of the Dock
  ## is its children's natural extent.
  let fixedW = if c.tightWidth: c.minWidth else: 0.0'f32
  let fixedH = if c.tightHeight: c.minHeight else: 0.0'f32
  var free = Rect(width: fixedW, height: fixedH)
  for child in widget.children:
    var cc = unbounded()
    var r: Rect
    if child of Docked:
      let side = Docked(child).side
      if side in {DockSide.top, DockSide.bottom}:
        if free.width > 0: cc = cc.withWidth(free.width)
      elif free.height > 0: cc = cc.withHeight(free.height)
      let s = child.measure(cc)
      r = Rect(x: free.x, y: free.y, width: s.width, height: s.height)
      case side
      of DockSide.top:
        free.y += s.height; free.height -= s.height
      of DockSide.bottom:
        r.y = free.y + free.height - s.height; free.height -= s.height
      of DockSide.left:
        free.x += s.width; free.width -= s.width
      of DockSide.right:
        r.x = free.x + free.width - s.width; free.width -= s.width
    else:
      if free.width > 0: cc = cc.withWidth(free.width)
      if free.height > 0: cc = cc.withHeight(free.height)
      let s = child.measure(cc)
      r = Rect(x: free.x, y: free.y, width: s.width, height: s.height)
    result.rects.add r
  var right, bottom = 0.0'f32
  for r in result.rects:
    right = max(right, r.x + r.width)
    bottom = max(bottom, r.y + r.height)
  let sized = fixedW > 0 and fixedH > 0
  result.own = Size(width: (if sized or fixedW > 0: fixedW else: right),
                    height: (if sized or fixedH > 0: fixedH else: bottom))

defineWidget(Dock):
  layout:
    # A Dock fills what its parent gives it; with no size it takes its
    # children's natural extents in the obvious arrangement.
    let plan = widget.planDock(constraintsOf(widget.bounds))
    widget.bounds.width = plan.own.width
    widget.bounds.height = plan.own.height
    for i, child in widget.children:
      let r = plan.rects[i]
      child.arrange(Rect(x: widget.bounds.x + r.x, y: widget.bounds.y + r.y,
                         width: r.width, height: r.height))

method computeSize*(widget: Dock, c: Constraints): Size = widget.planDock(c).own
method computeSize*(widget: Docked, c: Constraints): Size = widget.wrapSize(c)
