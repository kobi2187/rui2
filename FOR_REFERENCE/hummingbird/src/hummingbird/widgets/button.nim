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