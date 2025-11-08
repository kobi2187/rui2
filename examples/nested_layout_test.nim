## Nested Layout Test - Complex UI with VStack + HStack
##
## Creates a realistic UI layout:
## - Header (HStack with logo + nav buttons)
## - Content area (VStack)
##   - Title label
##   - Button row (HStack)
##   - Status labels (VStack)
## - Footer (HStack with buttons)

import raylib
import ../core/[types, widget_dsl]
import ../widgets/[button_yaml, hstack, vstack, label]
import ../drawing_primitives/[theme_sys_core, builtin_themes]

proc main() =
  initWindow(1000, 800, "Nested Layout Test - Complex UI")
  defer: closeWindow()
  setTargetFPS(60)

  echo "=== Creating Complex Nested Layout ==="

  let theme = getBuiltinTheme("light")

  # Root container - VStack for vertical sections
  let rootContainer = newVStack()
  rootContainer.bounds = Rect(x: 20, y: 20, width: 960, height: 760)
  rootContainer.spacing = 20.0
  rootContainer.justify = Start
  rootContainer.align = Stretch
  rootContainer.padding = EdgeInsets(top: 16, right: 16, bottom: 16, left: 16)

  # === HEADER ===
  let header = newHStack()
  header.bounds.height = 60
  header.spacing = 20.0
  header.justify = SpaceBetween
  header.align = Center
  header.padding = EdgeInsets(top: 8, right: 16, bottom: 8, left: 16)

  # Logo (label)
  let logo = newLabel()
  logo.text = "My App"
  logo.intent = ThemeIntent.Info
  logo.theme = theme
  logo.textAlign = TextAlign.Center
  logo.bounds.width = 120
  logo.bounds.height = 44
  header.addChild(logo)

  # Nav buttons container
  let navButtons = newHStack()
  navButtons.bounds.height = 44
  navButtons.spacing = 12.0
  navButtons.justify = End
  navButtons.align = Center

  for text in ["Home", "About", "Settings"]:
    let btn = newButtonYAML()
    btn.text = text
    btn.bounds.width = 100
    btn.bounds.height = 36
    navButtons.addChild(btn)

  header.addChild(navButtons)
  rootContainer.addChild(header)

  # === CONTENT AREA ===
  let contentArea = newVStack()
  contentArea.bounds.height = 500
  contentArea.spacing = 16.0
  contentArea.justify = Start
  contentArea.align = Stretch
  contentArea.padding = EdgeInsets(top: 16, right: 16, bottom: 16, left: 16)

  # Title
  let title = newLabel()
  title.text = "Welcome to RUI2"
  title.intent = ThemeIntent.Success
  title.theme = theme
  title.textAlign = TextAlign.Center
  title.bounds.height = 40
  contentArea.addChild(title)

  # Action buttons row
  let actionRow = newHStack()
  actionRow.bounds.height = 60
  actionRow.spacing = 16.0
  actionRow.justify = Center
  actionRow.align = Center

  let intents = [ThemeIntent.Success, ThemeIntent.Warning, ThemeIntent.Danger]
  let btnLabels = ["Save", "Edit", "Delete"]

  for i in 0..2:
    let btn = newButtonYAML()
    btn.text = btnLabels[i]
    btn.bounds.width = 140
    btn.bounds.height = 44
    # TODO: Theme intents for buttons
    actionRow.addChild(btn)

  contentArea.addChild(actionRow)

  # Status section - VStack with multiple labels
  let statusSection = newVStack()
  statusSection.bounds.height = 250
  statusSection.spacing = 12.0
  statusSection.justify = Start
  statusSection.align = Stretch
  statusSection.padding = EdgeInsets(top: 12, right: 12, bottom: 12, left: 12)

  let statusIntents = [ThemeIntent.Info, ThemeIntent.Success, ThemeIntent.Warning]
  let statusTexts = ["System Status: Online", "Database: Connected", "Memory Usage: 45%"]

  for i in 0..2:
    let statusLabel = newLabel()
    statusLabel.text = statusTexts[i]
    statusLabel.intent = statusIntents[i]
    statusLabel.theme = theme
    statusLabel.textAlign = TextAlign.Left
    statusLabel.bounds.height = 50
    statusSection.addChild(statusLabel)

  contentArea.addChild(statusSection)
  rootContainer.addChild(contentArea)

  # === FOOTER ===
  let footer = newHStack()
  footer.bounds.height = 60
  footer.spacing = 16.0
  footer.justify = End
  footer.align = Center
  footer.padding = EdgeInsets(top: 8, right: 16, bottom: 8, left: 16)

  for text in ["Help", "About", "Exit"]:
    let btn = newButtonYAML()
    btn.text = text
    btn.bounds.width = 100
    btn.bounds.height = 40
    footer.addChild(btn)

  rootContainer.addChild(footer)

  # Initial layout
  echo "\n=== Performing Initial Layout ==="
  rootContainer.layout()

  echo "Root container children:"
  echo "  Header: ", header.bounds
  echo "  Content: ", contentArea.bounds
  echo "  Footer: ", footer.bounds

  echo "\nHeader children:"
  for i, child in header.children:
    echo "  Child ", i, ": ", child.bounds

  echo "\nContent area children:"
  for i, child in contentArea.children:
    echo "  Child ", i, ": ", child.bounds

  echo "\n=== Rendering ==="

  var frameCount = 0

  while not windowShouldClose():
    frameCount += 1

    beginDrawing()
    clearBackground(Color(r: 40, g: 44, b: 52, a: 255))

    # Title
    raylib.drawText("Nested Layout Test", 10'i32, 5'i32, 20'i32, WHITE)

    # Draw root container bounds
    drawRectangleLines(
      int32(rootContainer.bounds.x),
      int32(rootContainer.bounds.y),
      int32(rootContainer.bounds.width),
      int32(rootContainer.bounds.height),
      GREEN
    )

    # Draw section bounds
    drawRectangleLines(
      int32(header.bounds.x),
      int32(header.bounds.y),
      int32(header.bounds.width),
      int32(header.bounds.height),
      YELLOW
    )

    drawRectangleLines(
      int32(contentArea.bounds.x),
      int32(contentArea.bounds.y),
      int32(contentArea.bounds.width),
      int32(contentArea.bounds.height),
      BLUE
    )

    drawRectangleLines(
      int32(footer.bounds.x),
      int32(footer.bounds.y),
      int32(footer.bounds.width),
      int32(footer.bounds.height),
      PURPLE
    )

    # Render all widgets
    rootContainer.render()

    # Stats
    raylib.drawText("Frame: " & $frameCount, 10'i32, 770'i32, 14'i32, LIGHTGRAY)
    raylib.drawText("Green=Root, Yellow=Header, Blue=Content, Purple=Footer", 100'i32, 770'i32, 12'i32, LIGHTGRAY)

    endDrawing()

when isMainModule:
  main()
