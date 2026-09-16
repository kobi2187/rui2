## TextInput Widget - Single-line text input field
##
## Features:
## - Single-line text editing with a real caret
## - Click to place the caret, drag to select
## - Keyboard input: typing, backspace, delete, arrows, home/end
## - Shift+arrows extend the selection
## - onChange / onSubmit actions
##
## Caret geometry and click-to-caret go through Pango (`cursorPosition` and
## `indexFromPosition`). The pre-merge version measured every prefix of the
## string in a loop to find the nearest character, against raylib's 10px bitmap
## font -- O(n) measurements per click, and wrong for any real font.
##
## Note: the old file declared `input:` and `on_click:` sections. The DSL never
## parsed either name, so none of its editing logic was ever reachable. They are
## `events:` handlers now.

import rui_core
import text_buffer
export text_buffer
import ../text_content
export text_content
import rui_drawing
import std/options

import raylib

template contentOf*(widget: untyped): TextContent =
  ## This input's text as a TextContent, so measuring and drawing go through the
  ## same engine Label and TextArea use. A template, not a proc: the TextInput
  ## type does not exist until the macro below has expanded.
  TextContent(
    text: widget.text,
    style: textStyle(widget.fontSize, BLACK),
    align: TextAlign.Left, wrap: false, markup: false, wrapWidth: 0.0'f32)

template indexAt*(widget: untyped, screenX: float32): int =
  ## Byte offset of the caret position under a click, via Pango.
  block:
    let hit = indexFromPosition(widget.text, widget.contentOf.style.pangoFont,
                                screenX - widget.bounds.x - widget.padding, 0.0)
    clamp(hit.index + hit.trailing, 0, widget.text.len)

template edit*(widget: untyped, body: untyped) =
  ## Run an editing operation against the widget's state as a TextBuffer, then
  ## write it back and raise whatever flags the result calls for.
  ##
  ## Templates rather than procs, as everywhere else in the DSL widgets: the
  ## TextInput type does not exist until the macro below has expanded.
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
      # Only a change of text needs a re-measure or an onChange; moving the
      # caret repaints and nothing more.
      widget.layoutDirty = true
      if widget.onChange != nil:
        widget.onChange(widget.text)

definePrimitive(TextInput):
  props:
    initialText: string = ""
    placeholder: string = "Type here..."
    fontSize: float32 = 14.0
    maxLength: int = -1          # -1 for unlimited
    padding: float32 = 8.0
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
    onSubmit(text: string)

  init:
    widget.focusable = true

  events:
    on_mouse_down:
      if widget.disabled:
        return false
      widget.edit: buf.placeCursor(widget.indexAt(event.mousePos.x))
      widget.dragging = true
      return true

    on_mouse_move:
      if not widget.dragging or widget.disabled:
        return false
      widget.edit: buf.dragTo(widget.indexAt(event.mousePos.x))
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
      # Printable ASCII only for now: `char` is one byte, so anything above
      # this would be half a codepoint. TextBuffer indexes in bytes and is
      # ready for more; the event type is what is not.
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

      of Left, Right, Home, End:
        let target = case event.key
                     of Left: widget.cursorPos - 1
                     of Right: widget.cursorPos + 1
                     of Home: 0
                     else: widget.text.len
        widget.edit: buf.moveCursor(target, extend = shiftDown)
        return true

      of Enter, KpEnter:
        if widget.onSubmit != nil:
          widget.onSubmit(widget.text)
        return true

      else:
        return false

  layout:
    let style = TextStyle(fontFamily: "", fontSize: widget.fontSize, color: BLACK,
                          bold: false, italic: false, underline: false)
    let m = measureText(if widget.text.len > 0: widget.text else: widget.placeholder,
                        style)
    if widget.bounds.height <= 0:
      widget.bounds.height = m.height + widget.padding * 2
    if widget.bounds.width <= 0:
      widget.bounds.width = max(200.0'f32, m.width + widget.padding * 2)

  render:
    let state = if widget.disabled: Disabled
                elif widget.focused: Focused
                elif widget.hovered: Hovered
                else: Normal
    let props = currentTheme.getThemeProps(widget.intent, state)

    drawInteractiveBox(widget.bounds, props, focused = widget.focused)

    let fgColor = props.foregroundColor.get(Color(r: 0, g: 0, b: 0, a: 255))
    let showPlaceholder = widget.text.len == 0
    var style = TextStyle(fontFamily: "", fontSize: widget.fontSize,
                          color: if showPlaceholder: Color(r: 128, g: 128, b: 128, a: 255)
                                 else: fgColor,
                          bold: false, italic: false, underline: false)

    let textX = widget.bounds.x + widget.padding
    let textY = widget.bounds.y + (widget.bounds.height - widget.fontSize) / 2
    let textRect = Rect(x: textX, y: textY,
                        width: widget.bounds.width - widget.padding * 2,
                        height: widget.fontSize)

    # Selection paints under the glyphs.
    if not showPlaceholder and widget.selectionStart >= 0 and
       widget.selectionStart != widget.selectionEnd:
      drawTextSelection(textRect,
                        min(widget.selectionStart, widget.selectionEnd),
                        max(widget.selectionStart, widget.selectionEnd),
                        widget.text, style,
                        Color(r: 100, g: 150, b: 255, a: 128))

    drawText(if showPlaceholder: widget.placeholder else: widget.text,
             textX, textY, widget.fontSize, style.color)

    if widget.focused and not widget.disabled:
      # Pango knows exactly where the caret goes, including past the last glyph.
      let caret = cursorPosition(widget.text, style.pangoFont, widget.cursorPos)
      let blinkOn = int(getTime() * 2.0) mod 2 == 0
      if blinkOn:
        let caretHeight = if caret.height > 0: caret.height else: widget.fontSize
        drawLine(textX + caret.x, textY,
                 textX + caret.x, textY + caretHeight,
                 fgColor)

    if widget.disabled:
      drawDisabledOverlay(widget.bounds)
