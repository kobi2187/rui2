## Visual Test - RUI Main Loop with Graphics
##
## Simple visual application to demonstrate:
## - Event collection from Raylib
## - Reactive Link[T] updates
## - Frame rendering
## - FPS display

import ../../core/[types, link, app]
when defined(useGraphics):
  import raylib  # Need raylib types for KeyboardKey

when defined(useGraphics):
  proc main() =
    echo "Starting RUI Visual Test..."

    # Create application
    let app = newApp(
      title = "RUI Visual Test - Press SPACE to increment",
      width = 600,
      height = 400,
      fps = 60
    )

    # Create store with reactive data
    type TestStore = ref object of Store
      counter: Link[int]
      mouseClicks: Link[int]

    let store = TestStore(
      counter: newLink(0),
      mouseClicks: newLink(0)
    )

    # Set up onChange callbacks for demonstration
    store.counter.setOnChange proc(old, new: int) =
      echo "Counter changed: ", old, " → ", new

    store.mouseClicks.setOnChange proc(old, new: int) =
      echo "Mouse clicks: ", new

    app.setStore(store)

    # Override event handler to update our store
    let originalHandler = proc(event: GuiEvent) =
      case event.kind
      of evKeyDown:
        # Check if Space key (value 32 in KeyboardKey enum)
        if event.key == KeyboardKey(32):  # Space key
          store.counter.value += 1

      of evMouseDown:
        store.mouseClicks.value += 1

      else:
        discard

    # Inject custom rendering (monkey-patch for demo)
    # In real app, this would be in render manager
    import naylib

    proc customRender(appInst: App) =
      beginDrawing()
      clearBackground(Color(r: 30, g: 30, b: 46, a: 255))  # Dark background

      # Title
      drawText("RUI Framework - Visual Test", 20, 20, 24, RayWhite)

      # Instructions
      drawText("Press SPACE to increment counter", 20, 60, 18, LightGray)
      drawText("Click mouse to count clicks", 20, 85, 18, LightGray)

      # Display counter (from reactive Link)
      let counterText = "Counter: " & $store.counter.value
      drawText(cstring(counterText), 20, 140, 32, Yellow)

      # Display mouse clicks
      let clicksText = "Mouse Clicks: " & $store.mouseClicks.value
      drawText(cstring(clicksText), 20, 190, 32, Green)

      # FPS and stats
      drawText(cstring("FPS: " & $appInst.currentFPS), 20, 260, 20, Lime)
      drawText(cstring("Events in queue: " & $appInst.eventManager.queueLength), 20, 290, 16, SkyBlue)

      # Event stats
      let stats = appInst.eventManager.getStats()
      var y = 320'i32
      for line in stats.split('\n'):
        if line.len > 0 and y < 390:
          drawText(line, 20'i32, y, 12'i32, Gray)
          y += 14

      endDrawing()

    # Run the application with custom handler
    echo "Application initialized"
    echo "Press ESC to quit"
    echo ""

    # Standard run would be: app.run()
    # But we need custom rendering, so inline it:

    import naylib
    initWindow(app.window.width.int32, app.window.height.int32, app.window.title)
    setTargetFPS(app.window.fps.int32)

    while not windowShouldClose() and not app.shouldClose:
      # Collect events
      when declared(collectRaylibEvents):
        app.collectRaylibEvents()

      # Process
      app.eventManager.update()
      discard app.eventManager.processEvents(
        app.eventManager.currentBudget,
        originalHandler
      )

      # Layout (would run if dirty)
      if app.tree.anyDirty:
        app.tree.anyDirty = false

      # Custom render
      customRender(app)

    closeWindow()
    echo "Application closed"

else:
  proc main() =
    echo "ERROR: This example requires graphics"
    echo "Compile with: nim c -d:useGraphics -r visual_test.nim"

when isMainModule:
  main()
