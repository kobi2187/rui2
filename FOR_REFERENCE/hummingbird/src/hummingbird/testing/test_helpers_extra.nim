# src/quickui/testing/test_helpers_extra.nim

# Extended Test Setup
type
 TestSetup* = object
   app*: TestApp
   theme*: Theme
   screen*: ScreenInfo
   locale*: string
   debugMode*: bool
   mockTime*: bool
   recordEvents*: bool

 TestRecorder* = object
   stateChanges*: seq[StateChange]
   events*: seq[EventLog]
   renders*: seq[RenderInfo]
   errors*: seq[ErrorLog]

# Test Environment Setup
proc newTestSetup*(opts: TestSetupOptions = defaultTestSetup): TestSetup =
 ## Create complete test environment
 result = TestSetup(
   app: newTestApp(),
   theme: if opts.darkMode: darkTheme() else: lightTheme(),
   screen: ScreenInfo(
     width: opts.screenWidth,
     height: opts.screenHeight,
     density: opts.screenDensity
   ),
   locale: opts.locale,
   debugMode: opts.debugMode,
   mockTime: opts.mockTime,
   recordEvents: opts.recordEvents
 )

# Time Control
proc withMockTime*(test: proc(time: var float64)) =
 ## Run test with controlled time
 var mockTime = 0.0
 proc getTime(): float64 = mockTime
 withOverride(getTime, test(mockTime))

# Widget Tree Helpers
proc findWidgets*[T: Widget](root: Widget): seq[T] =
 ## Find all widgets of type T
 for child in root.traverseTree:
   if child of T:
     result.add(T(child))

proc findParent*[T: Widget](widget: Widget): Option[T] =
 ## Find first parent of type T
 var current = widget.parent
 while current != nil:
   if current of T:
     return some(T(current))
   current = current.parent
 none(T)

# Layout Testing Extensions
proc expectAlignment*(widget, reference: Widget, 
                    alignment: Alignment,
                    margin: float32 = 1.0) =
 ## Test widget alignment
 case alignment
 of aLeft:
   check abs(widget.rect.left - reference.rect.left) <= margin
 of aRight:
   check abs(widget.rect.right - reference.rect.right) <= margin
 of aTop:
   check abs(widget.rect.top - reference.rect.top) <= margin
 of aBottom:
   check abs(widget.rect.bottom - reference.rect.bottom) <= margin
 of aCenter:
   check abs(widget.rect.centerX - reference.rect.centerX) <= margin
   check abs(widget.rect.centerY - reference.rect.centerY) <= margin

proc expectInBounds*(widget: Widget, bounds: Rect, margin: float32 = 1.0) =
 ## Test widget is within bounds
 check widget.rect.left >= bounds.left - margin
 check widget.rect.right <= bounds.right + margin
 check widget.rect.top >= bounds.top - margin
 check widget.rect.bottom <= bounds.bottom + margin

# Event Simulation Extensions
proc simulateDrag*(widget: Widget, delta: Point) =
 ## Simulate drag gesture
 let start = widget.rect.center
 let end = start + delta
 
 widget.handleMouseDown(start)
 widget.handleMouseMove(end)
 widget.handleMouseUp(end)

proc simulateScroll*(widget: Widget, delta: float32) =
 ## Simulate scroll
 widget.handleScroll(ScrollEvent(
   delta: delta,
   position: widget.rect.center
 ))

proc simulateDoubleClick*(widget: Widget) =
 ## Simulate double click
 let pos = widget.rect.center
 widget.handleMouseDown(pos)
 widget.handleMouseUp(pos)
 widget.handleMouseDown(pos)
 widget.handleMouseUp(pos)

# State Testing Extensions
proc trackStateHistory*[T](state: Store[T]): seq[StateChange[T]] =
 ## Record detailed state change history
 result = @[]
 state.onChange = proc(old, new: T) =
   result.add StateChange[T](
     oldValue: old,
     newValue: new,
     timestamp: getTime()
   )

template withTemporaryState*[T](state: Store[T], value: T, body: untyped) =
 ## Run code with temporary state value
 let oldValue = state.get()
 state.set(value)
 try:
   body
 finally:
   state.set(oldValue)

# Theme Testing Extensions
proc verifyTheming*(widget: Widget, theme: Theme, 
                  checks: proc(style: Style)) =
 ## Test theming
 withTestTheme widget, theme:
   let style = widget.getComputedStyle()
   checks(style)

# Accessibility Testing Extensions
proc verifyAccessibilityTree*(root: Widget): AccessibilityInfo =
 ## Verify full accessibility tree
 result = AccessibilityInfo(
   role: root.accessibilityRole,
   label: root.accessibilityLabel,
   children: @[]
 )
 
 for child in root.children:
   result.children.add verifyAccessibilityTree(child)

# Mock Data Generation
proc generateTestData*[T](count: int, generator: proc(): T): seq[T] =
 ## Generate test data
 for i in 0..<count:
   result.add generator()

proc mockWidget*[T: Widget](props: varargs[(string, JsonNode)]): T =
 ## Create widget with mocked props
 result = T()
 for (name, value) in props:
   result.setProp(name, value)

# Error Testing
template expectError*(errorType: typedesc, body: untyped) =
 ## Test for specific error types
 var caught = false
 try:
   body
 except errorType:
   caught = true
 except:
   fail "Wrong error type caught"
 check caught

# Performance Testing Extensions
template benchmarkMemory*(name: string, body: untyped) =
 ## Benchmark memory usage
 let initialMem = getOccupiedMem()
 body
 let finalMem = getOccupiedMem()
 echo name, " memory delta: ", finalMem - initialMem, " bytes"

# Recording and Playback
type
 TestRecording* = object
   events*: seq[UIEvent]
   stateChanges*: seq[StateChange]
   time*: float64

proc recordTest*(test: proc()): TestRecording =
 ## Record test for playback
 result = TestRecording()
 let recorder = startRecording()
 test()
 result = recorder.getRecording()

proc replayTest*(recording: TestRecording) =
 ## Replay recorded test
 for event in recording.events:
   simulateEvent(event)
   advanceTime(event.timestamp - getCurrentTime())

# Example Usage:
suite "Complex Widget Testing":
 test "Data grid with filtering and sorting":
   # Setup test environment
   let setup = newTestSetup(
     screenWidth: 1024,
     screenHeight: 768,
     darkMode: true,
     recordEvents: true
   )

   withMockTime() do (time: var float64):
     testInteraction DataGrid():
       # Generate test data
       let data = generateTestData(100) do () -> RowData:
         RowData(
           id: rand(1..1000),
           name: $rand(1000),
           value: rand(100.0)
         )
       
       widget.data = data
       
       # Test sorting
       simulateClick(widget.getColumnHeader("value"))
       check isSorted(widget.getData(), "value", SortOrder.Ascending)
       
       # Test filtering
       widget.setFilter("value", FilterOp.GreaterThan, 50.0)
       check widget.getData().allIt(it.value > 50.0)
       
       # Test selection with recording
       let recording = recordTest:
         simulateClick(widget.getRow(0))
         simulateClick(widget.getRow(2), {ModControl})  # Multi-select
       
       check widget.selectedRows.len == 2
       
       # Verify layout
       verifyLayout widget:
         expectInBounds(widget, setup.screen.viewRect)
         
         # Check header alignment
         for header in widget.findWidgets[ColumnHeader]():
           expectAlignment(header, widget, aTop)
       
       # Verify accessibility
       let accTree = verifyAccessibilityTree(widget)
       check accTree.role == arGrid
       check accTree.children.len == widget.visibleRows.len