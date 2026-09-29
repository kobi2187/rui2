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
## the caret in view (`scrollX` / `scrollY`), clipped to the frame. Not yet:
## wheel scrolling and a scrollbar, and wrapping while editing (wrap and
## markup apply to display text only).

import rui_core
import text_buffer
export text_buffer
import ../text_content
export text_content
import rui_drawing
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

const
  SelectionColor = Color(r: 100, g: 150, b: 255, a: 128)
  PlaceholderColor = Color(r: 128, g: 128, b: 128, a: 255)
  ThemeColor* = Color(r: 0, g: 0, b: 0, a: 0)
    ## The default `color`: transparent means "the theme's foreground".

template inset(widget: untyped): float32 =
  ## Padding applies only inside a frame; a bare label hugs its text.
  (if widget.framed: widget.padding else: 0.0'f32)

template textRect*(widget: untyped): Rect =
  ## The area inside the chrome that text is drawn into.
  Rect(x: widget.bounds.x + widget.inset,
       y: widget.bounds.y + widget.inset,
       width: widget.bounds.width - widget.inset * 2,
       height: widget.bounds.height - widget.inset * 2)

template lineRect(widget: untyped, lineH: float32): Rect =
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
    style: textStyle(widget.fontSize, widget.textColor, widget.fontFamily,
                     widget.bold, widget.italic, widget.underline),
    align: widget.align,
    wrap: widget.wrap and not widget.editable,
    markup: widget.markup and not widget.editable,
    wrapWidth: widget.textRect.width)

template indexAt*(widget: untyped, pos: Point): int =
  ## Byte offset of the caret position under a click: which line the y falls on,
  ## then Pango for the column within it.
  block:
    let content = widget.contentOf
    let inner = widget.lineRect(content.lineHeight)
    let starts = lineStarts(widget.text)
    let row = clamp(int((pos.y - inner.y + widget.scrollY) / content.lineHeight),
                    0, starts.len - 1)
    let start = starts[row]
    let stop = lineEnd(widget.text, row)
    let hit = indexFromPosition(widget.text[start ..< stop],
                                content.style.pangoFont,
                                pos.x - inner.x + widget.scrollX, 0.0)
    clamp(start + hit.index + hit.trailing, 0, widget.text.len)

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

const MultiClickWindow = initDuration(milliseconds = 400)

template countClick(widget: untyped, at: MonoTime): int =
  ## 1, 2 or 3: a click, a double-click or a triple-click. A click within the
  ## window of the last one continues the run; anything slower starts over.
  block:
    if widget.clickCount > 0 and at - widget.lastClickAt <= MultiClickWindow:
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
      if b.hasSelection: setClipboardText(b.selectedText)
    of KeyboardKey.X:
      let b = widget.bufferOf
      if b.hasSelection:
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
      widget.edit: buf.moveCursor(prevWordStart(buf.text, buf.cursor),
                                  extend = event.shift)
    of Right:
      widget.edit: buf.moveCursor(nextWordEnd(buf.text, buf.cursor),
                                  extend = event.shift)
    of Home:
      widget.edit: buf.moveCursor(0, extend = event.shift)
    of End:
      widget.edit: buf.moveCursor(buf.text.len, extend = event.shift)
    of Backspace:
      widget.edit: discard buf.deleteWordBack()
    of Delete:
      widget.edit: discard buf.deleteWordForward()
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

proc caretPhaseRemaining*(now: float): float =
  ## Seconds until the caret next turns on or off. It blinks on half-second
  ## boundaries of the clock, so this is the time to the next one.
  (floor(now * 2.0) + 1.0) / 2.0 - now

proc roomForLine*(text: string, maxLines: int): bool =
  ## Whether Enter may add a line under a `maxLines` limit (-1: no limit).
  maxLines < 0 or lineStarts(text).len < maxLines

template keepCaretInView(widget: untyped, content: TextContent, inner: Rect) =
  ## Scroll so the caret is inside `inner`. Runs while painting, which is when
  ## the caret's pixel position is known; indexAt reads the result.
  block:
    let lineH = content.lineHeight
    let starts = lineStarts(widget.text)
    let line = lineOf(widget.text, widget.cursorPos)
    let lineText = widget.text[starts[line] ..< lineEnd(widget.text, line)]
    let caret = cursorPosition(lineText, content.style.pangoFont,
                               widget.cursorPos - starts[line])
    let lineW = measureText(lineText, content.style).width
    widget.scrollX = scrollToShow(widget.scrollX, caret.x, 1.0, inner.width,
                                  lineW + 1.0)
    widget.scrollY = if widget.multiline:
                       scrollToShow(widget.scrollY, float32(line) * lineH, lineH,
                                    inner.height, float32(starts.len) * lineH)
                     else: 0.0'f32

