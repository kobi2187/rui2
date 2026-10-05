## TextArea -- the one text widget
##
## Label, TextInput and TextArea used to be three widgets over one editing
## model and one text engine. They are one widget now, and the difference
## between them is properties that *limit* it:
##
## | Role      | editable | multiline | framed | What it is                    |
## |-----------|----------|-----------|--------|-------------------------------|
## | Label     | false    | (wrap)    | false  | display text, sized to fit    |
## | TextInput | true     | false     | true   | one line; Enter submits       |
## | TextArea  | true     | true      | true   | many lines; Enter is newline  |
##
## `newLabel` and `newTextInput` are constructors that set those properties,
## and `Label` / `TextInput` are names for the same type, so `Label(w).text`
## and `ui: Label(text = "x")` keep working. `getTypeName` reports the role the
## properties give a widget, so scripting selectors like `Label` still find
## labels.
##
## Further limits: `maxLength` (characters), `maxLines` (Enter refuses a line
## past it), `disabled`, and `editable = false` for read-only text. A widget
## that is not editable takes no input at all -- which is what lets a Button's
## caption sit on top of it without swallowing the click.
##
## Up and Down remember the column they started from (`goalColumn`), so passing
## through a short line does not drag the caret left. The text scrolls to keep
## the caret in view (`scrollX` / `scrollY`), clipped to the frame.
##
## A multi-line editor wraps at its width (`wrap`, on by default): the caret,
## selection, clicks, Up/Down and Home/End all work on the lines as drawn,
## which Pango breaks by the Unicode rules. Markup applies to display text
## only.

import rui_core
import text_buffer
export text_buffer
import ../text_content
export text_content
import rui_drawing
import ../containers/scroll_geometry
import std/[strutils, options, math, monotimes]
import std/times except getTime   # raylib's getTime is the clock here
from std/unicode import `$`, runeLen
# rui_core does not re-export KeyboardKey -- its Menu/Down/Up fields collide
# with the Menu widget and with rui_drawing's ArrowDirection.
from raylib import KeyboardKey, getTime

proc lineStarts*(text: string): seq[int] =
  ## Byte offset of the first character of each line. Always at least one entry,
  ## because an empty string is one empty line rather than no lines.
  result = @[0]
  for i, ch in text:
    if ch == '\n':
      result.add(i + 1)

proc lineOf*(text: string, index: int): int =
  ## Which line a byte offset falls on.
  let starts = lineStarts(text)
  result = 0
  for i, start in starts:
    if start <= index:
      result = i
    else:
      break

proc columnOf*(text: string, index: int): int =
  ## How many characters into its line a byte offset is. Characters, not
  ## bytes, so Up/Down line an "é" up with the "e" above it.
  let start = lineStarts(text)[lineOf(text, index)]
  text[start ..< index].runeLen

proc lineEnd*(text: string, line: int): int =
  ## Byte offset just past the last character of a line, not counting the
  ## newline itself.
  let starts = lineStarts(text)
  if line + 1 < starts.len:
    return starts[line + 1] - 1
  text.len

proc indexAtLineColumn*(text: string, line, column: int): int =
  ## The byte offset `column` characters into `line`, clamped to that line's end --
  ## so moving down from a long line onto a short one lands at the short line's
  ## end rather than overshooting into the line after it.
  let starts = lineStarts(text)
  let l = clamp(line, 0, starts.len - 1)
  let stop = lineEnd(text, l)
  result = starts[l]
  for _ in 0 ..< column:
    if result >= stop:
      break
    result = nextBoundary(text, result)

proc verticalMove*(text: string, cursor, goalColumn: int,
                   down: bool): tuple[index, goalColumn: int] =
  ## Where Up (`down = false`) or Down puts the caret, and the column to aim
  ## for on the move after it.
  ##
  ## The goal column is what a run of Up/Down presses keeps: the column the
  ## first press started from, not wherever a short line clamped the caret to.
  ## `goalColumn < 0` means there is no run yet, so the caret's own column is
  ## the goal.
  let goal = if goalColumn >= 0: goalColumn else: columnOf(text, cursor)
  let line = lineOf(text, cursor) + (if down: 1 else: -1)
  (indexAtLineColumn(text, line, goal), goal)

# ----------------------------------------------------------------------------
# Visual lines
#
# What the editor walks, draws and hit-tests is the line as it appears: a
# paragraph that wraps is several of them. Without wrapping they are exactly
# the hard lines. Pango decides where a paragraph breaks.
# ----------------------------------------------------------------------------

type VisualLine* = tuple[start, stop: int, dir: TextDir]
  ## Bytes `start ..< stop` of the text, drawn as one line. `stop` leaves out
  ## a newline; on a line that wraps it is where the next line starts. `dir`
  ## is its paragraph's direction: a wrapped line is laid out in that, not in
  ## whatever its own first letter suggests.

