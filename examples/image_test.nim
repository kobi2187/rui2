## ImageWidget Test - Visual test for the ImageWidget
##
## What this tests: ImageWidget with different fit modes and image loading
## Expected behavior: Images render with proper scaling, or show placeholder if missing
## How to verify:
##   - Images display if paths are valid
##   - Placeholder shows if image missing
##   - Different fit modes work correctly
##   - Click handlers work (if enabled)
##
## Status: ✅ Testing

import raylib
import ../core/[types, widget_dsl_v2]
import ../widgets/basic/image

proc main() =
  # Setup window
  initWindow(1000, 700, "ImageWidget Test")
  defer: closeWindow()
  setTargetFPS(60)

  # Create ImageWidgets with different configurations
  # Note: Replace these paths with actual image files to see them render

  # Image 1: No path (shows placeholder)
  let img1 = ImageWidget(
    imagePath = "",
    width = 200.0,
    height = 150.0
  )
  img1.bounds.x = 50
  img1.bounds.y = 100

  # Image 2: With a path (will show placeholder if file doesn't exist)
  let img2 = ImageWidget(
    imagePath = "test.png",  # Replace with actual image path
    width = 200.0,
    height = 150.0,
    fitMode = ImageFit.Contain
  )
  img2.bounds.x = 270
  img2.bounds.y = 100

  # Image 3: Different fit mode
  let img3 = ImageWidget(
    imagePath = "icon.png",  # Replace with actual image path
    width = 200.0,
    height = 150.0,
    fitMode = ImageFit.Cover
  )
  img3.bounds.x = 490
  img3.bounds.y = 100

  # Image 4: Clickable image
  let img4 = ImageWidget(
    imagePath = "button.png",  # Replace with actual image path
    width = 200.0,
    height = 150.0,
    fitMode = ImageFit.Fill,
    onClick = proc() = echo "Image 4 clicked!"
  )
  img4.bounds.x = 710
  img4.bounds.y = 100

  # Image 5: ScaleDown mode
  let img5 = ImageWidget(
    imagePath = "logo.png",  # Replace with actual image path
    width = 150.0,
    height = 150.0,
    fitMode = ImageFit.ScaleDown
  )
  img5.bounds.x = 50
  img5.bounds.y = 300

  # Image 6: None mode
  let img6 = ImageWidget(
    imagePath = "avatar.png",  # Replace with actual image path
    width = 150.0,
    height = 150.0,
    fitMode = ImageFit.None
  )
  img6.bounds.x = 220
  img6.bounds.y = 300

  # Image 7: With tint color
  let img7 = ImageWidget(
    imagePath = "icon.png",  # Replace with actual image path
    width = 150.0,
    height = 150.0,
    tintColor = Color(r: 255, g: 150, b: 150, a: 255)  # Reddish tint
  )
  img7.bounds.x = 390
  img7.bounds.y = 300

  var images = @[img1, img2, img3, img4, img5, img6, img7]

  # Main loop
  while not windowShouldClose():
    let mousePos = getMousePosition()

    # Update hover state for all images
    for img in images:
      img.isHovered.set(
        mousePos.x >= img.bounds.x and
        mousePos.x <= img.bounds.x + img.bounds.width and
        mousePos.y >= img.bounds.y and
        mousePos.y <= img.bounds.y + img.bounds.height
      )

    # Handle mouse events
    if isMouseButtonPressed(MouseButton.Left):
      let event = GuiEvent(
        kind: evMouseDown,
        priority: epHigh,
        mousePos: Point(x: mousePos.x, y: mousePos.y)
      )
      for img in images:
        if img.handleInput(event):
          break

    if isMouseButtonReleased(MouseButton.Left):
      let event = GuiEvent(
        kind: evMouseUp,
        priority: epHigh,
        mousePos: Point(x: mousePos.x, y: mousePos.y)
      )
      for img in images:
        if img.handleInput(event):
          break

    # Render
    beginDrawing()
    clearBackground(Color(r: 30, g: 30, b: 35, a: 255))  # Dark background

    # Draw title and instructions
    raylib.drawText("ImageWidget Test", 10'i32, 10'i32, 24'i32, WHITE)
    raylib.drawText("Replace imagePath values with actual image files to test", 10'i32, 40'i32, 16'i32, LIGHTGRAY)
    raylib.drawText("Image 4 is clickable - click it to see console message", 10'i32, 60'i32, 14'i32, LIGHTGRAY)

    # Draw labels for each image
    raylib.drawText("No Path", 50'i32, 80'i32, 12'i32, LIGHTGRAY)
    raylib.drawText("Contain", 270'i32, 80'i32, 12'i32, LIGHTGRAY)
    raylib.drawText("Cover", 490'i32, 80'i32, 12'i32, LIGHTGRAY)
    raylib.drawText("Fill (Clickable)", 710'i32, 80'i32, 12'i32, LIGHTGRAY)
    raylib.drawText("ScaleDown", 50'i32, 280'i32, 12'i32, LIGHTGRAY)
    raylib.drawText("None", 220'i32, 280'i32, 12'i32, LIGHTGRAY)
    raylib.drawText("With Tint", 390'i32, 280'i32, 12'i32, LIGHTGRAY)

    # Render images
    for img in images:
      img.render()

    # Draw instructions at bottom
    raylib.drawText("Fit Modes: Contain | Cover | Fill | None | ScaleDown", 10'i32, 650'i32, 14'i32, GRAY)

    endDrawing()

when isMainModule:
  main()
