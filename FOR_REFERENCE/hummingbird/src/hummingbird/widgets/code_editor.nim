
# Code/Text editor
defineWidget CodeEditor:
  props:
    text*: string
    language*: string  # For syntax highlighting
    fontSize*: int
    showLineNumbers*: bool
    onTextChanged*: proc(text: string)

  render:
    # Line numbers
    if widget.showLineNumbers:
      let lineCount = widget.text.countLines()
      let gutterWidth = ($lineCount).len * widget.fontSize.float32

      for i in 1..lineCount:
        GuiLabel(
          Rectangle(
            x: widget.rect.x,
            y: widget.rect.y + (i-1).float32 * widget.fontSize,
            width: gutterWidth,
            height: widget.fontSize.float32
          ),
          $i
        )

    # Text area
    var text = widget.text
    if GuiTextBox(
      widget.getTextRect(),
      text,
      int.high,
      true
    ):
      widget.text = text
      if widget.onTextChanged != nil:
        widget.onTextChanged(text)

