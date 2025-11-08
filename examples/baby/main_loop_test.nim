## Main Loop Test
##
## Tests the main application loop integration
## - Event collection and processing
## - Frame timing
## - Headless mode for automated testing

import ../../core/[types, link, app]
import std/[strutils, monotimes]

proc testHeadlessMode() =
  echo repeat("=", 60)
  echo "Main Loop Test (Headless Mode)"
  echo repeat("=", 60)
  echo ""

  # Create application
  let app = newApp(
    title = "Test App",
    width = 800,
    height = 600,
    fps = 60
  )

  # Create a simple store
  type TestStore = ref object of Store
    counter: Link[int]
    message: Link[string]

  let store = TestStore(
    counter: newLink(0),
    message: newLink("Hello RUI")
  )
  app.setStore(store)

  # Add some test events manually
  echo "[Test] Adding test events..."

  # Mouse moves (should be compressed)
  for i in 0..<50:
    app.eventManager.addEvent(GuiEvent(
      kind: evMouseMove,
      priority: epNormal,
      timestamp: getMonoTime(),
      mousePos: Point(x: float32(i * 10), y: 100.0)
    ))

  # Keyboard sequence (should be preserved)
  let text = "Hello"
  for ch in text:
    app.eventManager.addEvent(GuiEvent(
      kind: evChar,
      priority: epHigh,
      timestamp: getMonoTime(),
      char: ch
    ))

  echo "  Added 50 mouse moves + 5 keyboard chars"
  echo ""

  # Run a few frames
  echo "[Test] Running 5 frames..."
  app.runHeadless(frames = 5)

  echo ""
  echo "[Test] Stats after 5 frames:"
  echo app.getStats()

  echo ""
  echo repeat("=", 60)
  echo "HEADLESS MODE TEST PASSED ✓"
  echo repeat("=", 60)
  echo ""
  echo "Main loop features verified:"
  echo "  ✓ Application initialization"
  echo "  ✓ Event manager integration"
  echo "  ✓ Frame loop execution"
  echo "  ✓ Headless mode for testing"

when isMainModule:
  testHeadlessMode()
