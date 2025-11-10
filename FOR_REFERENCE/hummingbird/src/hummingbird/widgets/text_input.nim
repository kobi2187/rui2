
# Text input field
defineWidget TextInput:
  props:
    text: string
    placeholder: string
    maxLength: int
    multiline: bool
    password: bool
    onTextChanged: proc(text: string)
    onSubmit: proc(text: string)
    selectionStart: int
    selectionEnd: int

  render:
    var text = widget.text
    if widget.password:
      if GuiPasswordBox(
        widget.toRaylibRect(),
        text.cstring,
        widget.maxLength,
        widget.focused
      ):
        if widget.onTextChanged != nil:
          widget.onTextChanged(text)
    else:
      if GuiTextBox(
        widget.toRaylibRect(),
        text.cstring,
        widget.maxLength,
        widget.focused
      ):
        if widget.onTextChanged != nil:
          widget.onTextChanged(text)

  input:
    if event.kind == ieKey and widget.focused:
      if event.key == KeyEnter and not widget.multiline:
        if widget.onSubmit != nil:
          widget.onSubmit(widget.text)
        true
      else:
        false
    else:
      false
