## TextArea — multi-line text editing
##
## The third of the three text widgets, and the one that did not exist. It is
## TextInput's editing model over text_content's engine, with the two things
## that make multi-line different:
##
## - Enter inserts a newline instead of submitting. There is no onSubmit,
##   because there is no key left to mean it -- Ctrl+Enter is the usual answer
##   and is left to the application, which knows whether this box is a form
##   field or a document.
## - The caret has a line as well as a column, so Up and Down move by line
##   rather than being left for focus navigation.
##
## Caret geometry goes through Pango, like TextInput's. What it does *not* do
## yet: horizontal scrolling, and a caret that remembers its column across
## short lines. Both are noted where they bite.

import rui_core
import text_buffer
export text_buffer
import ../text_content
import rui_drawing
import std/[strutils, options]
# rui_core does not re-export KeyboardKey -- its Menu/Down/Up fields collide
# with the Menu widget and with rui_drawing's ArrowDirection.
from raylib import KeyboardKey, getTime, isKeyDown

const
  SelectionColor = Color(r: 100, g: 150, b: 255, a: 128)
  PlaceholderColor = Color(r: 128, g: 128, b: 128, a: 255)

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
  ## How far into its line a byte offset is.
  index - lineStarts(text)[lineOf(text, index)]

proc lineEnd*(text: string, line: int): int =
  ## Byte offset just past the last character of a line, not counting the
  ## newline itself.
  let starts = lineStarts(text)
  if line + 1 < starts.len:
    return starts[line + 1] - 1
  text.len

proc indexAtLineColumn*(text: string, line, column: int): int =
  ## The offset `column` characters into `line`, clamped to that line's end --
  ## so moving down from a long line onto a short one lands at the short line's
  ## end rather than overshooting into the line after it.
  ##
  ## TODO: a real editor remembers the column you came from and restores it on
  ## the next long line. This forgets, so down-down through a short line drifts
  ## left. Worth fixing when someone edits prose in it.
  let starts = lineStarts(text)
  let l = clamp(line, 0, starts.len - 1)
  min(starts[l] + column, lineEnd(text, l))

