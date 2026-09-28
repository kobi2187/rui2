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
## through a short line does not drag the caret left. Not yet: horizontal or
## vertical scrolling, and wrapping while editing (wrap and markup apply to
## display text only).

import rui_core
import text_buffer
export text_buffer
import ../text_content
export text_content
import rui_drawing
import std/[strutils, options]
from std/unicode import `$`, runeLen
# rui_core does not re-export KeyboardKey -- its Menu/Down/Up fields collide
# with the Menu widget and with rui_drawing's ArrowDirection.
from raylib import KeyboardKey, getTime, isKeyDown

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
    let row = clamp(int((pos.y - inner.y) / content.lineHeight),
                    0, starts.len - 1)
    let start = starts[row]
    let stop = lineEnd(widget.text, row)
    let hit = indexFromPosition(widget.text[start ..< stop],
                                content.style.pangoFont, pos.x - inner.x, 0.0)
    clamp(start + hit.index + hit.trailing, 0, widget.text.len)

template edit*(widget: untyped, body: untyped) =
  ## Run an editing operation against the widget's state as a TextBuffer, then
  ## write it back and raise whatever flags the result calls for.
  block:
    var buf {.inject.} = initTextBuffer(widget.text, widget.cursorPos,
                                        widget.selectionStart,
                                        widget.selectionEnd)
    let before = buf.text
    # Any edit or cursor move ends a run of Up/Down presses; the Up/Down
    # handler restores the goal column after its own edit.
    widget.goalColumn = -1
    body
    widget.text = buf.text
    widget.cursorPos = buf.cursor
    widget.selectionStart = buf.selStart
    widget.selectionEnd = buf.selEnd
    widget.isDirty = true
    if widget.text != before:
      # Only a change of text needs a re-measure or an onChange; moving the
      # caret repaints and nothing more.
      widget.layoutDirty = true
      if widget.onChange != nil:
        widget.onChange(widget.text)

template takesInput(widget: untyped): bool =
  widget.editable and not widget.disabled

proc roomForLine*(text: string, maxLines: int): bool =
  ## Whether Enter may add a line under a `maxLines` limit (-1: no limit).
  maxLines < 0 or lineStarts(text).len < maxLines

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
    selfWidth: float32           # The width this widget last measured for itself

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
      widget.edit: buf.placeCursor(widget.indexAt(event.mousePos))
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
      let shiftDown = isKeyDown(LeftShift) or isKeyDown(RightShift)

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
    let content = widget.contentOf
    let pad = widget.inset * 2
    if not widget.editable:
      # Display text sizes to its content. Keep a width the *parent* assigned,
      # but re-measure one this widget set for itself -- otherwise it could
      # never grow again once it had a non-zero width.
      let parentAssigned = widget.bounds.width > 0 and
                           widget.bounds.width != widget.selfWidth
      if not parentAssigned:
        widget.bounds.width = content.measure().width + pad
        widget.selfWidth = widget.bounds.width
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
    else:
      let lineH = content.lineHeight
      let starts = lineStarts(widget.text)

      # Selection paints under the glyphs, a line at a time --
      # drawTextSelection measures a single run, so a span crossing a newline
      # has to be split.
      if widget.selectionStart >= 0 and
         widget.selectionStart != widget.selectionEnd:
        let lo = min(widget.selectionStart, widget.selectionEnd)
        let hi = max(widget.selectionStart, widget.selectionEnd)
        for i, start in starts:
          let stop = lineEnd(widget.text, i)
          if hi <= start or lo >= stop:
            continue
          let lineRect = Rect(x: inner.x, y: inner.y + float32(i) * lineH,
                              width: inner.width, height: lineH)
          drawTextSelection(lineRect, max(lo, start) - start,
                            min(hi, stop) - start,
                            widget.text[start ..< stop], content.style,
                            SelectionColor)

      for i, start in starts:
        var line = content
        line.text = widget.text[start ..< lineEnd(widget.text, i)]
        line.paint(Rect(x: inner.x, y: inner.y + float32(i) * lineH,
                        width: inner.width, height: lineH))

    if widget.focused and widget.takesInput:
      let lineH = content.lineHeight
      let line = lineOf(widget.text, widget.cursorPos)
      let start = lineStarts(widget.text)[line]
      let stop = lineEnd(widget.text, line)
      let caret = cursorPosition(widget.text[start ..< stop],
                                 content.style.pangoFont,
                                 widget.cursorPos - start)
      if int(getTime() * 2.0) mod 2 == 0:
        let y = inner.y + float32(line) * lineH
        drawLine(inner.x + caret.x, y, inner.x + caret.x, y + lineH,
                 widget.textColor)

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

proc newLabel*(text = "", fontSize: float32 = 14.0, color: Color = BLACK,
               fontFamily = "", bold = false, italic = false, underline = false,
               align = TextAlign.Left, wrap = false, markup = false): Label =
  ## Display text. Black unless told otherwise, as Label always was; pass
  ## `color = ThemeColor` to follow the theme instead.
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
