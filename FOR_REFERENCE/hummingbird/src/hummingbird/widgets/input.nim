
# widgets/input.nim
type
  TextInput* = ref object of Widget
    text*: string
    placeholder*: string
    maxLength*: int
    multiline*: bool
    onTextChanged*: proc(newText: string)
    onSubmit*: proc(text: string)
    selectionStart*: int
    selectionEnd*: int

method draw*(input: TextInput) =
  if not input.visible: return
  
  var text = input.text
  if GuiTextBox(
    Rectangle(
      x: input.rect.x,
      y: input.rect.y,
      width: input.rect.width,
      height: input.rect.height
    ),
    text.cstring,
    input.maxLength,
    input.focused
  ):
    let newText = $text
    if newText != input.text:
      input.text = newText
      if input.onTextChanged != nil:
        input.onTextChanged(newText)

method handleKeyPress*(input: TextInput, key: int, mods: set[KeyModifier]) =
  if key == KeyEnter and not input.multiline:
    if input.onSubmit != nil:
      input.onSubmit(input.text)
