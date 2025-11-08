## TextInput Widget Test
##
## Tests:
## 1. Basic text input (typing, backspace, delete)
## 2. Cursor positioning (click to move cursor)
## 3. Arrow key navigation
## 4. Theme integration
## 5. on_change and on_submit callbacks

import raylib
import ../widgets/[textinput, label, vstack]
import ../drawing_primitives/[theme_sys_core, builtin_themes]
import ../core/[types, widget_dsl]
import std/[strformat, strutils]

proc main() =
  initWindow(800, 600, "TextInput Test")
  defer: closeWindow()
  setTargetFPS(60)

  # Create theme
  let theme = getBuiltinTheme("light")

  # Create widgets
  var titleLabel = newLabel()
  titleLabel.text = "TextInput Widget Test"
  titleLabel.theme = theme
  titleLabel.intent = ThemeIntent.Info
  titleLabel.bounds = Rect(x: 50, y: 30, width: 700, height: 40)

  var instructionsLabel = newLabel()
  instructionsLabel.text = "Click and type in the fields below. Press Enter to submit."
  instructionsLabel.theme = theme
  instructionsLabel.bounds = Rect(x: 50, y: 80, width: 700, height: 30)

  var nameLabel = newLabel()
  nameLabel.text = "Name:"
  nameLabel.theme = theme
  nameLabel.bounds = Rect(x: 50, y: 130, width: 100, height: 30)

  var nameInput = newTextInput()
  nameInput.placeholder = "Enter your name"
  nameInput.theme = theme
  nameInput.bounds = Rect(x: 160, y: 130, width: 400, height: 36)
  nameInput.onChange = proc(newText: string) =
    echo "Name changed: ", newText

  var emailLabel = newLabel()
  emailLabel.text = "Email:"
  emailLabel.theme = theme
  emailLabel.bounds = Rect(x: 50, y: 180, width: 100, height: 30)

  var emailInput = newTextInput()
  emailInput.placeholder = "you@example.com"
  emailInput.theme = theme
  emailInput.intent = ThemeIntent.Info
  emailInput.bounds = Rect(x: 160, y: 180, width: 400, height: 36)
  emailInput.maxLength = 50
  emailInput.onChange = proc(newText: string) =
    echo "Email changed: ", newText
  emailInput.onSubmit = proc(text: string) =
    echo "Email submitted: ", text

  var passwordLabel = newLabel()
  passwordLabel.text = "Password:"
  passwordLabel.theme = theme
  passwordLabel.bounds = Rect(x: 50, y: 230, width: 100, height: 30)

  var passwordInput = newTextInput()
  passwordInput.placeholder = "Enter password"
  passwordInput.theme = theme
  passwordInput.intent = ThemeIntent.Warning
  passwordInput.bounds = Rect(x: 160, y: 230, width: 400, height: 36)
  passwordInput.onSubmit = proc(text: string) =
    echo "Password submitted (length: ", text.len, ")"

  var outputLabel = newLabel()
  outputLabel.text = "Output will appear here..."
  outputLabel.theme = theme
  outputLabel.intent = ThemeIntent.Success
  outputLabel.bounds = Rect(x: 50, y: 300, width: 700, height: 30)

  # Track which widget is focused
  var focusedWidget: Widget = nil

  echo "=== TextInput Test ==="
  echo "Click on input fields and type"
  echo "Use arrow keys, Home, End to navigate"
  echo "Backspace and Delete to edit"
  echo "Press Enter to submit (triggers callback)"
  echo "Press ESC to exit"
  echo ""

  var frameCount = 0

  while not windowShouldClose():
    frameCount += 1

    # Handle input
    # Mouse click for focus
    if isMouseButtonPressed(MouseButton.Left):
      let mouseX = float32(getMouseX())
      let mouseY = float32(getMouseY())
      let mousePos = Point(x: mouseX, y: mouseY)

      # Check which input was clicked
      var clickedInput: Widget = nil

      if mouseX >= nameInput.bounds.x and mouseX <= nameInput.bounds.x + nameInput.bounds.width and
         mouseY >= nameInput.bounds.y and mouseY <= nameInput.bounds.y + nameInput.bounds.height:
        clickedInput = nameInput

      if mouseX >= emailInput.bounds.x and mouseX <= emailInput.bounds.x + emailInput.bounds.width and
         mouseY >= emailInput.bounds.y and mouseY <= emailInput.bounds.y + emailInput.bounds.height:
        clickedInput = emailInput

      if mouseX >= passwordInput.bounds.x and mouseX <= passwordInput.bounds.x + passwordInput.bounds.width and
         mouseY >= passwordInput.bounds.y and mouseY <= passwordInput.bounds.y + passwordInput.bounds.height:
        clickedInput = passwordInput

      # Update focus
      if clickedInput != nil:
        if focusedWidget != nil:
          focusedWidget.focused = false
        focusedWidget = clickedInput
        focusedWidget.focused = true

        # Send click event to widget
        let event = GuiEvent(
          kind: evMouseUp,
          mousePos: mousePos
        )
        discard clickedInput.handleInput(event)

    # Keyboard input for focused widget
    if focusedWidget != nil:
      # Character input
      let ch = getCharPressed()
      if ch != 0:
        let event = GuiEvent(
          kind: evChar,
          char: char(ch)
        )
        discard focusedWidget.handleInput(event)

      # Special keys
      if isKeyPressed(Backspace):
        let event = GuiEvent(kind: evKeyDown, key: Backspace)
        discard focusedWidget.handleInput(event)

      if isKeyPressed(Delete):
        let event = GuiEvent(kind: evKeyDown, key: Delete)
        discard focusedWidget.handleInput(event)

      if isKeyPressed(Left):
        let event = GuiEvent(kind: evKeyDown, key: Left)
        discard focusedWidget.handleInput(event)

      if isKeyPressed(Right):
        let event = GuiEvent(kind: evKeyDown, key: Right)
        discard focusedWidget.handleInput(event)

      if isKeyPressed(Home):
        let event = GuiEvent(kind: evKeyDown, key: Home)
        discard focusedWidget.handleInput(event)

      if isKeyPressed(End):
        let event = GuiEvent(kind: evKeyDown, key: End)
        discard focusedWidget.handleInput(event)

      if isKeyPressed(Enter) or isKeyPressed(KpEnter):
        let event = GuiEvent(kind: evKeyDown, key: Enter)
        discard focusedWidget.handleInput(event)

    # Update output label
    if nameInput.text.len > 0 or emailInput.text.len > 0 or passwordInput.text.len > 0:
      outputLabel.text = &"Name: '{nameInput.text}' | Email: '{emailInput.text}' | Password: {'*'.repeat(passwordInput.text.len)}"
    else:
      outputLabel.text = "Output will appear here..."

    # Rendering
    beginDrawing()
    clearBackground(Color(r: 245, g: 245, b: 250, a: 255))

    # Render widgets
    titleLabel.render()
    instructionsLabel.render()

    nameLabel.render()
    nameInput.render()

    emailLabel.render()
    emailInput.render()

    passwordLabel.render()
    passwordInput.render()

    outputLabel.render()

    # Debug info
    raylib.drawText(&"Frame: {frameCount}", 10, 570, 14, LIGHTGRAY)
    if focusedWidget == nameInput:
      raylib.drawText("Focused: Name", 10, 550, 14, GREEN)
    elif focusedWidget == emailInput:
      raylib.drawText("Focused: Email", 10, 550, 14, GREEN)
    elif focusedWidget == passwordInput:
      raylib.drawText("Focused: Password", 10, 550, 14, GREEN)
    else:
      raylib.drawText("Focused: None", 10, 550, 14, LIGHTGRAY)

    raylib.drawText("Press ESC to exit", 650, 570, 14, LIGHTGRAY)

    endDrawing()

when isMainModule:
  main()
