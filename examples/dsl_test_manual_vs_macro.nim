## DSL Test: Manual vs Macro Comparison
##
## Shows what the definePrimitive macro should generate
## by comparing manual widget creation with macro usage

import ../core/[types, link]

# ============================================================================
# Example 1: Simple Label (Manual Implementation)
# ============================================================================

type
  LabelManual* = ref object of Widget
    # Props
    text*: string
    fontSize*: float

    # State (none for Label)

    # Actions (none for Label)

proc newLabelManual*(text: string, fontSize: float = 14.0): LabelManual =
  result = LabelManual()
  result.id = WidgetId(1)  # Should be newWidgetId()
  result.visible = true
  result.enabled = true
  result.hovered = false
  result.pressed = false
  result.focused = false
  result.isDirty = true
  result.layoutDirty = true
  result.zIndex = 0
  result.children = @[]
  result.parent = nil
  result.bounds = Rect(x: 0, y: 0, width: 100, height: 30)
  result.previousBounds = result.bounds

  # Set props
  result.text = text
  result.fontSize = fontSize

method render*(widget: LabelManual) =
  if not widget.visible: return

  # Render code would go here
  # let theme = getTheme()
  # drawText(widget.text, widget.bounds, theme.foreground, widget.fontSize)
  echo "Rendering Label: ", widget.text

  # Render children (none expected for Label)
  for child in widget.children:
    child.render()

# ============================================================================
# Example 1: Simple Label (Macro Usage - Target)
# ============================================================================

when false:
  # This is what we WANT to write:
  definePrimitive(Label):
    props:
      text: string
      fontSize: float = 14.0

    render:
      echo "Rendering Label: ", widget.text
      # let theme = getTheme()
      # drawText(widget.text, widget.bounds, theme.foreground, widget.fontSize)

  # Should generate the same code as LabelManual above

# ============================================================================
# Example 2: Button with State and Actions (Manual)
# ============================================================================

type
  ButtonManual* = ref object of Widget
    # Props
    text*: string
    disabled*: bool

    # State
    pressed: Link[bool]
    hovered: Link[bool]

    # Actions
    onClick*: Option[proc()]

proc newButtonManual*(
  text: string,
  disabled: bool = false,
  onClick: proc() = nil
): ButtonManual =
  result = ButtonManual()
  result.id = WidgetId(2)
  result.visible = true
  result.enabled = true
  result.hovered = false
  result.pressed = false
  result.focused = false
  result.isDirty = true
  result.layoutDirty = true
  result.zIndex = 0
  result.children = @[]
  result.parent = nil
  result.bounds = Rect(x: 0, y: 0, width: 100, height: 30)
  result.previousBounds = result.bounds

  # Set props
  result.text = text
  result.disabled = disabled

  # Initialize state
  result.pressed = newLink(false)
  result.hovered = newLink(false)

  # Set actions
  result.onClick = if onClick != nil: some(onClick) else: none(proc())

method render*(widget: ButtonManual) =
  if not widget.visible: return

  let pressed = widget.pressed.get()
  let hovered = widget.hovered.get()

  echo "Rendering Button: ", widget.text,
       " (pressed=", pressed,
       ", hovered=", hovered,
       ", disabled=", widget.disabled, ")"

  # let theme = getTheme()
  # let bgColor = if widget.disabled: theme.disabled
  #               elif pressed: theme.primaryDark
  #               elif hovered: theme.primaryLight
  #               else: theme.primary
  # drawRoundedRect(widget.bounds, 4.0, bgColor)
  # drawText(widget.text, widget.bounds, theme.onPrimary)

  for child in widget.children:
    child.render()

