type
  TextArea* = ref object of Widget
    text: string
    layout: PangoLayout
    selection: TextSelection
    cursor: TextCursor
    editable: bool
    multiLine: bool
    style: TextStyle  # fonts, colors etc

  TextSelection = object
    anchor, active: int
    
  TextCursor = object
    position: int
    visible: bool
    blinkTime: float32

# High level API for widget authors
proc newTextArea*(text = ""): TextArea =
  result = TextArea()
  result.layout = pango.layout_new()
  result.setText(text)
  result.editable = true
  result.multiLine = true

# Usage in other widgets:
proc newTextInput*(): TextInput =
  result = TextInput()
  result.textArea = newTextArea()
  result.textArea.multiLine = false
  result.textArea.style = inputStyle

proc newTextLabel*(): Label =
  result = Label()
  result.textArea = newTextArea()
  result.textArea.editable = false

# Core text operations
proc setText*(area: TextArea, text: string) =
  area.text = text
  pango.layout_set_text(area.layout, text)

proc getSelectedText*(area: TextArea): string =
  let (start, finish) = area.selection.getSortedRange()
  area.text[start ..< finish]

proc insertText*(area: TextArea, text: string) =
  if area.hasSelection:
    area.deleteSelection()
  let pos = area.cursor.position
  area.text.insert(text, pos)
  area.cursor.position += text.len
  area.updateLayout()

# Input handling
method handleInput*(area: TextArea, event: InputEvent) =
  if not area.editable: return

  case event.kind
  of Mouse:
    let pos = area.hitTest(event.mousePos)
    if event.click == Single:
      area.cursor.position = pos
      area.selection.clear()
    elif event.click == Double:
      area.selectWordAt(pos)
  
  of Key:
    case event.key
    of Left:
      if event.shift:
        area.extendSelection(-1)
      else:
        area.moveCursor(-1)
    of Delete:
      if area.hasSelection:
        area.deleteSelection()
      else:
        area.deleteAt(area.cursor.position)
  
  of Text:
    area.insertText(event.text)

# Drawing
method draw*(area: TextArea) =
  # Draw background
  if area.hasSelection:
    area.drawSelection()
  
  # Draw text via Pango
  area.layout.render()
  
  # Draw cursor if editable
  if area.editable and area.cursor.visible:
    area.drawCursor()