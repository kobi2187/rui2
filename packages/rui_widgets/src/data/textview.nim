## TextView -- a long text to read, scrolled, read only as far as it is shown.
##
## A read-only TextArea holds its whole text and wraps all of it whenever its
## width changes: right for a note or a chapter, not for a book or a log of a
## million lines. A TextView reads from a row source, one paragraph a row, and
## lays out only the lines on screen (a `TextPager`, sources/text_pager.nim):
##
## ```nim
## TextView(source = newLinesSource("book.txt"), fontSize = 18)
## ```
##
## - **Lazy.** Only the paragraphs on screen, and a stretch ahead, are read --
##   in the background, by the source -- and wrapped. Lines still being read
##   fill in when they arrive.
## - **Scrolls by lines**: the wheel (three a notch), Up/Down, PageUp/PageDown,
##   Home/End. It stops when the last line is at the bottom.
## - **The scroll bar counts paragraphs**, since the height of text never laid
##   out is not known: dragging it jumps to a paragraph, laid out on the spot
##   without the ones before it. Its arrows step a line, its track a page.
## - **The place is a text position** (`top`, `scrollTo`, `onScroll`), so a
##   new width keeps the paragraph at the top, and a reader can save where it
##   was and reopen there.
## - The text is drawn by a Label holding just the visible lines.

import rui_core
import rui_drawing
import ../input/textarea
import ../sources
import ../scroll_drag
import ../hover
import std/options
import raylib

proc scrollLines*(widget: Widget, n: int)
proc scrollTo*(widget: Widget, pos: TextPos)
proc scrollToEnd*(widget: Widget)
proc textStyle(widget: Widget): TextStyle
proc textArea(widget: Widget): Rect
proc linesShown(widget: Widget): int
proc barContent(widget: Widget): float32
proc barView(widget: Widget): float32
proc barScroll(widget: Widget): float32

definePrimitive(TextView):
  props:
    source: RowSource = nil        ## one paragraph a row
    fontSize: float32 = 16.0
    fontFamily: string = ""
    padding: float32 = 8.0
    intent: ThemeIntent = Default

  state:
    pager: TextPager
    pagerOf: RowSource             # the source the pager reads
    top: TextPos                   # the first line shown
    vbar: VBar
    lastWidth: float32

  actions:
    onScroll(top: TextPos)

  init:
    widget.focusable = true
    widget.resetOnLeave:
      widget.vbar.hover = false
    widget.addChild(newLabel(text = "", wrap = true))   # lines already fit: it breaks none

  events:
    on_mouse_wheel:
      widget.scrollLines(-int(event.wheelDelta * 3))
      return true

    on_mouse_move:
      var y = widget.barScroll
      let hoverWas = widget.vbar.hover
      if widget.vbar.barMove(widget.barTrack, widget.barContent, widget.barView, y,
                             event.mousePos):
        widget.scrollTo(TextPos(row: int(y), line: 0))
        return true
      if widget.vbar.hover != hoverWas: widget.isDirty = true
      return false

    on_mouse_up:
      if widget.vbar.barUp():
        widget.isDirty = true
        return true
      return false

    on_mouse_down:
      let track = widget.barTrack
      var y = widget.barScroll
      let press = barPress(track, widget.barContent, widget.barView, y, event.mousePos)
      case press.kind
      of bpNone: return false
      of bpStepUp: widget.scrollLines(-1)
      of bpStepDown: widget.scrollLines(1)
      of bpPageUp, bpPageDown:
        if isTouch():                # a finger jumps there and drags (scroll_drag)
          discard widget.vbar.barDown(track, widget.barContent, widget.barView,
                                      widget.barView, y, event.mousePos)
          widget.scrollTo(TextPos(row: int(y), line: 0))
          capturePointer(widget)
        else:
          let page = max(1, widget.linesShown - 1)
          widget.scrollLines(if press.kind == bpPageUp: -page else: page)
      of bpThumb:
        discard widget.vbar.barDown(track, widget.barContent, widget.barView,
                                    widget.barView, y, event.mousePos)
        capturePointer(widget)
      widget.isDirty = true
      return true

    on_key_down:
      if not widget.focused: return false
      let page = max(1, widget.linesShown - 1)
      case event.key
      of KeyboardKey.Down: widget.scrollLines(1)
      of KeyboardKey.Up: widget.scrollLines(-1)
      of KeyboardKey.PageDown, KeyboardKey.Space: widget.scrollLines(page)
      of KeyboardKey.PageUp: widget.scrollLines(-page)
      of KeyboardKey.Home: widget.scrollTo(TextPos())
      of KeyboardKey.End: widget.scrollToEnd()
      else: return false
      return true

  layout:
    if widget.bounds.width <= 0: widget.bounds.width = 400
    if widget.bounds.height <= 0: widget.bounds.height = 300
    if widget.source != widget.pagerOf:
      widget.pagerOf = widget.source
      widget.top = TextPos()
      widget.pager = nil
      if widget.source != nil:
        widget.pager = newTextPager(widget.source, widget.textStyle)
        widget.source.attach(widget, proc(change: SeqChange) = discard)  # redraws as rows arrive
    let label = Label(widget.children[0])
    label.fontSize = widget.fontSize
    label.fontFamily = widget.fontFamily
    let area = widget.textArea
    var text = ""
    if widget.pager != nil:
      widget.pager.setStyle(widget.textStyle)
      widget.pager.setArea(area.width, area.height)
      if area.width != widget.lastWidth:          # re-wrapped: keep the paragraph
        widget.lastWidth = area.width
        widget.top.line = 0
      let page = widget.pager.pageAt(widget.top)
      if page.isSome: text = page.get.text
    if label.text != text: label.text = text
    label.arrange(area)
    widget.childClip = some(Rect(x: area.x - widget.bounds.x, y: area.y - widget.bounds.y,
                                 width: area.width, height: area.height))

  render:
    let props = currentTheme.getThemeProps(widget.intent, Normal)
    widget.vbar.drawBar(widget.barTrack, widget.barContent, widget.barView,
                        widget.barScroll, props)

