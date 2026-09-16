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
import rui_drawing
import std/options

import raylib

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
      let style = TextStyle(fontFamily: "", fontSize: widget.fontSize, color: BLACK,
                            bold: false, italic: false, underline: false)
      let hit = indexFromPosition(widget.text, style.pangoFont,
                                  event.mousePos.x - widget.bounds.x - widget.padding,
                                  0.0)
      widget.cursorPos = clamp(hit.index + hit.trailing, 0, widget.text.len)
      widget.selectionStart = widget.cursorPos
      widget.selectionEnd = widget.cursorPos
      widget.dragging = true
      widget.isDirty = true
      return true

    on_mouse_move:
      if not widget.dragging or widget.disabled:
        return false
      let style = TextStyle(fontFamily: "", fontSize: widget.fontSize, color: BLACK,
                            bold: false, italic: false, underline: false)
      let hit = indexFromPosition(widget.text, style.pangoFont,
                                  event.mousePos.x - widget.bounds.x - widget.padding,
                                  0.0)
      widget.cursorPos = clamp(hit.index + hit.trailing, 0, widget.text.len)
      widget.selectionEnd = widget.cursorPos
      widget.isDirty = true
      return true

    on_mouse_up:
      if not widget.dragging:
        return false
      widget.dragging = false
      # A click without a drag leaves no selection behind.
      if widget.selectionStart == widget.selectionEnd:
        widget.selectionStart = -1
        widget.selectionEnd = -1
      return true

    on_char:
      if widget.disabled or not widget.focused:
        return false
      if event.char < ' ' or event.char > '~':
        return false
      if widget.maxLength >= 0 and widget.text.len >= widget.maxLength:
        return true

      # Typing over a selection replaces it.
      if widget.selectionStart >= 0 and widget.selectionStart != widget.selectionEnd:
        let a = min(widget.selectionStart, widget.selectionEnd)
        let b = max(widget.selectionStart, widget.selectionEnd)
        widget.text = widget.text[0..<a] & widget.text[b..^1]
        widget.cursorPos = a
        widget.selectionStart = -1
        widget.selectionEnd = -1

      widget.text.insert($event.char, widget.cursorPos)
      widget.cursorPos += 1
      widget.isDirty = true
      widget.layoutDirty = true
      if widget.onChange.isSome:
        widget.onChange.get()(widget.text)
      return true

    on_key_down:
      if widget.disabled or not widget.focused:
        return false
      let shiftDown = isKeyDown(LeftShift) or isKeyDown(RightShift)

      case event.key
      of Backspace:
        if widget.selectionStart >= 0 and widget.selectionStart != widget.selectionEnd:
          let a = min(widget.selectionStart, widget.selectionEnd)
          let b = max(widget.selectionStart, widget.selectionEnd)
          widget.text = widget.text[0..<a] & widget.text[b..^1]
          widget.cursorPos = a
          widget.selectionStart = -1
          widget.selectionEnd = -1
        elif widget.cursorPos > 0:
          widget.text = widget.text[0..<(widget.cursorPos - 1)] &
                        widget.text[widget.cursorPos..^1]
          widget.cursorPos -= 1
        else:
          return true
        widget.isDirty = true
        widget.layoutDirty = true
        if widget.onChange.isSome:
          widget.onChange.get()(widget.text)
        return true

      of Delete:
        if widget.cursorPos < widget.text.len:
          widget.text = widget.text[0..<widget.cursorPos] &
                        widget.text[(widget.cursorPos + 1)..^1]
          widget.isDirty = true
          widget.layoutDirty = true
          if widget.onChange.isSome:
            widget.onChange.get()(widget.text)
        return true

      of Left, Right, Home, End:
        let anchor = if widget.selectionStart >= 0: widget.selectionStart
                     else: widget.cursorPos
        case event.key
        of Left:  widget.cursorPos = max(0, widget.cursorPos - 1)
        of Right: widget.cursorPos = min(widget.text.len, widget.cursorPos + 1)
        of Home:  widget.cursorPos = 0
        else:     widget.cursorPos = widget.text.len

        if shiftDown:
          widget.selectionStart = anchor
          widget.selectionEnd = widget.cursorPos
        else:
          widget.selectionStart = -1
          widget.selectionEnd = -1
        widget.isDirty = true
        return true

      of Enter, KpEnter:
        if widget.onSubmit.isSome:
          widget.onSubmit.get()(widget.text)
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
