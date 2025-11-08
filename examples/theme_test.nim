## Theme System Test
##
## Tests:
## 1. Built-in themes (light, dark, beos, joy, wide)
## 2. Theme property access (getThemeProps)
## 3. State-based rendering
## 4. Theme switching

import raylib
import ../drawing_primitives/[theme_sys_core, builtin_themes]
import ../core/types

proc main() =
  initWindow(900, 700, "Theme System Test")
  defer: closeWindow()
  setTargetFPS(60)

  echo "=== Testing Built-in Themes ==="

  # Test all built-in themes
  let themes = @["light", "dark", "beos", "joy", "wide"]
  var currentThemeIdx = 0
  var currentTheme = getBuiltinTheme(themes[currentThemeIdx])

  echo "Initial theme: ", currentTheme.name

  # Test getting properties for different states
  echo "\n=== Default Intent, Different States ==="
  let normalProps = currentTheme.getThemeProps(ThemeIntent.Default, ThemeState.Normal)
  echo "Normal state:"
  if normalProps.backgroundColor.isSome:
    let bg = normalProps.backgroundColor.get()
    echo "  backgroundColor: rgb(", bg.r, ", ", bg.g, ", ", bg.b, ")"
  if normalProps.cornerRadius.isSome:
    echo "  cornerRadius: ", normalProps.cornerRadius.get()

  let hoveredProps = currentTheme.getThemeProps(ThemeIntent.Default, ThemeState.Hovered)
  echo "Hovered state:"
  if hoveredProps.backgroundColor.isSome:
    let bg = hoveredProps.backgroundColor.get()
    echo "  backgroundColor: rgb(", bg.r, ", ", bg.g, ", ", bg.b, ")"

  let pressedProps = currentTheme.getThemeProps(ThemeIntent.Default, ThemeState.Pressed)
  echo "Pressed state:"
  if pressedProps.backgroundColor.isSome:
    let bg = pressedProps.backgroundColor.get()
    echo "  backgroundColor: rgb(", bg.r, ", ", bg.g, ", ", bg.b, ")"

  # Test different intents
  echo "\n=== Different Intents, Normal State ==="
  for intent in [ThemeIntent.Default, ThemeIntent.Info, ThemeIntent.Success, ThemeIntent.Warning, ThemeIntent.Danger]:
    let props = currentTheme.getThemeProps(intent, ThemeState.Normal)
    echo $intent, ":"
    if props.backgroundColor.isSome:
      let bg = props.backgroundColor.get()
      echo "  backgroundColor: rgb(", bg.r, ", ", bg.g, ", ", bg.b, ")"

  echo "\n=== Interactive Demo ==="
  echo "Press SPACE to cycle through themes"
  echo "Hover over buttons to see state changes"

  var frameCount = 0
  var buttonRects: array[5, Rect]
  let startY = 150.0f32

  # Create button rectangles
  for i in 0..4:
    buttonRects[i] = Rect(
      x: 100.0f32,
      y: startY + float32(i) * 80.0f32,
      width: 200.0f32,
      height: 50.0f32
    )

  while not windowShouldClose():
    frameCount += 1
    let mousePos = getMousePosition()

    # Handle theme switching with SPACE
    if isKeyPressed(KeyboardKey.Space):
      currentThemeIdx = (currentThemeIdx + 1) mod themes.len
      currentTheme = getBuiltinTheme(themes[currentThemeIdx])
      echo "\nSwitched to theme: ", currentTheme.name

    # Check which button is hovered
    var hoveredButton = -1
    for i in 0..4:
      let r = buttonRects[i]
      if mousePos.x >= r.x and mousePos.x <= r.x + r.width and
         mousePos.y >= r.y and mousePos.y <= r.y + r.height:
        hoveredButton = i

    beginDrawing()
    clearBackground(Color(r: 30, g: 30, b: 40, a: 255))

    # Title
    raylib.drawText("Theme System Test", 10'i32, 10'i32, 24'i32, WHITE)
    raylib.drawText("Press SPACE to cycle themes", 10'i32, 40'i32, 16'i32, GRAY)

    # Show current theme name
    let themeText = "Current Theme: " & currentTheme.name
    raylib.drawText(themeText, 10'i32, 70'i32, 20'i32, YELLOW)

    # Draw buttons with different intents
    let intents = [ThemeIntent.Default, ThemeIntent.Info, ThemeIntent.Success, ThemeIntent.Warning, ThemeIntent.Danger]
    let intentNames = ["Default", "Info", "Success", "Warning", "Danger"]

    for i in 0..4:
      let r = buttonRects[i]
      let intent = intents[i]
      let state = if i == hoveredButton: ThemeState.Hovered else: ThemeState.Normal

      # Get themed properties
      let props = currentTheme.getThemeProps(intent, state)

      # Draw button background
      let bgColor = if props.backgroundColor.isSome:
                      props.backgroundColor.get()
                    else:
                      GRAY

      let cornerRad = if props.cornerRadius.isSome:
                       props.cornerRadius.get()
                     else:
                       4.0f32

      # Draw rounded rect
      drawRectangleRounded(
        Rectangle(x: r.x, y: r.y, width: r.width, height: r.height),
        cornerRad / r.height,
        10,
        bgColor
      )

      # Draw border
      if props.borderColor.isSome and props.borderWidth.isSome:
        drawRectangleRoundedLines(
          Rectangle(x: r.x, y: r.y, width: r.width, height: r.height),
          cornerRad / r.height,
          10,
          2,
          props.borderColor.get()
        )

      # Draw text
      let fgColor = if props.foregroundColor.isSome:
                      props.foregroundColor.get()
                    else:
                      WHITE

      let text = intentNames[i]
      let fontSize = if props.fontSize.isSome:
                      int32(props.fontSize.get())
                     else:
                      14'i32

      let textWidth = measureText(text, fontSize)
      let textX = int32(r.x + (r.width - float32(textWidth)) / 2.0)
      let textY = int32(r.y + (r.height - float32(fontSize)) / 2.0)

      raylib.drawText(text, textX, textY, fontSize, fgColor)

    # Show stats
    raylib.drawText("Frame: " & $frameCount, 10'i32, 650'i32, 14'i32, LIGHTGRAY)

    # Theme list on right side
    raylib.drawText("Available Themes:", 600'i32, 150'i32, 16'i32, WHITE)
    for i, themeName in themes:
      let color = if i == currentThemeIdx: YELLOW else: LIGHTGRAY
      raylib.drawText("  " & themeName, 600'i32, int32(180 + i * 25), 14'i32, color)

    endDrawing()

when isMainModule:
  main()