# ---------------------------------------------------------------------------

proc textStyle(widget: Widget): TextStyle =
  let widget = TextView(widget)
  TextStyle(fontSize: widget.fontSize, fontFamily: widget.fontFamily)

proc textArea(widget: Widget): Rect =
  let widget = TextView(widget)
  ## Where the lines go: inside the padding, left of the scroll bar.
  let bar = fingerSized(currentTheme.scrollbarThickness)
  let p = widget.padding
  Rect(x: widget.bounds.x + p, y: widget.bounds.y + p,
       width: max(0'f32, widget.bounds.width - 2 * p - bar),
       height: max(0'f32, widget.bounds.height - 2 * p))

proc linesShown(widget: Widget): int =
  let widget = TextView(widget)
  if widget.pager == nil: 1 else: widget.pager.linesPerPage

proc canGoOn(widget: TextView): bool =
  ## More text below the last line shown.
  if widget.pager == nil: return false
  let page = widget.pager.pageAt(widget.top)
  page.isSome and not widget.pager.atEnd(page.get.next)

# The scroll bar, in paragraphs.
proc barContent(widget: Widget): float32 =
  let widget = TextView(widget)
  if widget.source == nil: 0'f32 else: float32(widget.source.count)

proc barView(widget: Widget): float32 =
  let widget = TextView(widget)
  if widget.pager == nil: return 1
  let page = widget.pager.pageAt(widget.top)
  if page.isNone: return 1
  max(1'f32, float32(page.get.next.row - widget.top.row))

proc barScroll(widget: Widget): float32 =
  let widget = TextView(widget)
  if widget.pager == nil: return 0
  let lines = widget.pager.lineCount(widget.top.row)
  float32(widget.top.row) +
    (if lines.isSome and lines.get > 0: widget.top.line / lines.get else: 0)

proc moved(widget: TextView, was: TextPos) =
  if widget.top == was: return
  widget.layoutDirty = true
  widget.markDirtyToRoot()
  if widget.onScroll != nil: widget.onScroll(widget.top)

proc scrollLines*(widget: Widget, n: int) =
  ## Move the text `n` lines on (back, when negative). It goes no further than
  ## the last line at the bottom, and waits for lines still being read.
  let widget = TextView(widget)
  if widget.pager == nil or n == 0: return
  let was = widget.top
  if n < 0:
    let got = widget.pager.stepLines(widget.top, n)
    if got.isSome: widget.top = got.get
  else:
    for _ in 1 .. n:
      if not widget.canGoOn: break
      let got = widget.pager.stepLines(widget.top, 1)
      if got.isNone or got.get == widget.top: break
      widget.top = got.get
  widget.moved(was)

proc scrollTo*(widget: Widget, pos: TextPos) =
  ## Put `pos` at the top -- a saved place, or where the scroll bar was dragged.
  let widget = TextView(widget)
  let was = widget.top
  var row = pos.row
  if widget.source != nil: row = min(row, max(0, widget.source.count - 1))
  widget.top = TextPos(row: max(0, row), line: max(0, pos.line))
  widget.moved(was)

proc scrollToEnd*(widget: Widget) =
  ## The last screenful: the last line at the bottom (of the text counted so far).
  let widget = TextView(widget)
  if widget.pager == nil or widget.source.count == 0: return
  let was = widget.top
  let last = widget.source.count - 1
  let lines = widget.pager.lineCount(last)          # none while still being read
  widget.top = TextPos(row: last, line: (if lines.isSome: lines.get - 1 else: 0))
  let back = widget.pager.stepLines(widget.top, -(widget.linesShown - 1))
  if back.isSome: widget.top = back.get
  widget.moved(was)