var linesMemo: tuple[text, font: string, width: float32, lines: seq[VisualLine]]

proc visualLines*(text, font: string, wrapWidth: float32): seq[VisualLine] =
  ## The lines `text` is drawn as, wrapped at `wrapWidth` pixels (0: no
  ## wrapping). Remembered for the last text, as the editor asks per key.
  if linesMemo.lines.len > 0 and linesMemo.text == text and
     linesMemo.font == font and linesMemo.width == wrapWidth:
    return linesMemo.lines
  let hard = lineStarts(text)
  for i, start in hard:
    let stop = lineEnd(text, i)
    let dir = paragraphDir(text[start ..< stop])
    if wrapWidth > 0 and stop > start:
      let breaks = softBreaks(text[start ..< stop], font, int32(wrapWidth))
      for k, b in breaks:
        result.add (start + b, (if k + 1 < breaks.len: start + breaks[k + 1] else: stop), dir)
    else:
      result.add (start, stop, dir)
  linesMemo = (text, font, wrapWidth, result)

proc visualLineOf*(lines: openArray[VisualLine], index: int): int =
  ## The line a byte offset is drawn on. At a soft break the caret belongs to
  ## the line that starts there, as in every editor.
  for i, line in lines:
    if line.start <= index: result = i
    else: break

proc softEnd(text: string, line: VisualLine): int =
  ## Where a caret may stand at the end of `line`: before the newline of a
  ## hard line; on a wrapped line, before its last character -- the position
  ## after it is the next line's start.
  if line.stop < text.len and text[line.stop] != '\n' and line.stop > line.start:
    prevBoundary(text, line.stop)
  else:
    line.stop

proc visualColumn*(text: string, lines: openArray[VisualLine], index: int): int =
  let line = lines[visualLineOf(lines, index)]
  text[line.start ..< min(index, text.len)].runeLen

proc indexAtVisual*(text: string, lines: openArray[VisualLine], row, column: int): int =
  ## `column` characters into visual line `row`, clamped to where a caret may
  ## stand on it.
  let line = lines[clamp(row, 0, lines.high)]
  let stop = softEnd(text, line)
  result = line.start
  for _ in 0 ..< column:
    if result >= stop: break
    result = nextBoundary(text, result)

proc verticalMoveVisual*(text: string, lines: openArray[VisualLine],
                         cursor, goalColumn: int,
                         down: bool): tuple[index, goalColumn: int] =
  ## Up / Down over visual lines, keeping the column a run started from.
  let goal = if goalColumn >= 0: goalColumn else: visualColumn(text, lines, cursor)
  let row = visualLineOf(lines, cursor) + (if down: 1 else: -1)
  (indexAtVisual(text, lines, row, goal), goal)

# ----------------------------------------------------------------------------
# Secret text
#
# A password field shows one bullet per character -- per grapheme cluster, so
# an emoji or an accented letter is one dot, as it is one caret step. Editing
# works on the real text; everything that measures or draws goes through the
# bullets, with these two maps between the offsets.
# ----------------------------------------------------------------------------

const MaskBullet* = "\u2022"

proc clusterStarts(text: string): seq[int] =
  ## Byte offset of each grapheme cluster, then text.len.
  let attrs = charAttrs(text)
  for k in 0 ..< attrs.byteAt.high:
    if attrs.cursorStop[k]: result.add attrs.byteAt[k]
  result.add text.len

proc maskOf*(text: string): string =
  ## One bullet per character the caret steps over.
  MaskBullet.repeat(max(0, clusterStarts(text).len - 1))

proc toMasked*(text: string, index: int): int =
  ## Where real byte offset `index` falls in the bullets.
  let starts = clusterStarts(text)
  var n = 0
  while n + 1 < starts.len and starts[n] < index: inc n
  n * MaskBullet.len

proc fromMasked*(text: string, index: int): int =
  ## The real byte offset of bullet offset `index`.
  let starts = clusterStarts(text)
  starts[clamp(index div MaskBullet.len, 0, starts.high)]

const
  SelectionColor = Color(r: 100, g: 150, b: 255, a: 128)
  PlaceholderColor = Color(r: 128, g: 128, b: 128, a: 255)
  ThemeColor* = Color(r: 0, g: 0, b: 0, a: 0)
    ## The default `color`: transparent means "the theme's foreground".
  ThemeFontSize* = 0.0'f32
    ## The default `fontSize`: the theme's text size.
  ThemePadding* = -1.0'f32
    ## The default `padding`: the theme's field inset (its padding + outline).