method handleInput*(widget: ButtonManual, event: GuiEvent): bool =
  if not widget.visible or not widget.enabled:
    return false

  # Event handlers
  case event.kind:
  of evMouseDown:
    if not widget.disabled:
      widget.pressed.set(true)
      return true

  of evMouseUp:
    if widget.pressed.get() and not widget.disabled:
      widget.pressed.set(false)
      if widget.onClick.isSome:
        widget.onClick.get()()
      return true

  of evMouseMove:
    # Check if mouse is over widget
    let mouseX = event.mousePos.x
    let mouseY = event.mousePos.y
    let isOver = mouseX >= widget.bounds.x and
                 mouseX <= widget.bounds.x + widget.bounds.width and
                 mouseY >= widget.bounds.y and
                 mouseY <= widget.bounds.y + widget.bounds.height

    widget.hovered.set(isOver)

  else:
    discard

  # Propagate to children
  for i in countdown(widget.children.high, 0):
    if widget.children[i].handleInput(event):
      return true

  return false

# ============================================================================
# Example 2: Button with State and Actions (Macro Usage - Target)
# ============================================================================

when false:
  # This is what we WANT to write:
  definePrimitive(Button):
    props:
      text: string
      disabled: bool = false

    state:
      pressed: bool
      hovered: bool

    actions:
      onClick()

    events:
      on_mouse_down:
        if not widget.disabled:
          widget.pressed.set(true)
          return true

      on_mouse_up:
        if widget.pressed.get() and not widget.disabled:
          widget.pressed.set(false)
          if widget.onClick.isSome:
            widget.onClick.get()()
          return true

      on_mouse_move:
        let mouseX = event.mousePos.x
        let mouseY = event.mousePos.y
        let isOver = mouseX >= widget.bounds.x and
                     mouseX <= widget.bounds.x + widget.bounds.width and
                     mouseY >= widget.bounds.y and
                     mouseY <= widget.bounds.y + widget.bounds.height
        widget.hovered.set(isOver)

    render:
      let pressed = widget.pressed.get()
      let hovered = widget.hovered.get()

      echo "Rendering Button: ", widget.text,
           " (pressed=", pressed,
           ", hovered=", hovered,
           ", disabled=", widget.disabled, ")"

  # Should generate the same code as ButtonManual above

# ============================================================================
# Test Usage
# ============================================================================

proc testManualWidgets() =
  echo "\n=== Testing Manual Widgets ==="

  # Create label
  let label = newLabelManual("Hello World", 16.0)
  label.render()

  # Create button
  let button = newButtonManual(
    text = "Click Me",
    disabled = false,
    onClick = proc() =
      echo "Button clicked!"
  )

  button.render()

  # Simulate events
  echo "\n--- Simulating mouse down ---"
  discard button.handleInput(GuiEvent(
    kind: evMouseDown,
    mousePos: Point(x: 50, y: 15)
  ))

  button.render()

  echo "\n--- Simulating mouse up ---"
  discard button.handleInput(GuiEvent(
    kind: evMouseUp,
    mousePos: Point(x: 50, y: 15)
  ))

  button.render()

when isMainModule:
  testManualWidgets()

# ============================================================================
# Code Comparison
# ============================================================================

## Manual Implementation:
## - 80+ lines for Button (type + constructor + render + handleInput)
## - Manual state initialization (newLink for each field)
## - Manual action wrapping (some/none)
## - Manual event routing (case statement)
## - Lots of boilerplate
##
## Macro Usage:
## - ~30 lines for Button (just the logic)
## - Automatic state initialization
## - Automatic action wrapping
## - Declarative event handlers
## - No boilerplate
##
## The macro should generate identical code to the manual version!

# ============================================================================
# What the Macro Needs to Generate
# ============================================================================

## 1. Type Definition
##    - Inherit from Widget
##    - Add props as fields
##    - Add state as Link[T] fields
##    - Add actions as Option[proc] fields
##
## 2. Constructor
##    - All base Widget initialization
##    - Props as parameters (with defaults)
##    - Actions as optional parameters
##    - State initialization with newLink
##    - Action initialization with some/none
##
## 3. Render Method
##    - Visibility check
##    - User's render code
##    - Children rendering
##
## 4. HandleInput Method
##    - Visibility/enabled check
##    - Event routing based on events block
##    - Map event kinds to handlers
##    - Proper return values
##    - Children propagation
