## TextInput Widget - Single-line text input field
##
## Features:
## - Single-line text editing
## - Cursor positioning (click to move cursor)
## - Keyboard input (typing, backspace, delete, arrows)
## - Selection (drag or Shift+arrows)
## - Theme support
## - on_change and on_submit events
##
## Uses Raylib text rendering for now, will integrate Pango later

import raylib
import std/math
import ../core/[types, widget_dsl]
import ../drawing_primitives/[theme_sys_core, drawing_primitives]

export types, widget_dsl, theme_sys_core
export raylib.KeyboardKey  # Re-export for macro context

# Callback types for TextInput
type
  TextChangeCallback* = proc(newText: string) {.closure.}
  TextSubmitCallback* = proc(text: string) {.closure.}

defineWidget(TextInput):
  props:
    text: string
    cursorPos: int          # Cursor position (byte index in UTF-8 string)
    selectionStart: int     # -1 if no selection
    selectionEnd: int       # -1 if no selection
    theme: Theme
    intent: ThemeIntent
    state: ThemeState
    placeholder: string
    onChange: TextChangeCallback
    onSubmit: TextSubmitCallback
    fontSize: float32
    maxLength: int          # -1 for unlimited

  init:
    widget.text = ""
    widget.cursorPos = 0
    widget.selectionStart = -1
    widget.selectionEnd = -1
    widget.intent = ThemeIntent.Default
    widget.state = ThemeState.Normal
    widget.placeholder = "Type here..."
    widget.fontSize = 14.0
    widget.maxLength = -1
    widget.onChange = nil
    widget.onSubmit = nil
    widget.bounds.width = 200
    widget.bounds.height = 36

  render:
    when defined(useGraphics):
      # Get themed properties
      let props = widget.theme.getThemeProps(widget.intent, widget.state)

      # Background
      let bgColor = if props.backgroundColor.isSome:
                      props.backgroundColor.get()
                    else:
                      makeColor(255, 255, 255)

      let cornerRad = if props.cornerRadius.isSome:
                       props.cornerRadius.get()
                     else:
                       4.0

      drawRoundedRect(widget.bounds, cornerRad, bgColor, true)

      # Border
      if props.borderColor.isSome and props.borderWidth.isSome:
        let borderColor = props.borderColor.get()
        drawRoundedRect(widget.bounds, cornerRad, borderColor, false)

      # Padding
      let padding = if props.padding.isSome:
                      props.padding.get()
                    else:
                      EdgeInsets(top: 8, right: 8, bottom: 8, left: 8)

      let textX = widget.bounds.x + padding.left
      let textY = widget.bounds.y + padding.top
      let textWidth = widget.bounds.width - padding.left - padding.right
      let textHeight = widget.bounds.height - padding.top - padding.bottom

      # Text color
      let fgColor = if props.foregroundColor.isSome:
                      props.foregroundColor.get()
                    else:
                      makeColor(0, 0, 0)

      # Draw text or placeholder
      let displayText = if widget.text.len > 0:
                          widget.text
                        else:
                          widget.placeholder

      let textColor = if widget.text.len > 0:
                        fgColor
                      else:
                        makeColor(128, 128, 128)  # Gray for placeholder

      let fs = int32(widget.fontSize)

      # TODO: Handle text scrolling if it's too long
      # For now, just draw what fits
      raylib.drawText(displayText,
                     int32(textX),
                     int32(textY + (textHeight - widget.fontSize) / 2.0),
                     fs,
                     textColor)

      # Draw cursor if focused
      if widget.focused and widget.text.len > 0:
        # Calculate cursor X position
        # For now, simple calculation - will need proper text metrics
        let textBeforeCursor = if widget.cursorPos > 0:
                                  widget.text[0..<widget.cursorPos]
                                else:
                                  ""
        let cursorX = textX + float32(measureText(textBeforeCursor, fs))
        let cursorY = textY

        # Blinking cursor (simple for now)
        let time = getTime()
        let blinkPhase = int(time * 2.0) mod 2  # Blink every 0.5 seconds
        if blinkPhase == 0:
          drawLine(int32(cursorX), int32(cursorY),
                  int32(cursorX), int32(cursorY + textHeight),
                  fgColor)

      # Draw selection if any
      if widget.selectionStart >= 0 and widget.selectionEnd >= 0 and widget.selectionStart != widget.selectionEnd:
        let selStart = min(widget.selectionStart, widget.selectionEnd)
        let selEnd = max(widget.selectionStart, widget.selectionEnd)

        let textBeforeSelection = if selStart > 0:
                                     widget.text[0..<selStart]
                                   else:
                                     ""
        let selectedText = widget.text[selStart..<selEnd]

        let selectionX = textX + float32(measureText(textBeforeSelection, fs))
        let selectionWidth = float32(measureText(selectedText, fs))

        # Draw selection background
        let selectionColor = makeColor(100, 150, 255, 128)  # Light blue, semi-transparent
        drawRectangle(int32(selectionX), int32(textY),
                     int32(selectionWidth), int32(textHeight),
                     selectionColor)

  input:
    # Handle keyboard input when focused
    when defined(useGraphics):
      if widget.focused:
        case event.kind
        of evChar:
          # Type character
          if event.char >= ' ' and event.char <= '~':  # Printable ASCII
            # Insert character at cursor position
            if widget.maxLength < 0 or widget.text.len < widget.maxLength:
              if widget.cursorPos == widget.text.len:
                widget.text.add(event.char)
              else:
                widget.text.insert($event.char, widget.cursorPos)
              widget.cursorPos += 1
              widget.isDirty = true
              widget.selectionStart = -1
              widget.selectionEnd = -1
              if widget.onChange != nil:
                widget.onChange(widget.text)
            return true

        of evKeyDown:
          # Handle special keys
          if event.key == Backspace:
            # Delete character before cursor
            if widget.cursorPos > 0:
              let before = if widget.cursorPos > 1: widget.text[0..<(widget.cursorPos-1)] else: ""
              let after = if widget.cursorPos < widget.text.len: widget.text[widget.cursorPos..^1] else: ""
              widget.text = before & after
              widget.cursorPos -= 1
              widget.isDirty = true
              if widget.onChange != nil:
                widget.onChange(widget.text)
            return true

          elif event.key == Delete:
            # Delete character after cursor
            if widget.cursorPos < widget.text.len:
              let before = if widget.cursorPos > 0: widget.text[0..<widget.cursorPos] else: ""
              let after = if widget.cursorPos < widget.text.len - 1: widget.text[(widget.cursorPos+1)..^1] else: ""
              widget.text = before & after
              widget.isDirty = true
              if widget.onChange != nil:
                widget.onChange(widget.text)
            return true

          elif event.key == Left:
            # Move cursor left
            if widget.cursorPos > 0:
              widget.cursorPos -= 1
              widget.selectionStart = -1
              widget.selectionEnd = -1
            return true

          elif event.key == Right:
            # Move cursor right
            if widget.cursorPos < widget.text.len:
              widget.cursorPos += 1
              widget.selectionStart = -1
              widget.selectionEnd = -1
            return true

          elif event.key == Home:
            # Move to start
            widget.cursorPos = 0
            widget.selectionStart = -1
            widget.selectionEnd = -1
            return true

          elif event.key == End:
            # Move to end
            widget.cursorPos = widget.text.len
            widget.selectionStart = -1
            widget.selectionEnd = -1
            return true

          elif event.key == Enter or event.key == KpEnter:
            # Trigger submit callback
            if widget.onSubmit != nil:
              widget.onSubmit(widget.text)
            return true

        else:
          discard

  on_click:
    # Calculate clicked position and move cursor
    # event.mousePos.x/y gives us the click position
    let clickX = event.mousePos.x - widget.bounds.x - 8.0  # 8px padding

    # Find closest cursor position
    # Simple approach: measure each character position
    var closestPos = 0
    var closestDist = abs(clickX)

    for i in 0..widget.text.len:
      let textBefore = if i > 0: widget.text[0..<i] else: ""
      let xPos = float32(measureText(textBefore, int32(widget.fontSize)))
      let dist = abs(clickX - xPos)

      if dist < closestDist:
        closestDist = dist
        closestPos = i

    widget.cursorPos = closestPos
    widget.selectionStart = -1
    widget.selectionEnd = -1
