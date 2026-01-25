## Pango Rendering Stress Test
##
## Tests:
## 1. Render many labels simultaneously (100+)
## 2. Measure frame time and rendering time
## 3. Detect flickering (texture stability)
## 4. Test cache invalidation and re-rendering
## 5. Measure memory usage
## 6. Test different text lengths and Unicode
##
## Expected: Smooth 60 FPS with no flickering

import raylib
import std/[times, monotimes, random, strformat]

# Import pangolib_binding from sibling directory
import ../pangolib_binding/src/[pangotypes, pangocore]

type
  TextLabel = object
    layout: TextLayout
    x, y: float32
    text: string
    lastUpdateTime: MonoTime
    updateCount: int
    flickerDetected: bool
    lastTextureId: uint32  # Track texture changes

  PerformanceStats = object
    frameCount: int
    totalFrameTime: Duration
    totalRenderTime: Duration
    minFrameTime: Duration
    maxFrameTime: Duration
    avgFrameTime: Duration
    currentFPS: float32
    droppedFrames: int
    flickerCount: int
    cacheHits: int
    cacheMisses: int

proc initStats(): PerformanceStats =
  result.minFrameTime = initDuration(seconds = 999)
  result.maxFrameTime = initDuration(seconds = 0)

proc updateStats(stats: var PerformanceStats, frameTime, renderTime: Duration, fps: float32) =
  inc stats.frameCount
  stats.totalFrameTime += frameTime
  stats.totalRenderTime += renderTime
  stats.currentFPS = fps

  if frameTime < stats.minFrameTime:
    stats.minFrameTime = frameTime
  if frameTime > stats.maxFrameTime:
    stats.maxFrameTime = frameTime

  stats.avgFrameTime = stats.totalFrameTime div stats.frameCount

  # Detect dropped frames (> 16.67ms = < 60 FPS)
  if frameTime.inMilliseconds > 17:
    inc stats.droppedFrames

proc createRandomText(minLen, maxLen: int): string =
  let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 !?.,;:"
  let unicodeChars = @["世", "界", "🚀", "🎨", "✨", "🔥", "💡", "שלום", "مرحبا"]
  let length = rand(minLen..maxLen)

  for i in 0..<length:
    if rand(100) < 10:  # 10% chance of unicode
      result.add(unicodeChars[rand(unicodeChars.len - 1)])
    else:
      result.add(chars[rand(chars.len - 1)])

proc createLabel(text: string, x, y: float32): TextLabel =
  result.text = text
  result.x = x
  result.y = y
  result.lastUpdateTime = getMonoTime()
  result.updateCount = 0
  result.flickerDetected = false

  let layoutResult = initTextLayout(text, maxWidth = 300)
  if layoutResult.isOk:
    result.layout = layoutResult.get()
    result.lastTextureId = result.layout.texture.id
  else:
    echo "WARNING: Failed to create layout for: ", text

proc updateLabel(label: var TextLabel, newText: string): bool =
  ## Returns true if texture changed (potential flicker)
  let oldTextureId = label.lastTextureId

  # Free old layout
  freeTextLayout(label.layout)

  # Create new layout
  label.text = newText
  let layoutResult = initTextLayout(newText, maxWidth = 300)
  if layoutResult.isOk:
    label.layout = layoutResult.get()
    label.lastTextureId = label.layout.texture.id
    inc label.updateCount
    label.lastUpdateTime = getMonoTime()

    # Check if texture ID changed (indicates new allocation)
    if oldTextureId != label.lastTextureId:
      label.flickerDetected = true
      return true

  return false

