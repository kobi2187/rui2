## The text engine the three text widgets share.
##
## Label, TextInput and TextArea differ in their chrome and in whether they can
## be edited. What they do *not* differ in is the part that is actually hard:
## turning a string plus a style into a size, and then onto the screen, through
## Pango. That was written out separately in each of them -- the same seven-field
## `TextStyle(...)` literal, the same decision about whether to measure wrapped
## or on one line, the same markup fork -- and kept in step by hand.
##
## A `TextContent` is that shared part as a value: what to show, how, and how
## wide it is allowed to get. `measure` and `paint` take one and do the rest.
##
## ## Why one engine rather than one widget
##
## Issue #30 proposed collapsing the three widgets into one with `editable` and
## `multiline` flags. They are closer than that suggests in their text handling
## and further apart in everything else: a Label has markup and alignment and no
## chrome; an input has a box, a placeholder, a caret, a maximum length and a
## selection. One type carrying all of it would give every Label in a list four
## caret fields it can never use, and would make half its props meaningful only
## in some combinations -- the shape a flag argument usually takes just before
## it becomes hard to read.
##
## So the engine is shared and the surfaces stay: `newLabel`, `newTextInput`,
## `newTextArea`. "One good text widget and derive the rest", with the widget
## being the deep module rather than the type.

import rui_core
import rui_drawing

type
  TextContent* = object
    ## Everything needed to size and paint a run of text.
    text*: string
    style*: TextStyle
    align*: TextAlign
    wrap*: bool
      ## Break at `wrapWidth` rather than running on one line.
    markup*: bool
      ## Treat `text` as Pango markup: "<b>bold</b> <span foreground='#c00'>red</span>".
      ## Colours then come from the markup, and `style.color` is ignored.
    wrapWidth*: float32
      ## The width to wrap against. 0 means "not known yet", which is what a
      ## widget has before its parent has assigned one -- and the reason
      ## measuring falls back to a single line rather than wrapping to nothing.

proc textStyle*(fontSize: float32, color: Color, fontFamily = "",
                bold = false, italic = false, underline = false): TextStyle =
  ## The TextStyle literal every text widget was writing out in full, usually
  ## twice -- once in `layout` and once in `render`, where the two could drift.
  TextStyle(fontFamily: fontFamily, fontSize: fontSize, color: color,
            bold: bold, italic: italic, underline: underline)

proc wrapsHere*(content: TextContent): bool =
  ## Wrapping needs both a request and a width to wrap against.
  content.wrap and content.wrapWidth > 0

proc pangoWrapWidth*(content: TextContent): int32 =
  ## Pango's convention: -1 for no wrapping.
  if content.wrapsHere: content.wrapWidth.int32 else: -1'i32

proc measure*(content: TextContent): TextMetrics =
  ## How big this text is. Three paths, because Pango measures markup, wrapped
  ## text and a single line through three different calls.
  if content.markup:
    let m = measureMarkupPango(content.text, content.style.pangoFont,
                               content.pangoWrapWidth)
    return TextMetrics(width: m.width, height: m.height,
                       lineHeight: m.height, baseline: m.baseline)
  if content.wrapsHere:
    return measureTextWrapped(content.text, content.style, content.wrapWidth)
  measureText(content.text, content.style)

proc paint*(content: TextContent, rect: Rect) =
  ## Draw it into `rect`, by the same three paths measure uses -- so what is
  ## drawn is what was measured.
  if content.markup:
    drawMarkupPango(content.text, rect.x, rect.y, content.style.pangoFont,
                    content.pangoWrapWidth)
  elif content.wrap:
    drawTextLayout(TextLayout(text: content.text, rect: rect,
                              style: content.style, align: content.align,
                              wrap: true))
  else:
    drawText(content.text, rect, content.style, content.align)

proc lineHeight*(content: TextContent): float32 =
  ## Height of one line in this style, for widgets that lay out line by line.
  ## Measured from a glyph with both an ascender and a descender rather than
  ## from the font size, which is not the same number.
  measureText("Ag", content.style).height