template paintEditable(widget: untyped, content: TextContent, inner: Rect) =
  ## Selection, text and caret for editable text, line by line, scrolled and
  ## clipped to `inner`.
  block:
    if widget.focused:
      widget.keepCaretInView(content, inner)
    let lineH = content.lineHeight
    let font = content.style.pangoFont
    let ox = inner.x - widget.scrollX
    let oy = inner.y - widget.scrollY
    let starts = lineStarts(widget.text)

    # Selection under the glyphs, one band per line. Both edges from Pango's
    # caret positions, so it lines up with the glyphs in any script.
    if widget.selectionStart >= 0 and widget.selectionStart != widget.selectionEnd:
      let lo = min(widget.selectionStart, widget.selectionEnd)
      let hi = max(widget.selectionStart, widget.selectionEnd)
      for i, start in starts:
        let stop = lineEnd(widget.text, i)
        if hi < start or lo > stop or (hi == start and lo < start):
          continue
        let lineText = widget.text[start ..< stop]
        let x0 = cursorPosition(lineText, font, max(lo, start) - start).x
        let x1 = cursorPosition(lineText, font, min(hi, stop) - start).x
        let band = intersect(Rect(x: ox + x0, y: oy + float32(i) * lineH,
                                  width: x1 - x0, height: lineH), inner)
        if band.width > 0 and band.height > 0:
          drawRect(band, SelectionColor)

    for i, start in starts:
      let y = oy + float32(i) * lineH
      if y + lineH < inner.y or y > inner.y + inner.height:
        continue
      drawTextPangoClipped(widget.text[start ..< lineEnd(widget.text, i)],
                           ox, y, font, content.style.color,
                           Rectangle(x: inner.x, y: inner.y,
                                     width: inner.width, height: inner.height))

    if widget.focused and widget.takesInput:
      let line = lineOf(widget.text, widget.cursorPos)
      let start = starts[line]
      let caret = cursorPosition(widget.text[start ..< lineEnd(widget.text, line)],
                                 font, widget.cursorPos - start)
      let now = getTime()
      let x = ox + caret.x
      let y = oy + float32(line) * lineH
      if int(now * 2.0) mod 2 == 0 and x >= inner.x and x <= inner.x + inner.width:
        drawLine(x, max(y, inner.y), x, min(y + lineH, inner.y + inner.height),
                 widget.textColor)
      # Nothing else repaints an idle field, so ask for the next blink phase --
      # without this the caret froze in whichever phase the last edit left it.
      widget.repaintAfter(caretPhaseRemaining(now))

definePrimitive(TextArea):
  props:
    initialText: string = ""
    placeholder: string = "Type here..."
    fontSize: float32 = 14.0
    color: Color = ThemeColor    ## Transparent: use the theme's foreground
    fontFamily: string = ""      ## "" resolves to the system Sans alias
    bold: bool = false
    italic: bool = false
    underline: bool = false
    align: TextAlign = TextAlign.Left
    wrap: bool = false           ## Display text wraps to the assigned width
    markup: bool = false         ## Display text is Pango markup
    editable: bool = true        ## false: display only, takes no input
    multiline: bool = true       ## false: one line, Enter fires onSubmit
    maxLength: int = -1          ## Characters; -1 for unlimited
    maxLines: int = -1           ## Lines Enter may create; -1 for unlimited
    framed: bool = true          ## Draw the input box, and pad inside it
    padding: float32 = 8.0
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

  actions:
    onChange(newText: string)
    onSubmit(text: string)

  typeName:
    if not widget.editable: "Label"
    elif not widget.multiline: "TextInput"
    else: "TextArea"

  init:
    widget.focusable = widget.editable
    widget.selectionStart = -1
    widget.selectionEnd = -1
    widget.goalColumn = -1

  events:
    on_mouse_down:
      if not widget.takesInput:
        return false
      let at = widget.indexAt(event.mousePos)
      case widget.countClick(event.timestamp)
      of 2:
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
      if not widget.dragging or not widget.takesInput:
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
        let move = verticalMove(widget.text, widget.cursorPos,
                                widget.goalColumn, down = event.key == Down)
        widget.edit: buf.moveCursor(move.index, extend = shiftDown)
        widget.goalColumn = move.goalColumn
        return true

      of Left, Right, Home, End:
        let line = lineOf(widget.text, widget.cursorPos)
        let target = case event.key
                     of Left: prevBoundary(widget.text, widget.cursorPos)
                     of Right: nextBoundary(widget.text, widget.cursorPos)
                     of Home: lineStarts(widget.text)[line]
                     else: lineEnd(widget.text, line)
        widget.edit: buf.moveCursor(target, extend = shiftDown)
        return true

      else:
        return false

  layout:
    widget.cursorShape = if widget.takesInput: csText else: csDefault
    let content = widget.contentOf
    let pad = widget.inset * 2
    if not widget.editable:
      # Display text sizes to its content, unless the parent assigned a width.
      # A width it gave itself last time reads as 0 here (beginSelfSizing),
      # so changed text is re-measured.
      if widget.bounds.width <= 0:
        widget.bounds.width = content.measure().width + pad
      # Measured after the width is settled, so wrapped text gets its height.
      widget.bounds.height = widget.contentOf.measure().height + pad
    else:
      let lines = if widget.multiline: max(1, widget.visibleLines) else: 1
      if widget.bounds.height <= 0:
        widget.bounds.height = content.lineHeight * float32(lines) + pad
      if widget.bounds.width <= 0:
        let floor = if widget.multiline: 240.0'f32 else: 200.0'f32
        widget.bounds.width = max(floor, content.measure().width + pad)

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

proc newLabel*(text = "", fontSize: float32 = 14.0, color: Color = ThemeColor,
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
                   fontSize: float32 = 14.0, maxLength = -1,
                   padding: float32 = 8.0, disabled = false,
                   intent = ThemeIntent.Default,
                   onChange: proc(newText: string) = nil,
                   onSubmit: proc(text: string) = nil): TextInput =
  ## One line of editable text.
  newTextArea(initialText = initialText, placeholder = placeholder,
              fontSize = fontSize, maxLength = maxLength, padding = padding,
              disabled = disabled, intent = intent, multiline = false,
              maxLines = 1, onChange = onChange, onSubmit = onSubmit)