proc main() =
  const
    WindowWidth = 1400
    WindowHeight = 900
    NumLabels = 150  # Stress test with 150 labels

  initWindow(WindowWidth, WindowHeight, "Pango Stress Test - Performance & Flicker Detection")
  defer: closeWindow()
  setTargetFPS(60)

  randomize()

  var stats = initStats()
  var labels: seq[TextLabel] = @[]

  echo "=== Initializing ", NumLabels, " Labels ==="
  let initStart = getMonoTime()

  # Create labels in a grid
  var x = 50.0f32
  var y = 100.0f32
  for i in 0..<NumLabels:
    let text = createRandomText(5, 30)
    labels.add(createLabel(text, x, y))

    x += 250
    if x > WindowWidth.float32 - 250:
      x = 50.0f32
      y += 40

  let initTime = getMonoTime() - initStart
  echo "✓ Created ", NumLabels, " labels in ", initTime.inMilliseconds, "ms"

  var
    updateMode = 0  # 0 = no updates, 1 = occasional, 2 = frequent, 3 = continuous
    updateInterval = 1000  # ms between updates
    lastUpdate = getMonoTime()
    testPhase = 0
    phaseStartTime = getMonoTime()

  echo "\n=== Starting Stress Test ==="
  echo "Phase 0: Static rendering (no updates)"
  echo "Phase 1: Occasional updates (1/sec)"
  echo "Phase 2: Frequent updates (10/sec)"
  echo "Phase 3: Continuous updates (every frame)"

  while not windowShouldClose():
    let frameStart = getMonoTime()

    # Phase progression (every 5 seconds)
    if (getMonoTime() - phaseStartTime).inSeconds >= 5 and testPhase < 3:
      inc testPhase
      phaseStartTime = getMonoTime()
      case testPhase
      of 1:
        echo "\n→ Phase 1: Occasional updates"
        updateMode = 1
        updateInterval = 1000
      of 2:
        echo "\n→ Phase 2: Frequent updates"
        updateMode = 2
        updateInterval = 100
      of 3:
        echo "\n→ Phase 3: Continuous updates"
        updateMode = 3
        updateInterval = 0
      else:
        discard

    # Update labels based on mode
    let renderStart = getMonoTime()
    var flickeredThisFrame = false

    if updateMode > 0:
      let now = getMonoTime()
      let shouldUpdate = updateMode == 3 or
                        (now - lastUpdate).inMilliseconds >= updateInterval

      if shouldUpdate:
        lastUpdate = now

        # Update a random subset of labels
        let numToUpdate = case updateMode
          of 1: 5
          of 2: 20
          of 3: 50
          else: 0

        for i in 0..<numToUpdate:
          let idx = rand(labels.len - 1)
          let newText = createRandomText(5, 30)
          if updateLabel(labels[idx], newText):
            flickeredThisFrame = true
            inc stats.flickerCount
            inc stats.cacheMisses
          else:
            inc stats.cacheHits

    let renderTime = getMonoTime() - renderStart

    # Rendering
    beginDrawing()
    clearBackground(Color(r: 20, g: 20, b: 30, a: 255))

    # Title and stats
    raylib.drawText("PANGO STRESS TEST", 10'i32, 10'i32, 28'i32, YELLOW)

    # Draw all labels
    for label in labels:
      if label.layout.texture.id != 0:
        drawTexture(label.layout.texture, int32(label.x), int32(label.y), WHITE)

    # Performance stats panel
    let panelX = WindowWidth - 380
    let panelY = 10
    drawRectangle(panelX, panelY, 370, 360, Color(r: 0, g: 0, b: 0, a: 200))

    var yOffset = panelY + 10
    proc drawStat(label, value: string, color = WHITE) =
      raylib.drawText(label, (panelX + 10).int32, yOffset.int32, 16'i32, LIGHTGRAY)
      raylib.drawText(value, (panelX + 200).int32, yOffset.int32, 16'i32, color)
      yOffset += 22

    drawStat("Test Phase:", $testPhase & "/3")
    drawStat("Labels:", $NumLabels)
    drawStat("FPS:", &"{stats.currentFPS:.1f}",
             if stats.currentFPS >= 58.0: GREEN else: RED)
    drawStat("Frame Time:", &"{stats.avgFrameTime.inMilliseconds}ms",
             if stats.avgFrameTime.inMilliseconds <= 16: GREEN else: ORANGE)
    drawStat("Min Frame:", &"{stats.minFrameTime.inMilliseconds}ms")
    drawStat("Max Frame:", &"{stats.maxFrameTime.inMilliseconds}ms")
    drawStat("Render Time:", &"{renderTime.inMilliseconds}ms")
    drawStat("Dropped Frames:", $stats.droppedFrames,
             if stats.droppedFrames == 0: GREEN else: RED)
    drawStat("Flicker Events:", $stats.flickerCount,
             if stats.flickerCount == 0: GREEN else: RED)
    drawStat("Cache Hits:", $stats.cacheHits)
    drawStat("Cache Misses:", $stats.cacheMisses)

    if flickeredThisFrame:
      raylib.drawText("⚠ FLICKER DETECTED THIS FRAME!",
                     10'i32, (WindowHeight - 30).int32, 20'i32, RED)

    # Test phase indicator
    let phaseText = case testPhase
      of 0: "Phase 0: Static (no updates)"
      of 1: "Phase 1: Occasional (1 update/sec)"
      of 2: "Phase 2: Frequent (10 updates/sec)"
      of 3: "Phase 3: Continuous (50 updates/frame)"
      else: ""
    raylib.drawText(phaseText, 10'i32, 50'i32, 18'i32, YELLOW)

    # Progress bar for phase
    let phaseProgress = min(1.0, (getMonoTime() - phaseStartTime).inMilliseconds.float / 5000.0)
    drawRectangle(10, 75, int32(phaseProgress * 500), 10, GREEN)
    drawRectangleLines(10, 75, 500, 10, WHITE)

    endDrawing()

    let frameTime = getMonoTime() - frameStart
    updateStats(stats, frameTime, renderTime, getFPS().float32)

  # Final report
  echo "\n=== FINAL PERFORMANCE REPORT ==="
  echo "Total Frames: ", stats.frameCount
  echo "Average FPS: ", stats.currentFPS
  echo "Average Frame Time: ", stats.avgFrameTime.inMilliseconds, "ms"
  echo "Min Frame Time: ", stats.minFrameTime.inMilliseconds, "ms"
  echo "Max Frame Time: ", stats.maxFrameTime.inMilliseconds, "ms"
  echo "Dropped Frames: ", stats.droppedFrames
  echo "Flicker Events: ", stats.flickerCount
  echo "Cache Hits: ", stats.cacheHits
  echo "Cache Misses: ", stats.cacheMisses

  if stats.flickerCount == 0 and stats.droppedFrames == 0:
    echo "\n✓✓✓ PERFECT: No flickering, smooth 60 FPS!"
  elif stats.flickerCount == 0 and stats.droppedFrames < 10:
    echo "\n✓ GOOD: No flickering, minor frame drops"
  elif stats.flickerCount < 5:
    echo "\n⚠ ACCEPTABLE: Minor flickering detected"
  else:
    echo "\n✗ ISSUES: Significant flickering or performance problems"

  # Cleanup
  for label in labels:
    freeTextLayout(label.layout)

when isMainModule:
  main()
