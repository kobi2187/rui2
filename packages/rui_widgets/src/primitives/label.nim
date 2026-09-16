## Label Primitive Widget
##
## Renders text through Pango, so full Unicode, BiDi (Hebrew/Arabic) and complex
## script shaping come for free, along with real font metrics.
##
## A Label sizes itself: its `layout` measures the text and sets its own height
## (and width, when the parent has not imposed one), which is what lets vertical
## and horizontal stacks arrange labels without every caller assigning bounds by
## hand.

import rui_core
import rui_drawing
import ../text_content
export text_content
import raylib

template contentOf*(widget: untyped): TextContent =
  ## This label as a TextContent. A template, not a proc: the Label type does
  ## not exist until the macro below has expanded.
  ##
  ## `layout` and `render` both go through here, which is the point -- they used
  ## to build the same seven-field TextStyle literal separately and decide
  ## separately whether to wrap.
  TextContent(
    text: widget.text,
    style: textStyle(widget.fontSize, widget.color, widget.fontFamily,
                     widget.bold, widget.italic, widget.underline),
    align: widget.align,
    wrap: widget.wrap,
    markup: widget.markup,
    wrapWidth: widget.bounds.width)

definePrimitive(Label):
  props:
    text: string
    fontSize: float = 14.0
    color: raylib.Color = BLACK
    fontFamily: string = ""     ## "" resolves to the system Sans alias
    bold: bool = false
    italic: bool = false
    underline: bool = false
    align: TextAlign = TextAlign.Left
    wrap: bool = false          ## wrap to the width the parent assigned
    markup: bool = false        ## treat `text` as Pango markup:
                                ## "<b>bold</b> <span foreground='#c00'>red</span>"
                                ## Colours come from the markup, so `color` is ignored.

  state:
    selfWidth: float    ## the width this label last measured for itself
    selfHeight: float

  layout:
    let content = widget.contentOf
    let metrics = content.measure()

    # Keep a width the *parent* assigned, but re-measure one this label set
    # for itself -- otherwise a free-standing label can never grow again once
    # it has a non-zero width, and bound text silently stops resizing.
    let parentAssigned = widget.bounds.width > 0 and
                         widget.bounds.width != widget.selfWidth
    if not parentAssigned:
      widget.bounds.width = metrics.width
      widget.selfWidth = metrics.width

    widget.bounds.height = metrics.height
    widget.selfHeight = metrics.height

  render:
    widget.contentOf.paint(widget.bounds)
