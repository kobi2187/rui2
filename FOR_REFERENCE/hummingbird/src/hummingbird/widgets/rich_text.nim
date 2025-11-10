
# Rich text editor
defineWidget RichText:
  props:
    text: string
    selection: Option[TextRange]
    formats: Table[TextRange, TextFormat]
    onTextChange: proc(newText: string)
    onFormatChange: proc(range: TextRange, format: TextFormat)

  type
    TextRange* = object
      start*, finish*: int

    TextFormat* = object
      bold*, italic*, underline*: bool
      textColor*, backgroundColor*: Option[Color]
      fontSize*: Option[int]

  render:
    # Draw formatting toolbar
    drawToolbar()

    # Draw text content with formatting
    var y = widget.rect.y + 30
    for line in widget.text.splitLines:
      var x = widget.rect.x
      for ch in line:
        let format = getFormatAt(x, y)
        drawFormattedChar(ch, x, y, format)
        x += getCharWidth(ch, format)
      y += getLineHeight(format)