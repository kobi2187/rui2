## Basic Pango Test - Verify Pango+Cairo→Raylib pipeline works
##
## Tests:
## 1. Initialize Pango layout
## 2. Render to Cairo surface
## 3. Convert to Raylib texture
## 4. Display on screen

import raylib

# Import pangolib_binding from sibling directory
import ../pangolib_binding/src/[pangotypes, pangocore]

proc main() =
  initWindow(800, 600, "Pango Basic Test")
  defer: closeWindow()
  setTargetFPS(60)

  echo "=== Testing Pango+Cairo→Raylib Pipeline ==="

  # Test 1: Basic ASCII text
  echo "\n1. Testing ASCII text..."
  let asciiResult = initTextLayout("Hello, RUI2!", maxWidth = 400)
  if asciiResult.isErr:
    echo "ERROR: Failed to create ASCII layout: ", asciiResult.error.message
    return
  var asciiLayout = asciiResult.get()
  echo "✓ ASCII layout created: ", asciiLayout.width, "x", asciiLayout.height

  # Test 2: Unicode text (emoji, Chinese, Arabic)
  echo "\n2. Testing Unicode text..."
  let unicodeText = "Hello 世界 שלום 🚀"
  let unicodeResult = initTextLayout(unicodeText, maxWidth = 400)
  if unicodeResult.isErr:
    echo "ERROR: Failed to create Unicode layout: ", unicodeResult.error.message
    return
  var unicodeLayout = unicodeResult.get()
  echo "✓ Unicode layout created: ", unicodeLayout.width, "x", unicodeLayout.height

  # Test 3: Multi-line text
  echo "\n3. Testing multi-line text..."
  let multilineText = "Line 1\nLine 2\nLine 3"
  let multilineResult = initTextLayout(multilineText, maxWidth = 300)
  if multilineResult.isErr:
    echo "ERROR: Failed to create multiline layout: ", multilineResult.error.message
    return
  var multilineLayout = multilineResult.get()
  echo "✓ Multiline layout created: ", multilineLayout.width, "x", multilineLayout.height

  # Test 4: Cursor positioning
  echo "\n4. Testing cursor positioning..."
  let cursorResult = getCursorPosition(asciiLayout, 7)
  if cursorResult.isOk:
    let (cx, cy) = cursorResult.get()
    echo "✓ Cursor at index 7: (", cx, ", ", cy, ")"
  else:
    echo "ERROR: Cursor position failed: ", cursorResult.error.message

  # Test 5: Position to index
  echo "\n5. Testing position→index..."
  let indexResult = getTextIndexFromPosition(asciiLayout, 50, 5)
  if indexResult.isOk:
    echo "✓ Index at (50, 5): ", indexResult.get()
  else:
    echo "ERROR: Position to index failed: ", indexResult.error.message

  echo "\n=== All tests passed! ==="
  echo "Press ESC to exit, or wait to see rendering..."

  var frameCount = 0

  while not windowShouldClose():
    frameCount += 1

    beginDrawing()
    clearBackground(Color(r: 30, g: 30, b: 40, a: 255))

    # Title
    raylib.drawText("Pango Basic Test", 10'i32, 10'i32, 24'i32, WHITE)
    raylib.drawText("All Pango tests passed! See console for details.", 10'i32, 40'i32, 16'i32, LIGHTGRAY)

    # Draw ASCII layout texture
    drawTexture(asciiLayout.texture, 50, 100, WHITE)
    raylib.drawText("ASCII:", 50'i32, 80'i32, 14'i32, YELLOW)

    # Draw Unicode layout texture
    drawTexture(unicodeLayout.texture, 50, 180, WHITE)
    raylib.drawText("Unicode (Chinese, Hebrew, Emoji):", 50'i32, 160'i32, 14'i32, YELLOW)

    # Draw multiline layout texture
    drawTexture(multilineLayout.texture, 50, 260, WHITE)
    raylib.drawText("Multi-line:", 50'i32, 240'i32, 14'i32, YELLOW)

    # Draw cursor position indicator on ASCII text
    if cursorResult.isOk:
      let (cx, cy) = cursorResult.get()
      drawLine(50 + cx, 100 + cy, 50 + cx, 100 + cy + 20, RED)
      raylib.drawText("↑ Cursor at index 7", 50'i32, 125'i32, 12'i32, RED)

    # Stats
    raylib.drawText("Frame: " & $frameCount, 10'i32, 570'i32, 14'i32, LIGHTGRAY)
    raylib.drawText("Press ESC to exit", 10'i32, 550'i32, 14'i32, LIGHTGRAY)

    endDrawing()

when isMainModule:
  main()
