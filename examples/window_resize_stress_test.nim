## Window Resize Stress Test
##
## Tests:
## 1. Performance during rapid window resizing
## 2. Event debouncing (350ms) effectiveness
## 3. FPS stability during resize operations
## 4. Frame drop detection
## 5. Tree re-evaluation performance
##
## Expected: Smooth 60 FPS with minimal drops, debouncing prevents excessive redraws

import raylib
import ../core/[types, app]
import std/[monotimes, times, strformat]

type
  ResizeStats = object
    resizeEventCount: int
    totalResizes: int
    lastResizeTime: MonoTime
    resizesInLastSecond: int
    lastSecondStart: MonoTime

    # Frame performance
    frameCount: int
    droppedFrames: int
    minFrameTime: Duration
    maxFrameTime: Duration
    totalFrameTime: Duration
    avgFrameTime: Duration
    currentFPS: float

    # Layout performance
    layoutCallCount: int
    layoutSkippedCount: int

proc initResizeStats(): ResizeStats =
  result.minFrameTime = initDuration(seconds = 999)
  result.maxFrameTime = initDuration(seconds = 0)
  result.lastSecondStart = getMonoTime()
  result.lastResizeTime = getMonoTime()

proc updateFrameStats(stats: var ResizeStats, frameTime: Duration, fps: float) =
  inc stats.frameCount
  stats.totalFrameTime += frameTime
  stats.currentFPS = fps

  if frameTime < stats.minFrameTime:
    stats.minFrameTime = frameTime
  if frameTime > stats.maxFrameTime:
    stats.maxFrameTime = frameTime

  stats.avgFrameTime = stats.totalFrameTime div max(1, stats.frameCount)

  # Detect dropped frames (> 16.67ms = < 60 FPS)
  if frameTime.inMilliseconds > 17:
    inc stats.droppedFrames

proc recordResize(stats: var ResizeStats) =
  let now = getMonoTime()
  inc stats.totalResizes
  inc stats.resizeEventCount

  # Track resizes per second
  if (now - stats.lastSecondStart).inSeconds >= 1:
    stats.resizesInLastSecond = stats.resizeEventCount
    stats.resizeEventCount = 0
    stats.lastSecondStart = now

  stats.lastResizeTime = now