template contentOf*(widget: untyped): TextContent =
  ## This area's text as a TextContent. A template, not a proc: the TextArea
  ## type does not exist until the macro below has expanded.
  TextContent(
    text: widget.text,
    style: textStyle(widget.fontSize, currentTheme.getThemeProps(
      widget.intent, ThemeState.Normal).foregroundColor.get(BLACK)),
    align: TextAlign.Left,
    wrap: false,
    markup: false,
    wrapWidth: 0.0'f32)

template textRect*(widget: untyped): Rect =
  ## The area inside the chrome that text is drawn into.
  Rect(x: widget.bounds.x + widget.padding,
       y: widget.bounds.y + widget.padding,
       width: widget.bounds.width - widget.padding * 2,
       height: widget.bounds.height - widget.padding * 2)

template indexAt*(widget: untyped, pos: Point): int =
  ## Byte offset of the caret position under a click: which line the y falls on,
  ## then Pango for the column within it.
  block:
    let content = widget.contentOf
    let inner = widget.textRect
    let starts = lineStarts(widget.text)
    let row = clamp(int((pos.y - inner.y) / content.lineHeight),
                    0, starts.len - 1)
    let start = starts[row]
    let stop = lineEnd(widget.text, row)
    let hit = indexFromPosition(widget.text[start ..< stop],
                                content.style.pangoFont, pos.x - inner.x, 0.0)
    clamp(start + hit.index + hit.trailing, 0, widget.text.len)

template edit*(widget: untyped, body: untyped) =
  ## Run an editing operation against the widget's state as a TextBuffer, then
  ## write it back and raise whatever flags the result calls for. The same
  ## arrangement as TextInput's.
  block:
    var buf {.inject.} = initTextBuffer(widget.text, widget.cursorPos,
                                        widget.selectionStart,
                                        widget.selectionEnd)
    let before = buf.text
    body
    widget.text = buf.text
    widget.cursorPos = buf.cursor
    widget.selectionStart = buf.selStart
    widget.selectionEnd = buf.selEnd
    widget.isDirty = true
    if widget.text != before:
      widget.layoutDirty = true
      if widget.onChange != nil:
        widget.onChange(widget.text)

definePrimitive(TextArea):
  props:
    initialText: string = ""
    placeholder: string = "Type here..."
    fontSize: float32 = 14.0
    maxLength: int = -1          # -1 for unlimited
    padding: float32 = 8.0
    visibleLines: int = 5        # Height, in lines, when nothing else decides
    disabled: bool = false
    intent: ThemeIntent = Default

  state:
    text: string
    cursorPos: int               # Byte index into text
    selectionStart: int          # -1 when there is no selection
    selectionEnd: int
    dragging: bool

  actions:
    onChange(newText: string)

  init:
    widget.focusable = true
    widget.selectionStart = -1
    widget.selectionEnd = -1

  events:
    on_mouse_down:
      if widget.disabled:
        return false
      widget.edit: buf.placeCursor(widget.indexAt(event.mousePos))
      widget.dragging = true
      return true

    on_mouse_move:
      if not widget.dragging or widget.disabled:
        return false
      widget.edit: buf.dragTo(widget.indexAt(event.mousePos))
      return true

    on_mouse_up:
      if not widget.dragging:
        return false
      widget.dragging = false
      widget.edit: buf.endDrag()
      return true

    on_char:
      if widget.disabled or not widget.focused:
        return false
      if event.char < ' ' or event.char > '~':
        return false
      widget.edit: discard buf.insert($event.char, widget.maxLength)
      return true

    on_key_down:
      if widget.disabled or not widget.focused:
        return false
      let shiftDown = isKeyDown(LeftShift) or isKeyDown(RightShift)

      case event.key
      of Backspace:
        widget.edit: discard buf.backspace()
        return true

      of Delete:
        widget.edit: discard buf.deleteForward()
        return true

      of Enter, KpEnter:
        # A newline, not a submit: this is the difference from TextInput.
        widget.edit: discard buf.insert("\n", widget.maxLength)
        return true

      of Up, Down:
        let line = lineOf(widget.text, widget.cursorPos)
        let column = columnOf(widget.text, widget.cursorPos)
        let target = indexAtLineColumn(widget.text,
                                       if event.key == Up: line - 1 else: line + 1,
                                       column)
        widget.edit: buf.moveCursor(target, extend = shiftDown)
        return true

      of Left, Right, Home, End:
        let line = lineOf(widget.text, widget.cursorPos)
        let target = case event.key
                     of Left: widget.cursorPos - 1
                     of Right: widget.cursorPos + 1
                     of Home: lineStarts(widget.text)[line]
                     else: lineEnd(widget.text, line)
        widget.edit: buf.moveCursor(target, extend = shiftDown)
        return true

      else:
        return false

  layout:
    let content = widget.contentOf
    let lineH = content.lineHeight
    if widget.bounds.height <= 0:
      widget.bounds.height = lineH * float32(widget.visibleLines) +
                             widget.padding * 2
    if widget.bounds.width <= 0:
      widget.bounds.width = max(240.0'f32,
                                content.measure().width + widget.padding * 2)

  render:
    let state = if widget.disabled: Disabled
                elif widget.focused: Focused
                elif widget.hovered: Hovered
                else: Normal
    let props = currentTheme.getThemeProps(widget.intent, state)
    drawInteractiveBox(widget.bounds, props, focused = widget.focused)

    let showPlaceholder = widget.text.len == 0
    let inner = widget.textRect
    var content = widget.contentOf
    if showPlaceholder:
      content.text = widget.placeholder
      content.style.color = PlaceholderColor

    let lineH = content.lineHeight
    let starts = lineStarts(widget.text)

    # Selection paints under the glyphs, a line at a time -- drawTextSelection
    # measures a single run, so a span crossing a newline has to be split.
    if not showPlaceholder and widget.selectionStart >= 0 and
       widget.selectionStart != widget.selectionEnd:
      let lo = min(widget.selectionStart, widget.selectionEnd)
      let hi = max(widget.selectionStart, widget.selectionEnd)
      for i, start in starts:
        let stop = lineEnd(widget.text, i)
        if hi <= start or lo >= stop:
          continue
        let lineRect = Rect(x: inner.x, y: inner.y + float32(i) * lineH,
                            width: inner.width, height: lineH)
        drawTextSelection(lineRect, max(lo, start) - start, min(hi, stop) - start,
                          widget.text[start ..< stop], content.style,
                          SelectionColor)

    if showPlaceholder:
      content.paint(inner)
    else:
      for i, start in starts:
        let stop = lineEnd(widget.text, i)
        var line = content
        line.text = widget.text[start ..< stop]
        line.paint(Rect(x: inner.x, y: inner.y + float32(i) * lineH,
                        width: inner.width, height: lineH))

    if widget.focused and not widget.disabled:
      let line = lineOf(widget.text, widget.cursorPos)
      let start = starts[line]
      let stop = lineEnd(widget.text, line)
      let caret = cursorPosition(widget.text[start ..< stop],
                                 content.style.pangoFont,
                                 widget.cursorPos - start)
      if int(getTime() * 2.0) mod 2 == 0:
        let y = inner.y + float32(line) * lineH
        drawLine(inner.x + caret.x, y, inner.x + caret.x, y + lineH,
                 content.style.color)

    if widget.disabled:
      drawDisabledOverlay(widget.bounds)
