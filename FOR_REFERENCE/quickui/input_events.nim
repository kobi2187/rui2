type
  InputEvent = object
    case kind: InputKind
    of ieKey:
      key: KeyCode
      unicode: Rune
      modifiers: set[Modifier]  # Ctrl, Alt, Shift
    of ieMouse:
      button: MouseButton
      pos: Point
      clicks: int  # For double-clicks
    of ieWheel:
      delta: float32

  FocusManager = ref object
    current: Widget
    focusOrder: seq[Widget]

proc handleInput(widget: Widget, event: InputEvent): bool =
  # Returns true if event was handled
  if widget.focused and event.kind == ieKey:
    # Handle keyboard input
    result = widget.onKeyPress(event)

  # Propagate to children if not handled
  if not result:
    for child in widget.children:
      if child.handleInput(event):
        return true
