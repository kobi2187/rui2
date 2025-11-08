## HStack Test - Horizontal layout
##
## Tests:
## 1. HStack positions children horizontally
## 2. Spacing between children works
## 3. Alignment (cross-axis) works
## 4. Justification (main-axis) works

import raylib
import ../core/[types, widget_dsl]
import ../widgets/button_yaml
import ../widgets/hstack as hstackWidget
import ../widgets/label
import ../drawing_primitives/[theme_sys_core, builtin_themes]

proc main() =
  initWindow(900, 700, "HStack Test - Horizontal Layout")
  defer: closeWindow()
  setTargetFPS(60)

  echo "=== HStack Layout Test ==="

  let theme = getBuiltinTheme("light")

  # Create HStack with buttons
  let hstack1 = hstackWidget.newHStack()
  hstack1.bounds = Rect(x: 50, y: 50, width: 800, height: 60)
  hstack1.spacing = 16.0
  hstack1.justify = Start
  hstack1.align = Center
  hstack1.padding = EdgeInsets(top: 8, right: 8, bottom: 8, left: 8)

  # Add buttons
  for i in 0..3:
    let btn = newButtonYAML()
    btn.text = "Button " & $(i + 1)
    btn.bounds.width = 120
    btn.bounds.height = 40
    hstack1.addChild(btn)

  # Initial layout
  hstack1.layout()

  echo "\n=== Initial Positions (Start justify, Center align) ==="
  for i, child in hstack1.children:
    echo "Child ", i, ": x=", child.bounds.x, ", y=", child.bounds.y

  # Create second HStack with Center justification
  let hstack2 = hstackWidget.newHStack()
  hstack2.bounds = Rect(x: 50, y: 150, width: 800, height: 60)
  hstack2.spacing = 16.0
  hstack2.justify = Center
  hstack2.align = Center
  hstack2.padding = EdgeInsets(top: 8, right: 8, bottom: 8, left: 8)

  for i in 0..2:
    let btn = newButtonYAML()
    btn.text = "Centered " & $(i + 1)
    btn.bounds.width = 150
    btn.bounds.height = 40
    hstack2.addChild(btn)

  hstack2.layout()

  echo "\n=== Center Justified ==="
  for i, child in hstack2.children:
    echo "Child ", i, ": x=", child.bounds.x

  # Create third HStack with SpaceBetween
  let hstack3 = hstackWidget.newHStack()
  hstack3.bounds = Rect(x: 50, y: 250, width: 800, height: 60)
  hstack3.spacing = 0.0  # SpaceBetween calculates spacing
  hstack3.justify = SpaceBetween
  hstack3.align = Center
  hstack3.padding = EdgeInsets(top: 8, right: 8, bottom: 8, left: 8)

  for i in 0..2:
    let btn = newButtonYAML()
    btn.text = "Spaced " & $(i + 1)
    btn.bounds.width = 140
    btn.bounds.height = 40
    hstack3.addChild(btn)

  hstack3.layout()

  echo "\n=== SpaceBetween Justified ==="
  for i, child in hstack3.children:
    echo "Child ", i, ": x=", child.bounds.x

  # Create HStack with Labels
  let hstack4 = hstackWidget.newHStack()
  hstack4.bounds = Rect(x: 50, y: 350, width: 800, height: 100)
  hstack4.spacing = 20.0
  hstack4.justify = Start
  hstack4.align = Stretch  # Labels stretch to full height
  hstack4.padding = EdgeInsets(top: 8, right: 8, bottom: 8, left: 8)

  let intents = [ThemeIntent.Info, ThemeIntent.Success, ThemeIntent.Warning, ThemeIntent.Danger]
  let labels = ["Info", "Success", "Warning", "Danger"]

  for i in 0..3:
    let lbl = newLabel()
    lbl.text = labels[i]
    lbl.intent = intents[i]
    lbl.theme = theme
    lbl.textAlign = TextAlign.Center
    lbl.bounds.width = 150
    lbl.bounds.height = 60  # Will be stretched
    hstack4.addChild(lbl)

  hstack4.layout()

  echo "\n=== Labels with Stretch Align ==="
  for i, child in hstack4.children:
    echo "Child ", i, ": x=", child.bounds.x, ", height=", child.bounds.height

  echo "\n=== Rendering ==="

  var frameCount = 0

  while not windowShouldClose():
    frameCount += 1

    beginDrawing()
    clearBackground(Color(r: 30, g: 30, b: 40, a: 255))

    # Title
    raylib.drawText("HStack Test - Horizontal Layout", 10'i32, 10'i32, 24'i32, WHITE)

    # Labels
    raylib.drawText("Start Justify:", 50'i32, 30'i32, 14'i32, LIGHTGRAY)
    raylib.drawText("Center Justify:", 50'i32, 130'i32, 14'i32, LIGHTGRAY)
    raylib.drawText("SpaceBetween:", 50'i32, 230'i32, 14'i32, LIGHTGRAY)
    raylib.drawText("Labels with Stretch:", 50'i32, 330'i32, 14'i32, LIGHTGRAY)

    # Draw HStack bounds
    drawRectangleLines(
      int32(hstack1.bounds.x),
      int32(hstack1.bounds.y),
      int32(hstack1.bounds.width),
      int32(hstack1.bounds.height),
      YELLOW
    )

    drawRectangleLines(
      int32(hstack2.bounds.x),
      int32(hstack2.bounds.y),
      int32(hstack2.bounds.width),
      int32(hstack2.bounds.height),
      YELLOW
    )

    drawRectangleLines(
      int32(hstack3.bounds.x),
      int32(hstack3.bounds.y),
      int32(hstack3.bounds.width),
      int32(hstack3.bounds.height),
      YELLOW
    )

    drawRectangleLines(
      int32(hstack4.bounds.x),
      int32(hstack4.bounds.y),
      int32(hstack4.bounds.width),
      int32(hstack4.bounds.height),
      YELLOW
    )

    # Render HStacks
    hstack1.render()
    hstack2.render()
    hstack3.render()
    hstack4.render()

    # Stats
    raylib.drawText("Frame: " & $frameCount, 10'i32, 670'i32, 14'i32, LIGHTGRAY)

    endDrawing()

when isMainModule:
  main()
