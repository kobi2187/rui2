## Accordion -- a column of Expanders, one open at a time.
##
## The way to keep what you are working on in front and the rest out of the
## way without losing sight of it: open a section and the one that was open
## folds to its header, the open one takes the room left over, and the others
## slide to their new places (the column eases them, `.animateLayout()`; it
## snaps with `motion: reduced`). Content that should fill the open section
## asks for it with `.flex()`. Closing the open one leaves them all folded.
## The first section that starts expanded is the one open.
##
## ```nim
## Accordion():
##   Expander(title = "Inbox"):
##     ListBox(items = mail).flex()
##   Expander(title = "Calendar", initialExpanded = false):
##     Label(text = "Nothing today")
## ```

import rui_core
import expander
import ../layout_motion

definePrimitive(Accordion):
  props:
    spacing: float32 = 4.0
    fill: bool = true            # the open section takes the room left over

  state:
    openIndex: int               # the open section, -1 when all are folded

  init:
    widget.openIndex = -1
    widget.animateLayout = true

  layout:
    # One open at a time: a section opened since the last pass wins, and the
    # rest fold.
    var opened = -1
    for i, child in widget.children:
      if child of Expander and Expander(child).expanded and i != widget.openIndex:
        opened = i
        break
    if opened >= 0:
      widget.openIndex = opened
      for i, child in widget.children:
        if i != opened and child of Expander and Expander(child).expanded:
          Expander(child).expanded = false       # its setter redraws it
          child.layoutDirty = true
    elif widget.openIndex >= 0 and not Expander(widget.children[widget.openIndex]).expanded:
      widget.openIndex = -1

    let across = if widget.bounds.width > 0: unbounded().withWidth(widget.bounds.width)
                 else: unbounded()
    var heights: seq[float32]
    var used = totalSpacing(widget.children.len, widget.spacing)
    var widest = 0.0'f32
    for child in widget.children:
      let s = child.measure(across)
      heights.add s.height
      used += s.height
      widest = max(widest, s.width)
    if widget.bounds.width <= 0: widget.bounds.width = widest
    if widget.bounds.height <= 0: widget.bounds.height = used
    let spare = widget.bounds.height - used
    if widget.fill and spare > 0 and widget.openIndex >= 0:
      heights[widget.openIndex] += spare
    var y = widget.bounds.y
    for i, child in widget.children:
      arrangeMoving(widget, child, Rect(x: widget.bounds.x, y: y,
                                        width: widget.bounds.width, height: heights[i]))
      y += heights[i] + widget.spacing

proc open*(widget: Accordion, index: int) =
  ## Open section `index` from code (the others fold); -1 folds them all.
  for i, child in widget.children:
    if child of Expander:
      let want = i == index
      if Expander(child).expanded != want:
        Expander(child).expanded = want
        child.layoutDirty = true
  widget.openIndex = (if index >= 0 and index < widget.children.len: index else: -1)
  widget.layoutDirty = true
  widget.markDirtyToRoot()

method computeSize*(widget: Accordion, c: Constraints): Size =
  # Measured without laying out: a layout here would set the sections easing
  # toward their measuring-time places.
  let across = if c.tightWidth: unbounded().withWidth(c.minWidth) else: unbounded()
  var h = totalSpacing(widget.children.len, widget.spacing)
  var w = 0.0'f32
  for child in widget.children:
    let s = child.measure(across)
    h += s.height
    w = max(w, s.width)
  Size(width: (if c.tightWidth: c.minWidth else: w),
       height: (if c.tightHeight: c.minHeight else: h))