template fontSizeOf*(widget: untyped): float32 =
  (if widget.fontSize > 0: widget.fontSize
   else: currentTheme.getThemeProps(widget.intent).fontSize.get(14.0'f32))

template inset*(widget: untyped): float32 =
  ## Padding applies only inside a frame; a bare label hugs its text.
  (if not widget.framed: 0.0'f32
   elif widget.padding >= 0: widget.padding
   else: currentTheme.getThemeProps(widget.intent).fieldInset)

template textRect*(widget: untyped): Rect =
  ## The area inside the chrome that text is drawn into.
  Rect(x: widget.bounds.x + widget.inset,
       y: widget.bounds.y + widget.inset,
       width: widget.bounds.width - widget.inset * 2,
       height: widget.bounds.height - widget.inset * 2)

template lineRect*(widget: untyped, lineH: float32): Rect =
  ## Where the lines start. A single-line field centres its line vertically,
  ## so an input given a height tighter than line + padding still reads as
  ## centred rather than sliding against its bottom edge.
  block:
    var r = widget.textRect
    if not widget.multiline and widget.editable:
      r.y = widget.bounds.y + (widget.bounds.height - lineH) / 2
      r.height = lineH
    r

template textColor(widget: untyped): Color =
  (if widget.color.a > 0: widget.color
   else: currentTheme.getThemeProps(widget.intent, ThemeState.Normal)
           .foregroundColor.get(BLACK))

template contentOf*(widget: untyped): TextContent =
  ## This widget's text as a TextContent, so measuring and drawing go through
  ## one engine. A template, not a proc: the TextArea type does not exist until
  ## the macro below has expanded.
  ##
  ## Wrap and markup are display features: an editor shows the source it is
  ## editing, line by line, so both are off while `editable`.
  TextContent(
    text: widget.text,
    style: textStyle(widget.fontSizeOf, widget.textColor, widget.fontFamily,
                     widget.bold, widget.italic, widget.underline),
    align: widget.align,
    wrap: widget.wrap and not widget.editable,
    markup: widget.markup and not widget.editable,
    wrapWidth: widget.textRect.width)

template editWrapWidth*(widget: untyped): float32 =
  ## The width editable text wraps at, or 0 when it does not wrap: only a
  ## multi-line editor with `wrap` does, at the width inside its frame --
  ## and not before it has one.
  (if widget.editable and widget.multiline and widget.wrap and
      widget.textRect.width > 0:
     widget.textRect.width
   else: 0.0'f32)

template linesOf*(widget: untyped): seq[VisualLine] =
  ## The editor's text as drawn, line by line.
  visualLines(widget.text, widget.contentOf.style.pangoFont, widget.editWrapWidth)

template shownText*(widget: untyped): string =
  ## What is drawn: the text, or bullets for a secret.
  (if widget.secret: maskOf(widget.text) else: widget.text)

template toShown(widget: untyped, index: int): int =
  (if widget.secret: toMasked(widget.text, index) else: index)

template toReal(widget: untyped, index: int): int =
  (if widget.secret: fromMasked(widget.text, index) else: index)

template shownLines(widget: untyped): seq[VisualLine] =
  ## The drawn text's lines. A secret is one line, never wrapped.
  (if widget.secret: visualLines(widget.shownText, widget.contentOf.style.pangoFont, 0)
   else: widget.linesOf)

template lineShift(widget: untyped, line: VisualLine, font: string,
                   inner: Rect): float32 =
  ## How far right a line starts. A wrapped right-to-left paragraph hugs the
  ## right edge, as it would in any editor; everything else starts at the left.
  (if widget.editWrapWidth > 0 and line.dir == tdRtl:
     inner.width - measureTextPango(widget.shownText[line.start ..< line.stop], font,
                                    dir = line.dir).width
   else: 0.0'f32)

template indexAt*(widget: untyped, pos: Point): int =
  ## Byte offset of the caret position under a click: which visual line the y
  ## falls on, then Pango for the position within it.
  block:
    let content = widget.contentOf
    let inner = widget.lineRect(content.lineHeight)
    let shown = widget.shownText
    let lines = widget.shownLines
    let row = clamp(int((pos.y - inner.y + widget.scrollY) / content.lineHeight),
                    0, lines.high)
    let line = lines[row]
    let font = content.style.pangoFont
    let hit = indexFromPosition(shown[line.start ..< line.stop], font,
                                pos.x - inner.x + widget.scrollX -
                                  widget.lineShift(line, font, inner),
                                0.0, dir = line.dir)
    widget.toReal(clamp(line.start + hit.index + hit.trailing, line.start,
                        softEnd(shown, line)))

template bufferOf(widget: untyped): TextBuffer =
  initTextBuffer(widget.text, widget.cursorPos, widget.selectionStart,
                 widget.selectionEnd)

template writeBack(widget: untyped, buf: TextBuffer, beforeText: string) =
  ## Store an edited buffer and raise whatever flags the change calls for.
  widget.text = buf.text
  widget.cursorPos = buf.cursor
  widget.selectionStart = buf.selStart
  widget.selectionEnd = buf.selEnd
  widget.isDirty = true
  widget.revealCaret = true          # the caret moved or the text changed
  if widget.text != beforeText:
    # Only a change of text needs a re-measure or an onChange; moving the
    # caret repaints and nothing more.
    widget.layoutDirty = true
    if widget.onChange != nil:
      widget.onChange(widget.text)

template edit*(widget: untyped, body: untyped) =
  ## Run an editing operation against the widget's state as a TextBuffer,
  ## record it for undo, and write it back.
  block:
    var buf {.inject.} = widget.bufferOf
    let before = buf.snapshot
    # Any edit or cursor move ends a run of Up/Down presses; the Up/Down
    # handler restores the goal column after its own edit.
    widget.goalColumn = -1
    body
    widget.history.record(before, buf.snapshot)
    widget.writeBack(buf, before.text)

template travel(widget: untyped, forward: bool): bool =
  ## Undo (`forward = false`) or redo. Not an `edit`: it must not record
  ## itself in the history it is walking.
  block:
    var buf = widget.bufferOf
    let beforeText = buf.text
    let moved = if forward: widget.history.redo(buf)
                else: widget.history.undo(buf)
    if moved:
      widget.goalColumn = -1
      widget.writeBack(buf, beforeText)
    moved

template multiClickWindow(): Duration =
  ## The user's double-click speed.
  initDuration(milliseconds = prefs.doubleClickMs)

template countClick(widget: untyped, at: MonoTime): int =
  ## 1, 2 or 3: a click, a double-click or a triple-click. A click within the
  ## window of the last one continues the run; anything slower starts over.
  block:
    if widget.clickCount > 0 and at - widget.lastClickAt <= multiClickWindow():
      widget.clickCount = min(widget.clickCount + 1, 3)
    else:
      widget.clickCount = 1
    widget.lastClickAt = at
    widget.clickCount

template ctrlKey(widget: untyped, event: GuiEvent): bool =
  ## The Ctrl shortcuts. False for a Ctrl chord this widget does not use, so
  ## the key still reaches focus navigation and the application.
  block:
    var handled = true
    case event.key
    of KeyboardKey.A:
      widget.edit: buf.selectAll()
    of KeyboardKey.C:
      let b = widget.bufferOf
      if b.hasSelection and not widget.secret: setClipboardText(b.selectedText)
    of KeyboardKey.X:
      let b = widget.bufferOf
      if b.hasSelection and not widget.secret:
        setClipboardText(b.selectedText)
        widget.edit: discard buf.deleteSelection()
    of KeyboardKey.V:
      widget.edit: discard buf.paste(clipboardText(), widget.multiline,
                                     widget.maxLength, widget.maxLines)
    of KeyboardKey.Z:
      discard widget.travel(forward = event.shift)
    of KeyboardKey.Y:
      discard widget.travel(forward = true)
    of Left:
      # A secret has no words to show: its word moves go to the ends.
      widget.edit: buf.moveCursor(
        (if widget.secret: 0 else: prevWordStart(buf.text, buf.cursor)),
        extend = event.shift)
    of Right:
      widget.edit: buf.moveCursor(
        (if widget.secret: buf.text.len else: nextWordEnd(buf.text, buf.cursor)),
        extend = event.shift)
    of Home:
      widget.edit: buf.moveCursor(0, extend = event.shift)
    of End:
      widget.edit: buf.moveCursor(buf.text.len, extend = event.shift)
    of Backspace:
      widget.edit:
        if widget.secret: buf.moveCursor(0, extend = true); discard buf.deleteSelection()
        else: discard buf.deleteWordBack()
    of Delete:
      widget.edit:
        if widget.secret: buf.moveCursor(buf.text.len, extend = true); discard buf.deleteSelection()
        else: discard buf.deleteWordForward()
    of Enter, KpEnter:
      # Ctrl+Enter submits even where Enter makes a new line.
      if widget.onSubmit != nil: widget.onSubmit(widget.text)
      else: handled = false
    else:
      handled = false
    handled

template takesInput(widget: untyped): bool =
  widget.editable and not widget.disabled

proc scrollToShow*(scroll, pos, size, view, content: float32): float32 =
  ## The scroll offset that keeps `pos .. pos + size` inside a `view`-long
  ## window, moving as little as possible, and never past the content: a
  ## field is not scrolled into blank space after its text has shrunk.
  result = scroll
  if pos < result:
    result = pos
  elif pos + size > result + view:
    result = pos + size - view
  result = clamp(result, 0.0'f32, max(0.0'f32, content - view))

proc caretPhaseRemaining*(now: float, halfPeriod = 0.5): float =
  ## Seconds until the caret next turns on or off. It blinks on `halfPeriod`
  ## boundaries of the clock (the user's setting; half a second by default),
  ## so this is the time to the next one.
  (floor(now / halfPeriod) + 1.0) * halfPeriod - now

proc roomForLine*(text: string, maxLines: int): bool =
  ## Whether Enter may add a line under a `maxLines` limit (-1: no limit).
  maxLines < 0 or lineStarts(text).len < maxLines

template maxScrollY*(widget: untyped, lineH: float32, inner: Rect): float32 =
  ## How far a multi-line editor's text can scroll: its lines past the view.
  (if widget.multiline: max(0.0'f32, float32(widget.linesOf.len) * lineH - inner.height)
   else: 0.0'f32)

const ScrollBarWidth = 4.0'f32

template scrollTrack*(widget: untyped, inner: Rect): Rect =
  ## Where the vertical scroll bar runs: in the frame's padding beside the
  ## text when there is room, else over the text's right edge.
  block:
    let room = widget.bounds.x + widget.bounds.width - (inner.x + inner.width)
    let x = if room >= ScrollBarWidth + 2: inner.x + inner.width + (room - ScrollBarWidth) / 2
            else: inner.x + inner.width - ScrollBarWidth
    Rect(x: x, y: inner.y, width: ScrollBarWidth, height: inner.height)

template scrollThumb*(widget: untyped, lineH: float32, inner: Rect): Rect =
  ## The scroll bar's thumb, or an empty rect when everything fits.
  block:
    let maxY = widget.maxScrollY(lineH, inner)
    if maxY <= 0:
      Rect()
    else:
      let track = widget.scrollTrack(inner)
      let len = thumbLength(track.height, inner.height, inner.height + maxY)
      Rect(x: track.x, y: track.y + thumbOffset(track.height, len, widget.scrollY, maxY),
           width: track.width, height: len)

template scrollToThumbAt(widget: untyped, pointerY: float32, lineH: float32, inner: Rect) =
  ## Drag the thumb so its grabbed point follows the pointer.
  block:
    let maxY = widget.maxScrollY(lineH, inner)
    let thumb = widget.scrollThumb(lineH, inner)
    let travel = inner.height - thumb.height
    if travel > 0:
      widget.scrollY = clamp((pointerY - widget.barGrab - inner.y) / travel * maxY, 0.0'f32, maxY)
      widget.isDirty = true

template keepCaretInView(widget: untyped, content: TextContent, inner: Rect) =
  ## Scroll so the caret is inside `inner`. Runs while painting, which is when
  ## the caret's pixel position is known; indexAt reads the result.
  block:
    let lineH = content.lineHeight
    let shown = widget.shownText
    let lines = widget.shownLines
    let cursor = widget.toShown(widget.cursorPos)
    let row = visualLineOf(lines, cursor)
    let line = lines[row]
    let lineText = shown[line.start ..< line.stop]
    let caret = cursorPosition(lineText, content.style.pangoFont,
                               cursor - line.start, dir = line.dir)
    let lineW = measureTextPango(lineText, content.style.pangoFont, dir = line.dir).width
    widget.scrollX = if widget.editWrapWidth > 0: 0.0'f32   # wrapped: nothing to the side
                     else: scrollToShow(widget.scrollX, caret.x, 1.0, inner.width,
                                        lineW + 1.0)
    widget.scrollY = if widget.multiline:
                       scrollToShow(widget.scrollY, float32(row) * lineH, lineH,
                                    inner.height, float32(lines.len) * lineH)
                     else: 0.0'f32

template paintEditable(widget: untyped, content: TextContent, inner: Rect) =
  ## Selection, text and caret for editable text, line by line, scrolled and
  ## clipped to `inner`.
  block:
    if widget.focused and widget.revealCaret:
      widget.keepCaretInView(content, inner)
      widget.revealCaret = false
    # Never scrolled past the content (it may have shrunk, or the box grown).
    widget.scrollY = clamp(widget.scrollY, 0.0'f32,
                           widget.maxScrollY(content.lineHeight, inner))
    let lineH = content.lineHeight
    let font = content.style.pangoFont
    let ox = inner.x - widget.scrollX
    let oy = inner.y - widget.scrollY
    let shown = widget.shownText
    let lines = widget.shownLines

    # Selection under the glyphs, one band per line. Both edges from Pango's
    # caret positions, so it lines up with the glyphs in any script.
    if widget.selectionStart >= 0 and widget.selectionStart != widget.selectionEnd:
      let lo = widget.toShown(min(widget.selectionStart, widget.selectionEnd))
      let hi = widget.toShown(max(widget.selectionStart, widget.selectionEnd))
      for i, line in lines:
        if hi < line.start or lo > line.stop or (hi == line.start and lo < line.start):
          continue
        let lineText = shown[line.start ..< line.stop]
        let shift = widget.lineShift(line, font, inner)
        let x0 = shift + cursorPosition(lineText, font, max(lo, line.start) - line.start,
                                        dir = line.dir).x
        let x1 = shift + cursorPosition(lineText, font, min(hi, line.stop) - line.start,
                                        dir = line.dir).x
        let band = intersect(Rect(x: ox + min(x0, x1), y: oy + float32(i) * lineH,
                                  width: abs(x1 - x0), height: lineH), inner)
        if band.width > 0 and band.height > 0:
          drawRect(band, SelectionColor)

    for i, line in lines:
      let y = oy + float32(i) * lineH
      if y + lineH < inner.y or y > inner.y + inner.height:
        continue
      drawTextPangoClipped(shown[line.start ..< line.stop],
                           ox + widget.lineShift(line, font, inner), y, font,
                           content.style.color,
                           Rectangle(x: inner.x, y: inner.y,
                                     width: inner.width, height: inner.height),
                           dir = line.dir)

    if widget.focused and widget.takesInput:
      let cursor = widget.toShown(widget.cursorPos)
      let row = visualLineOf(lines, cursor)
      let line = lines[row]
      let caret = cursorPosition(shown[line.start ..< line.stop],
                                 font, cursor - line.start, dir = line.dir)
      let now = getTime()
      let x = ox + widget.lineShift(line, font, inner) + caret.x
      let y = oy + float32(row) * lineH
      let half = prefs.caretBlinkMs.float / 1000.0
      let caretOn = half <= 0 or int(now / half) mod 2 == 0   # 0: steady
      if caretOn and x >= inner.x and x <= inner.x + inner.width:
        drawLine(x, max(y, inner.y), x, min(y + lineH, inner.y + inner.height),
                 widget.textColor)
      # Nothing else repaints an idle field, so ask for the next blink phase --
      # without this the caret froze in whichever phase the last edit left it.
      if half > 0:
        widget.repaintAfter(caretPhaseRemaining(now, half))

definePrimitive(TextArea):
  props:
    initialText: string = ""
    placeholder: string = "Type here..."
    fontSize: float32 = ThemeFontSize  ## 0: the theme's text size
    color: Color = ThemeColor    ## Transparent: use the theme's foreground
    fontFamily: string = ""      ## "" resolves to the system Sans alias
    bold: bool = false
    italic: bool = false
    underline: bool = false
    align: TextAlign = TextAlign.Left
    wrap: bool = true            ## Wrap at the width: display text, and multi-line editors
    markup: bool = false         ## Display text is Pango markup
    editable: bool = true        ## false: display only, takes no input
    multiline: bool = true       ## false: one line, Enter fires onSubmit
    secret: bool = false         ## Show bullets, never copy, never read by scripts
    maxLength: int = -1          ## Characters; -1 for unlimited
    maxLines: int = -1           ## Lines Enter may create; -1 for unlimited
    framed: bool = true          ## Draw the input box, and pad inside it
    padding: float32 = ThemePadding  ## Inside the frame; < 0: the theme's
    visibleLines: int = 5        ## Height, in lines, when multiline and editable
    disabled: bool = false
    intent: ThemeIntent = Default

  state:
    text: string                 # first, so a bare script `write` means it
    cursorPos: int               # Byte index into text
    selectionStart: int          # -1 when there is no selection
    selectionEnd: int
    dragging: bool
    goalColumn: int              # Column Up/Down aim for; -1 outside a run
    history: EditHistory         # Undo/redo; a script sees only the depths
    clickCount: int              # 1..3 within a multi-click run, 0 before any
    lastClickAt: MonoTime
    scrollX: float32             # How far the text is scrolled, so the caret
    scrollY: float32             # stays in view
    revealCaret: bool            # scroll to the caret at the next paint
    draggingBar: bool            # the scroll bar's thumb is held
    barGrab: float32             # where on the thumb it was taken

  actions:
    onChange(newText: string)
    onSubmit(text: string)

  typeName:
    if not widget.editable: "Label"
    elif not widget.multiline: "TextInput"
    else: "TextArea"

  init:
    widget.focusable = widget.editable
    widget.blockReading = widget.secret
    if widget.secret: widget.multiline = false
    widget.selectionStart = -1
    widget.selectionEnd = -1
    widget.goalColumn = -1

  events:
    on_mouse_down:
      if not widget.takesInput:
        return false
      let lineH = widget.contentOf.lineHeight
      let inner = widget.lineRect(lineH)
      let thumb = widget.scrollThumb(lineH, inner)
      if thumb.height > 0:
        let track = widget.scrollTrack(inner)
        let hitTrack = Rect(x: track.x - 3, y: track.y, width: track.width + 6,
                            height: track.height)
        if hitTrack.contains(event.mousePos.x, event.mousePos.y):
          # On the thumb: hold it where it was taken. On the track: jump so
          # the thumb's middle is under the pointer, then hold it there.
          widget.barGrab = if thumb.contains(thumb.x, event.mousePos.y):
                             event.mousePos.y - thumb.y
                           else: thumb.height / 2
          widget.draggingBar = true
          widget.scrollToThumbAt(event.mousePos.y, lineH, inner)
          return true
      let at = widget.indexAt(event.mousePos)
      case widget.countClick(event.timestamp)
      of 2:
        if widget.secret:
          widget.edit: buf.selectAll()           # no word lengths to reveal
        else:
          let word = wordAt(widget.text, at)
          widget.edit: buf.selectRange(word.a, word.b)
      of 3:
        let line = lineOf(widget.text, at)
        widget.edit: buf.selectRange(lineStarts(widget.text)[line],
                                     lineEnd(widget.text, line))
      else:
        widget.edit: buf.placeCursor(at)
        widget.dragging = true
      return true

    on_mouse_move:
      if widget.draggingBar:
        let lineH = widget.contentOf.lineHeight
        widget.scrollToThumbAt(event.mousePos.y, lineH, widget.lineRect(lineH))
        return true
      if not widget.dragging or not widget.takesInput:
        return false
      widget.edit: buf.dragTo(widget.indexAt(event.mousePos))
      return true

    on_mouse_up:
      if widget.draggingBar:
        widget.draggingBar = false
        return true
      if not widget.dragging:
        return false
      widget.dragging = false
      widget.edit: buf.endDrag()
      return true

    on_mouse_wheel:
      # Three lines a notch (the user's scroll speed is already in the
      # delta). At either end the wheel is left to an enclosing scroll view.
      if not widget.multiline or not widget.editable:
        return false
      let lineH = widget.contentOf.lineHeight
      let maxY = widget.maxScrollY(lineH, widget.lineRect(lineH))
      let next = clamp(widget.scrollY - event.wheelDelta * lineH * 3, 0.0'f32, maxY)
      if next == widget.scrollY:
        return false
      widget.scrollY = next
      widget.isDirty = true
      return true

    on_char:
      if not widget.takesInput or not widget.focused:
        return false
      let r = event.typedRune
      if not r.isTypeable:
        return false
      widget.edit: discard buf.insert($r, widget.maxLength)
      return true

    on_key_down:
      if not widget.takesInput or not widget.focused:
        return false
      if event.ctrl and widget.ctrlKey(event):
        return true
      let shiftDown = event.shift

      case event.key
      of Backspace:
        widget.edit: discard buf.backspace()
        return true

      of Delete:
        widget.edit: discard buf.deleteForward()
        return true

      of Enter, KpEnter:
        if widget.multiline and roomForLine(widget.text, widget.maxLines):
          widget.edit: discard buf.insert("\n", widget.maxLength)
        elif widget.onSubmit != nil:
          widget.onSubmit(widget.text)
        return true

      of Up, Down:
        # A single line has nowhere to go; leave the keys to focus navigation.
        if not widget.multiline:
          return false
        let move = verticalMoveVisual(widget.text, widget.linesOf, widget.cursorPos,
                                      widget.goalColumn, down = event.key == Down)
        widget.edit: buf.moveCursor(move.index, extend = shiftDown)
        widget.goalColumn = move.goalColumn
        return true

      of PageUp, PageDown:
        # A page is the lines in view, less one kept for context. The view
        # moves with the caret, so the line it was on stays where it was.
        if not widget.multiline:
          return false
        let lineH = widget.contentOf.lineHeight
        let inner = widget.lineRect(lineH)
        let rows = max(1, int(inner.height / lineH) - 1)
        let lines = widget.linesOf
        let down = event.key == PageDown
        let goal = if widget.goalColumn >= 0: widget.goalColumn
                   else: visualColumn(widget.text, lines, widget.cursorPos)
        let row = visualLineOf(lines, widget.cursorPos) + (if down: rows else: -rows)
        let target = if row < 0: 0
                     elif row > lines.high: widget.text.len
                     else: indexAtVisual(widget.text, lines, row, goal)
        widget.scrollY = clamp(widget.scrollY + (if down: 1.0'f32 else: -1.0'f32) *
                               float32(rows) * lineH, 0.0'f32,
                               widget.maxScrollY(lineH, inner))
        widget.edit: buf.moveCursor(target, extend = shiftDown)
        widget.goalColumn = goal
        return true

      of Left, Right, Home, End:
        # Home and End go to the ends of the line as drawn.
        let lines = widget.linesOf
        let line = lines[visualLineOf(lines, widget.cursorPos)]
        let target = case event.key
                     of Left: stepCaret(widget.text, widget.cursorPos, -1)
                     of Right: stepCaret(widget.text, widget.cursorPos, 1)
                     of Home: line.start
                     else: softEnd(widget.text, line)
        widget.edit: buf.moveCursor(target, extend = shiftDown)
        return true

      else:
        return false

  layout:
    widget.cursorShape = if widget.takesInput: csText else: csDefault
    widget.blockReading = widget.blockReading or widget.secret
    widget.takesText = widget.takesInput
    let content = widget.contentOf
    let pad = widget.inset * 2
    if not widget.editable:
      # Display text sizes to its content, unless the parent assigned a width.
      # A width it gave itself last time reads as 0 here (beginSelfSizing),
      # so changed text is re-measured.
      if widget.bounds.width <= 0:
        widget.bounds.width = content.measure().width + pad
      # Measured after the width is settled, so wrapped text gets its height.
      # A height the parent assigned is kept -- a Label in a SizedBox(height)
      # takes that height, its text centred in it, as a Flutter Text would.
      if widget.bounds.height <= 0:
        widget.bounds.height = widget.contentOf.measure().height + pad
    else:
      let lines = if widget.multiline: max(1, widget.visibleLines) else: 1
      if widget.bounds.height <= 0:
        widget.bounds.height = content.lineHeight * float32(lines) + pad
        if not widget.multiline:
          widget.bounds.height = max(widget.bounds.height, currentTheme.controlHeight)
      if widget.bounds.width <= 0:
        let floor = if widget.multiline: 240.0'f32 else: 200.0'f32
        # Wrapping text has no natural width beyond the floor: it would be
        # as wide as its longest paragraph, which wrapping is there to avoid.
        widget.bounds.width = if widget.wrap and widget.multiline: floor
                              else: max(floor, content.measure().width + pad)

  render:
    if widget.framed:
      let props = widget.themeProps(widget.intent, crText,
                                    disabled = widget.disabled)
      drawInteractiveBox(widget.bounds, props, focused = widget.focused)

    var content = widget.contentOf
    let inner = widget.lineRect(content.lineHeight)
    let showPlaceholder = widget.text.len == 0 and widget.editable
    if showPlaceholder:
      content.text = widget.placeholder
      content.style.color = PlaceholderColor

    if not widget.editable or showPlaceholder:
      # Display text: one paint, with alignment, wrapping and markup.
      content.paint(inner)
    if widget.editable and (not showPlaceholder or widget.focused):
      # Over a placeholder this draws only the caret: the text is empty.
      widget.paintEditable(widget.contentOf, inner)

    # The scroll bar, when there is more text than fits: a slim thumb in the
    # theme's border colour, stronger while held or hovered.
    if widget.editable and widget.multiline:
      let thumb = widget.scrollThumb(content.lineHeight, inner)
      if thumb.height > 0:
        let props = widget.themeProps(widget.intent, crText)
        let c = props.borderColor.get(GRAY)
        drawRoundedRect(thumb, ScrollBarWidth / 2,
                        c.withAlpha(if widget.draggingBar or widget.hovered: 0.9'f32 else: 0.5'f32))

    if widget.disabled:
      drawDisabledOverlay(widget.bounds)

# ============================================================================
# The limited roles
# ============================================================================

type
  Label* = TextArea
    ## A TextArea with `editable = false` and no frame: display text.
  TextInput* = TextArea
    ## A TextArea with `multiline = false`: one line, Enter submits.

proc newLabel*(text = "", fontSize: float32 = ThemeFontSize, color: Color = ThemeColor,
               fontFamily = "", bold = false, italic = false, underline = false,
               align = TextAlign.Left, wrap = false, markup = false): Label =
  ## Display text, in the theme's text colour unless given one. It was black
  ## by default, which vanished on every dark theme.
  newTextArea(initialText = text, placeholder = "", fontSize = fontSize,
              color = color, fontFamily = fontFamily, bold = bold,
              italic = italic, underline = underline, align = align,
              wrap = wrap, markup = markup, editable = false,
              multiline = true, framed = false, padding = 0.0)

proc newTextInput*(initialText = "", placeholder = "Type here...",
                   fontSize: float32 = ThemeFontSize, maxLength = -1,
                   padding: float32 = ThemePadding, disabled = false,
                   intent = ThemeIntent.Default,
                   onChange: proc(newText: string) = nil,
                   onSubmit: proc(text: string) = nil): TextInput =
  ## One line of editable text.
  newTextArea(initialText = initialText, placeholder = placeholder,
              fontSize = fontSize, maxLength = maxLength, padding = padding,
              disabled = disabled, intent = intent, multiline = false,
              maxLines = 1, onChange = onChange, onSubmit = onSubmit)

proc newPasswordInput*(initialText = "", placeholder = "Password",
                       fontSize: float32 = ThemeFontSize, maxLength = -1,
                       padding: float32 = ThemePadding, disabled = false,
                       intent = ThemeIntent.Default,
                       onChange: proc(newText: string) = nil,
                       onSubmit: proc(text: string) = nil): TextInput =
  ## One line of secret text: bullets on screen, nothing to the clipboard,
  ## nothing to scripts.
  newTextArea(initialText = initialText, placeholder = placeholder,
              fontSize = fontSize, maxLength = maxLength, padding = padding,
              disabled = disabled, intent = intent, multiline = false,
              maxLines = 1, secret = true, onChange = onChange, onSubmit = onSubmit)
