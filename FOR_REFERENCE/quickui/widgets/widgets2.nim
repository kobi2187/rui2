# widgets/core.nim
type
  Widget* = ref object of RootObj
    id*: string
    rect*: Rect
    visible*: bool
    enabled*: bool
    parent*: Widget
    children*: seq[Widget]
    focused*: bool
    style*: Option[Style]

  WidgetKind* = enum
    wkButton, wkLabel, wkTextInput, wkCheckbox, 
    wkRadio, wkSlider, wkProgress

# widgets/button.nim
type
  Button* = ref object of Widget
    text*: string
    onClick*: proc()
    isPressed*: bool
    icon*: Option[Icon]

proc newButton*(text: string, onClick: proc()): Button =
  Button(
    text: text,
    onClick: onClick,
    enabled: true,
    visible: true
  )

method draw*(button: Button) =
  if not button.visible: return
  
  let rect = Rectangle(
    x: button.rect.x,
    y: button.rect.y,
    width: button.rect.width,
    height: button.rect.height
  )
  
  if GuiButton(rect, button.text):
    if button.enabled and button.onClick != nil:
      button.onClick()

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

# widgets/checkbox.nim
type
  Checkbox* = ref object of Widget
    text*: string
    checked*: bool
    onToggle*: proc(checked: bool)

method draw*(cb: Checkbox) =
  var checked = cb.checked
  if GuiCheckBox(
    Rectangle(
      x: cb.rect.x,
      y: cb.rect.y,
      width: 20,
      height: 20
    ),
    cb.text,
    addr checked
  ):
    cb.checked = checked
    if cb.onToggle != nil:
      cb.onToggle(checked)

# widgets/slider.nim
type
  Slider* = ref object of Widget
    value*: float32
    minValue*: float32
    maxValue*: float32
    onChange*: proc(newValue: float32)

method draw*(slider: Slider) =
  var value = slider.value
  if GuiSlider(
    Rectangle(
      x: slider.rect.x,
      y: slider.rect.y,
      width: slider.rect.width,
      height: slider.rect.height
    ),
    "",
    $value,
    addr value,
    slider.minValue,
    slider.maxValue
  ):
    slider.value = value
    if slider.onChange != nil:
      slider.onChange(value)

# widgets/progress.nim
type
  ProgressBar* = ref object of Widget
    value*: float32
    maxValue*: float32
    showText*: bool

method draw*(pb: ProgressBar) =
  GuiProgressBar(
    Rectangle(
      x: pb.rect.x,
      y: pb.rect.y,
      width: pb.rect.width,
      height: pb.rect.height
    ),
    "",
    $pb.value,
    0,
    pb.maxValue
  )

# Example usage:
let form = container:
  vstack:
    TextInput(
      placeholder: "Enter name",
      onTextChanged: proc(text: string) =
        echo "Text changed: ", text
    )
    
    Checkbox(
      text: "Agree to terms",
      onToggle: proc(checked: bool) =
        echo "Checkbox: ", checked
    )
    
    Slider(
      minValue: 0,
      maxValue: 100,
      onChange: proc(value: float32) =
        echo "Slider: ", value
    )
    
    ProgressBar(
      value: 75,
      maxValue: 100,
      showText: true
    )
    
    hstack:
      Button(
        text: "Save",
        onClick: proc() =
          echo "Save clicked"
      )
      
      Button(
        text: "Cancel",
        onClick: proc() =
          echo "Cancel clicked"
      )