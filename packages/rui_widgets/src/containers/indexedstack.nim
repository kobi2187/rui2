## IndexedStack -- many children, one shown.
##
## yui's `stack`: pages that occupy the same box with only the one at `index`
## visible (Flutter's IndexedStack; TabControl is this plus a tab strip). It is
## as big as its biggest child, so switching never moves what is around it, and
## the hidden children keep their state. Set `index` from code, or bind it:
## `IndexedStack(index = page.value)`.
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
    alignment: Alignment = AlignmentTopLeft

  layout:
    # A Stack (Flutter): as big as its biggest child, each child at its own
    # size -- any size up to the stack's -- placed by `alignment`.
    let given = widget.arrangeConstraints
    let own = given.constrain(widget.measure(given))
    widget.bounds.width = own.width
    widget.bounds.height = own.height
    showOnlyIndexed(widget, widget.index)
    for child in widget.children:
      let s = child.measure(given.loosen())
      let off = alignmentOffset(widget.alignment, (own.width - s.width, own.height - s.height))
      child.arrange(Rect(x: widget.bounds.x + off.x, y: widget.bounds.y + off.y,
                         width: s.width, height: s.height))

method computeSize*(widget: IndexedStack, c: Constraints): Size =
  for child in widget.children:
    let s = child.measure(c.loosen())
    result.width = max(result.width, s.width)
    result.height = max(result.height, s.height)
  result = c.constrain(result)
