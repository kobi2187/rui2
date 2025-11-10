
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
