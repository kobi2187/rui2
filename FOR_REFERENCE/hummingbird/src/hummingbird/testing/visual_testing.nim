# src/quickui/testing/visual_testing.nim
type
  WidgetSnapshot* = object
    pixels*: seq[Color]  # Rasterized content
    size*: tuple[w, h: int]
    timestamp*: float64
    widgetPath*: string

  RenderSequence* = object
    snapshots*: seq[WidgetSnapshot]
    events*: seq[UIEvent]
    timings*: seq[float64]
    performanceMetrics*: PerformanceMetrics

  PerformanceMetrics* = object
    frameDeltas*: seq[float64]
    renderTimes*: seq[float64]
    skippedFrames*: int
    maxFrameTime*: float64
    avgFrameTime*: float64

# Snapshot Creation
proc rasterizeWidget*(widget: Widget): WidgetSnapshot =
  ## Create pixel-perfect snapshot of widget
  let rect = widget.getBoundingRect()
  let renderTexture = newRenderTexture(rect.width.int, rect.height.int)
  
  beginTextureMode(renderTexture):
    clearBackground(BLANK)
    # Render widget hierarchy
    widget.render()
  
  result = WidgetSnapshot(
    pixels: renderTexture.getPixelData(),
    size: (rect.width.int, rect.height.int),
    timestamp: getCurrentTime(),
    widgetPath: widget.getPath()
  )

# Sequence Recording
proc recordInteractionSequence*(
  widget: Widget,
  events: seq[UIEvent],
  normalDelay = 0.5,  # Normal human-like delay
  stressDelay = 0.016 # Single frame delay for stress test
): tuple[normal, stress: RenderSequence] =
  ## Record same interaction sequence with different timings
  
  proc runSequence(delay: float64): RenderSequence =
    result = RenderSequence()
    var lastFrameTime = getCurrentTime()
    
    for event in events:
      # Take snapshot before event
      result.snapshots.add(rasterizeWidget(widget))
      result.events.add(event)
      result.timings.add(getCurrentTime())
      
      # Process event
      widget.handleEvent(event)
      
      # Measure frame time
      let frameTime = getCurrentTime() - lastFrameTime
      result.performanceMetrics.frameDeltas.add(frameTime)
      
      if frameTime > 0.016:  # 60 FPS target
        inc result.performanceMetrics.skippedFrames
      
      result.performanceMetrics.renderTimes.add(frameTime)
      result.performanceMetrics.maxFrameTime = max(
        result.performanceMetrics.maxFrameTime, 
        frameTime
      )
      
      # Wait specified delay
      sleep(delay)
      lastFrameTime = getCurrentTime()
    
    # Final snapshot
    result.snapshots.add(rasterizeWidget(widget))
    
    # Calculate average frame time
    result.performanceMetrics.avgFrameTime = 
      mean(result.performanceMetrics.renderTimes)

  # Run both sequences
  (
    normal: runSequence(normalDelay),
    stress: runSequence(stressDelay)
  )

# Analysis
proc compareSnapshots*(a, b: WidgetSnapshot): float64 =
  ## Compare snapshots, returns difference percentage (0-1)
  var differences = 0
  for i in 0..<a.pixels.len:
    if a.pixels[i] != b.pixels[i]:
      inc differences
  result = differences.float64 / a.pixels.len.float64

proc analyzeRenderSequences*(
  normal, stress: RenderSequence
): tuple[visualDifferences: seq[float64], performanceIssues: seq[string]] =
  ## Compare normal and stress sequences
  for i in 0..<min(normal.snapshots.len, stress.snapshots.len):
    let difference = compareSnapshots(
      normal.snapshots[i],
      stress.snapshots[i]
    )
    result.visualDifferences.add(difference)
    
    # Report significant differences
    if difference > 0.01:  # More than 1% different
      result.performanceIssues.add fmt"Visual inconsistency at event {i}: {difference*100:.2f}% different"
  
  # Analyze performance metrics
  if stress.performanceMetrics.skippedFrames > 0:
    result.performanceIssues.add fmt"Skipped {stress.performanceMetrics.skippedFrames} frames under stress"
  
  if stress.performanceMetrics.maxFrameTime > 0.032:  # 30 FPS minimum
    result.performanceIssues.add fmt"Max frame time too high: {stress.performanceMetrics.maxFrameTime*1000:.2f}ms"

# Usage Example
suite "Visual Coherence Tests":
  test "Complex form interaction remains coherent under stress":
    let form = ComplexForm()
    
    # Create test event sequence
    let events = @[
      UIEvent(kind: evtClick, position: form.getSubmitButton().center),
      UIEvent(kind: evtTextInput, text: "Test input"),
      UIEvent(kind: evtScroll, delta: 100),
      UIEvent(kind: evtClick, position: form.getDropdown().center),
      UIEvent(kind: evtResize, newSize: (800, 600))
    ]
    
    # Record both sequences
    let sequences = recordInteractionSequence(form, events)
    
    # Analyze results
    let analysis = analyzeRenderSequences(
      sequences.normal,
      sequences.stress
    )
    
    # Report issues
    check analysis.performanceIssues.len == 0
    
    for i, diff in analysis.visualDifferences:
      check diff < 0.01, fmt"Visual difference at step {i}: {diff*100:.2f}%"

  test "Data grid stays consistent during rapid scrolling":
    let grid = DataGrid()
    grid.data = generateTestData(1000)
    
    var events: seq[UIEvent]
    # Simulate scroll sequence
    for delta in countup(0, 1000, 100):
      events.add UIEvent(
        kind: evtScroll,
        delta: delta.float
      )
    
    let sequences = recordInteractionSequence(grid, events)
    let analysis = analyzeRenderSequences(
      sequences.normal,
      sequences.stress
    )
    
    check analysis.performanceIssues.len == 0

# For debugging visual issues
proc saveSnapshotDiff*(a, b: WidgetSnapshot, path: string) =
  ## Save visual difference as image for inspection
  var diffImage = newImage(a.size.w, a.size.h)
  
  for y in 0..<a.size.h:
    for x in 0..<a.size.w:
      let i = y * a.size.w + x
      if a.pixels[i] != b.pixels[i]:
        diffImage[x, y] = RED
      else:
        diffImage[x, y] = a.pixels[i]
  
  diffImage.saveToFile(path)