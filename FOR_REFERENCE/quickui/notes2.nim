# Current (directly using raygui):
if GuiButton(Rectangle(x: widget.x, y: widget.y, width: widget.width, height: widget.height),
             widget.text):
  widget.onClick()

# Better approach:
type Button = ref object of Widget
  text: string
  onClick: proc()

method render(button: Button) =
  let rect = Rectangle(
    x: button.x,
    y: button.y,
    width: button.width,
    height: button.height
  )
  if button.enabled and naylib.button(rect, button.text):  # wrapper around GuiButton
    button.onClick()