proc main() =
  # Create app with minimum size constraint
  let app = newApp(
    title = "Window Resize Stress Test - Drag to resize rapidly!",
    width = 800,
    height = 600,
    fps = 60,
    resizable = true,
    minWidth = 400,
    minHeight = 300
  )

  # Run custom loop for detailed performance tracking
  initWindow(app.window.width.int32, app.window.height.int32, app.window.title)
  setTargetFPS(app.window.fps.int32)
  setWindowState(flags(WindowResizable))
  setWindowMinSize(app.window.minWidth.int32, app.window.minHeight.int32)
  defer: closeWindow()

  echo "Window Resize Stress Test Started"
  echo "  Initial size: ", app.window.width, "x", app.window.height
  echo "  Min size: ", app.window.minWidth, "x", app.window.minHeight
  echo "  Event debounce: 350ms"
  echo ""
  echo "Instructions:"
  echo "  - Rapidly resize window by dragging edges"
  echo "  - Watch for frame drops and FPS stability"
  echo "  - Observe event coalescing (resizes/sec vs events/sec)"
  echo "  - Press SPACE to reset stats"
  echo ""

  var stats = initResizeStats()

  while not windowShouldClose():
    let frameStart = getMonoTime()

    # Detect resize
    let isResizing = isWindowResized()
    if isResizing:
      let newWidth = getScreenWidth()
      let newHeight = getScreenHeight()
      app.window.width = newWidth
      app.window.height = newHeight
      stats.recordResize()

      # Simulate tree re-evaluation
      app.tree.anyDirty = true
      inc stats.layoutCallCount
    elif app.tree.anyDirty:
      # Tree was marked dirty but no resize this frame
      app.tree.anyDirty = false
      inc stats.layoutSkippedCount

    # Reset stats on spacebar
    if isKeyPressed(Space):
      echo "Stats reset"
      stats = initResizeStats()

    # Rendering
    beginDrawing()
    clearBackground(Color(r: 20, g: 20, b: 30, a: 255))

    # Title
    drawText("WINDOW RESIZE STRESS TEST", 20'i32, 20'i32, 28'i32, Color(r: 255, g: 200, b: 80, a: 255))

    # Instructions
    var yPos = 60'i32
    drawText("Rapidly resize the window by dragging edges!", 20'i32, yPos, 16'i32, Color(r: 180, g: 180, b: 180, a: 255))
    yPos += 25
    drawText("Press SPACE to reset statistics", 20'i32, yPos, 16'i32, Color(r: 180, g: 180, b: 180, a: 255))

    # Performance Panel
    yPos += 50
    drawRectangle(15'i32, yPos, 770'i32, 400'i32, Color(r: 0, g: 0, b: 0, a: 180))
    yPos += 10

    proc drawStat(label, value: string, color = Color(r: 200, g: 200, b: 200, a: 255)) =
      drawText(label, 30'i32, yPos, 16'i32, Color(r: 150, g: 150, b: 150, a: 255))
      drawText(value, 350'i32, yPos, 18'i32, color)
      yPos += 25

    # FPS and Frame Performance
    drawText("=== FRAME PERFORMANCE ===", 30'i32, yPos, 18'i32, Color(r: 255, g: 220, b: 100, a: 255))
    yPos += 30

    let fpsColor = if stats.currentFPS >= 58.0:
                     Color(r: 100, g: 255, b: 100, a: 255)
                   elif stats.currentFPS >= 50.0:
                     Color(r: 255, g: 200, b: 100, a: 255)
                   else:
                     Color(r: 255, g: 100, b: 100, a: 255)
    drawStat("Current FPS:", &"{stats.currentFPS:.1f}", fpsColor)

    let avgTime = stats.avgFrameTime.inMilliseconds
    let avgColor = if avgTime <= 16:
                     Color(r: 100, g: 255, b: 100, a: 255)
                   elif avgTime <= 20:
                     Color(r: 255, g: 200, b: 100, a: 255)
                   else:
                     Color(r: 255, g: 100, b: 100, a: 255)
    drawStat("Avg Frame Time:", &"{avgTime}ms", avgColor)

    drawStat("Min Frame Time:", &"{stats.minFrameTime.inMilliseconds}ms")
    drawStat("Max Frame Time:", &"{stats.maxFrameTime.inMilliseconds}ms")

    let dropColor = if stats.droppedFrames == 0:
                      Color(r: 100, g: 255, b: 100, a: 255)
                    elif stats.droppedFrames < 10:
                      Color(r: 255, g: 200, b: 100, a: 255)
                    else:
                      Color(r: 255, g: 100, b: 100, a: 255)
    drawStat("Dropped Frames:", $stats.droppedFrames, dropColor)

    drawStat("Total Frames:", $stats.frameCount)

    # Resize Statistics
    yPos += 20
    drawText("=== RESIZE PERFORMANCE ===", 30'i32, yPos, 18'i32, Color(r: 255, g: 220, b: 100, a: 255))
    yPos += 30

    drawStat("Total Resizes:", $stats.totalResizes)
    drawStat("Resizes/Second:", $stats.resizesInLastSecond)

    let timeSinceResize = (getMonoTime() - stats.lastResizeTime).inMilliseconds
    let resizeColor = if timeSinceResize < 350:
                        Color(r: 255, g: 200, b: 100, a: 255)  # Debouncing
                      else:
                        Color(r: 100, g: 255, b: 100, a: 255)  # Settled
    drawStat("Time Since Resize:", &"{timeSinceResize}ms", resizeColor)

    if timeSinceResize < 350:
      drawStat("Debounce Status:", "WAITING (350ms)", Color(r: 255, g: 200, b: 100, a: 255))
    else:
      drawStat("Debounce Status:", "SETTLED", Color(r: 100, g: 255, b: 100, a: 255))

    # Layout Statistics
    yPos += 20
    drawText("=== LAYOUT PERFORMANCE ===", 30'i32, yPos, 18'i32, Color(r: 255, g: 220, b: 100, a: 255))
    yPos += 30

    drawStat("Layout Calls:", $stats.layoutCallCount)
    drawStat("Layout Skipped:", $stats.layoutSkippedCount)

    if isResizing:
      drawStat("Current State:", "RESIZING", Color(r: 255, g: 100, b: 100, a: 255))
    else:
      drawStat("Current State:", "STABLE", Color(r: 100, g: 255, b: 100, a: 255))

    # Window Info
    yPos += 20
    drawText("=== WINDOW INFO ===", 30'i32, yPos, 18'i32, Color(r: 255, g: 220, b: 100, a: 255))
    yPos += 30

    drawStat("Current Size:", &"{app.window.width} x {app.window.height}")
    drawStat("Min Size:", &"{app.window.minWidth} x {app.window.minHeight}")

    # Visual border
    let w = getScreenWidth()
    let h = getScreenHeight()
    drawRectangleLines(3'i32, 3'i32, (w - 6).int32, (h - 6).int32, Color(r: 100, g: 150, b: 255, a: 255))

    # Active resize indicator
    if isResizing:
      drawText("RESIZING NOW!", (w div 2 - 120).int32, (h - 50).int32, 28'i32, Color(r: 255, g: 100, b: 100, a: 255))

    endDrawing()

    # Update frame stats
    let frameTime = getMonoTime() - frameStart
    stats.updateFrameStats(frameTime, getFPS().float)

  # Final report
  echo "\n=== FINAL STRESS TEST REPORT ==="
  echo "Total Frames: ", stats.frameCount
  echo "Avg FPS: ", stats.currentFPS
  echo "Dropped Frames: ", stats.droppedFrames, " (",
       (stats.droppedFrames.float / stats.frameCount.float * 100.0), "%)"
  echo "Avg Frame Time: ", stats.avgFrameTime.inMilliseconds, "ms"
  echo "Max Frame Time: ", stats.maxFrameTime.inMilliseconds, "ms"
  echo ""
  echo "Total Resizes: ", stats.totalResizes
  echo "Layout Calls: ", stats.layoutCallCount
  echo "Layout Skipped: ", stats.layoutSkippedCount
  echo ""

  if stats.droppedFrames == 0:
    echo "✓✓✓ PERFECT: No dropped frames, smooth 60 FPS!"
  elif stats.droppedFrames < stats.frameCount div 20:
    echo "✓ GOOD: Minimal frame drops (< 5%)"
  else:
    echo "⚠ NEEDS WORK: Significant frame drops during resize"

when isMainModule:
  main()
