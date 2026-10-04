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

defineWidget(Dock):
  layout:
    # A Dock fills what its parent gives it; with no size it takes its
    # children's natural extents in the obvious arrangement.
    var free = widget.bounds
    let sized = free.width > 0 and free.height > 0

    for child in widget.children:
      if child of Docked:
        let side = Docked(child).side
        child.bounds = Rect(x: free.x, y: free.y)
        case side
        of DockSide.top, DockSide.bottom:
          child.bounds.width = max(0.0'f32, free.width)
        of DockSide.left, DockSide.right:
          child.bounds.height = max(0.0'f32, free.height)
        child.layout()
        case side
        of DockSide.top:
          free.y += child.bounds.height
          free.height -= child.bounds.height
        of DockSide.bottom:
          child.bounds.y = free.y + free.height - child.bounds.height
          child.layout()
          free.height -= child.bounds.height
        of DockSide.left:
          free.x += child.bounds.width
          free.width -= child.bounds.width
        of DockSide.right:
          child.bounds.x = free.x + free.width - child.bounds.width
          child.layout()
          free.width -= child.bounds.width
      else:
        child.bounds = Rect(x: free.x, y: free.y,
                            width: max(0.0'f32, free.width),
                            height: max(0.0'f32, free.height))
        child.layout()

    if not sized:
      var right, bottom = 0.0'f32
      for child in widget.children:
        right = max(right, child.bounds.x + child.bounds.width)
        bottom = max(bottom, child.bounds.y + child.bounds.height)
      if widget.bounds.width <= 0: widget.bounds.width = right - widget.bounds.x
      if widget.bounds.height <= 0: widget.bounds.height = bottom - widget.bounds.y
