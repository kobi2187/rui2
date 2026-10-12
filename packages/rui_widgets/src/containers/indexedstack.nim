## IndexedStack -- many children, one shown.
##
## yui's `stack`: pages that occupy the same box with only the one at `index`
## visible (Flutter's IndexedStack; TabControl is this plus a tab strip). It is
## as big as its biggest child, so switching never moves what is around it, and
## the hidden children keep their state. Set `index` from code, or bind it:
## `IndexedStack(index = -> page)`.
##
## ```nim
## IndexedStack(index = 1):
##   LoginForm()
##   Dashboard()
## ```

import rui_core

proc showOnlyIndexed(widget: Widget, index: int) =
  for i, child in widget.children:
    child.visible = i == index

defineWidget(IndexedStack):
  props:
    index: int = 0

  layout:
    let own = widget.measure(constraintsOf(widget.bounds))
    widget.bounds.width = own.width
    widget.bounds.height = own.height
    showOnlyIndexed(widget, widget.index)
    for child in widget.children:
      child.arrange(Rect(x: widget.bounds.x, y: widget.bounds.y,
                         width: own.width, height: own.height))

method computeSize*(widget: IndexedStack, c: Constraints): Size =
  for child in widget.children:
    let s = child.measure(c)
    result.width = max(result.width, s.width)
    result.height = max(result.height, s.height)
  if c.tightWidth: result.width = c.minWidth
  if c.tightHeight: result.height = c.minHeight
