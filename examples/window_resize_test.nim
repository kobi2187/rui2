## Window Resize Test
##
## Tests:
## 1. User can resize window by dragging edges
## 2. Programmatic window resizing via keyboard
## 3. Window size is tracked correctly
## 4. Events are generated on resize

import raylib
import ../core/[types, app]

proc main() =
  # Create resizable app
  let app = newApp(
    title = "Window Resize Test - Press 1/2/3 to resize",
    width = 800,
    height = 600,
    fps = 60,
    resizable = true
  )

  # Run custom loop to test programmatic resize
  initWindow(app.window.width.int32, app.window.height.int32, app.window.title)
  setTargetFPS(app.window.fps.int32)

  if app.window.resizable:
    setWindowState(flags(WindowResizable))

  defer: closeWindow()

  echo "Window Resize Test Started"
  echo "  Initial size: ", app.window.width, "x", app.window.height
  echo "  Resizable: ", app.window.resizable
  echo ""
  echo "Controls:"
  echo "  - Drag window edges to resize"
  echo "  - Press 1: Small window (640x480)"
  echo "  - Press 2: Medium window (800x600)"
  echo "  - Press 3: Large window (1024x768)"
  echo "  - Press R: Toggle resizable"
  echo ""

  var frameCount = 0
  var lastWidth = app.window.width
  var lastHeight = app.window.height

  while not windowShouldClose():
    # Check for keyboard commands
    if isKeyPressed(KeyboardKey.One):
      echo "Setting window to 640x480"
      app.setWindowSize(640, 480)
    elif isKeyPressed(KeyboardKey.Two):
      echo "Setting window to 800x600"
      app.setWindowSize(800, 600)
    elif isKeyPressed(KeyboardKey.Three):
      echo "Setting window to 1024x768"
      app.setWindowSize(1024, 768)
    elif isKeyPressed(KeyboardKey.R):
      app.setWindowResizable(not app.window.resizable)
      echo "Resizable: ", app.window.resizable

    # Detect window resize
    if isWindowResized():
      let newWidth = getScreenWidth()
      let newHeight = getScreenHeight()
      app.window.width = newWidth
      app.window.height = newHeight
      echo "Window resized to ", newWidth, "x", newHeight

    # Rendering
    beginDrawing()
    clearBackground(Color(r: 25, g: 25, b: 35, a: 255))

    # Title
    drawText("WINDOW RESIZE TEST", 20'i32, 20'i32, 32'i32, Color(r: 255, g: 220, b: 100, a: 255))

    # Instructions
    var yPos = 70'i32
    drawText("Controls:", 20'i32, yPos, 20'i32, Color(r: 200, g: 200, b: 200, a: 255))
    yPos += 30

    drawText("1 - Small window (640x480)", 40'i32, yPos, 16'i32, Color(r: 150, g: 150, b: 150, a: 255))
    yPos += 25
    drawText("2 - Medium window (800x600)", 40'i32, yPos, 16'i32, Color(r: 150, g: 150, b: 150, a: 255))
    yPos += 25
    drawText("3 - Large window (1024x768)", 40'i32, yPos, 16'i32, Color(r: 150, g: 150, b: 150, a: 255))
    yPos += 25
    drawText("R - Toggle resizable", 40'i32, yPos, 16'i32, Color(r: 150, g: 150, b: 150, a: 255))
    yPos += 25
    drawText("Drag window edges to resize", 40'i32, yPos, 16'i32, Color(r: 150, g: 150, b: 150, a: 255))

    # Current window info
    yPos += 50
    drawText("Current Window Info:", 20'i32, yPos, 20'i32, Color(r: 200, g: 200, b: 200, a: 255))
    yPos += 30

    let widthText = "Width: " & $app.window.width & " px"
    drawText(widthText, 40'i32, yPos, 18'i32, Color(r: 100, g: 200, b: 100, a: 255))
    yPos += 25

    let heightText = "Height: " & $app.window.height & " px"
    drawText(heightText, 40'i32, yPos, 18'i32, Color(r: 100, g: 200, b: 100, a: 255))
    yPos += 25

    let resizableText = "Resizable: " & $app.window.resizable
    let resizableColor = if app.window.resizable:
                           Color(r: 100, g: 200, b: 100, a: 255)
                         else:
                           Color(r: 200, g: 100, b: 100, a: 255)
    drawText(resizableText, 40'i32, yPos, 18'i32, resizableColor)
    yPos += 25

    let fpsText = "FPS: " & $getFPS()
    drawText(fpsText, 40'i32, yPos, 18'i32, Color(r: 100, g: 150, b: 200, a: 255))

    # Visual feedback - draw border showing window bounds
    let w = getScreenWidth()
    let h = getScreenHeight()
    drawRectangleLines(5'i32, 5'i32, (w - 10).int32, (h - 10).int32, Color(r: 100, g: 100, b: 200, a: 255))

    # Size change indicator
    if app.window.width != lastWidth or app.window.height != lastHeight:
      drawText("SIZE CHANGED!", (w div 2 - 100).int32, (h - 60).int32, 24'i32, Color(r: 255, g: 100, b: 100, a: 255))
      lastWidth = app.window.width
      lastHeight = app.window.height

    endDrawing()
    inc frameCount

when isMainModule:
  main()
