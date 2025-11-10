# src/quickui/testing/test_helpers.nim
import unittest, macros, json
import ../core/[types, widget, state]
import ../themes/types
import ../layout/constraints

type
  TestApp* = ref object
    ## Helper for setting up test environment
    root*: Widget
    theme*: Theme
    time*: float
    mousePos*: Point
    keyboardState*: set[Key]
    activeWidget*: Widget

  WidgetTestContext* = object
    ## Context for widget-specific tests
    widget*: Widget
    parent*: Widget
    app*: TestApp
    events*: seq[UIEvent]

# App Setup Helpers
proc newTestApp*(): TestApp =
  ## Create test environment
  result = TestApp(
    root: Panel(),
    theme: defaultTheme(),
    time: 0.0
  )

proc withTheme*(app: TestApp, theme: Theme): TestApp =
  result = app
  result.theme = theme

# Widget Testing
proc testWidget*[T: Widget](widget: T, 
                          setup: proc(ctx: var WidgetTestContext)): WidgetTestContext =
  ## Setup widget test environment
  result = WidgetTestContext(
    widget: widget,
    parent: Panel(),
    app: newTestApp()
  )
  setup(result)

# Macro Testing
proc compareAst*(generated, expected: NimNode): bool =
  ## Compare generated vs expected AST
  result = sameStructure(generated, expected)

template expectMacroOutput*(macroCall, expected: untyped) =
  ## Test macro output
  let generatedAst = getAst(macroCall)
  let expectedAst = getAst(expected)
  check compareAst(generatedAst, expectedAst)

# State Testing
proc trackStateChanges*[T](state: Store[T]): seq[T] =
  ## Record state changes
  result = @[state.get()]
  state.onChange = proc(newValue: T) =
    result.add(newValue)

template expectStateChange*[T](state: Store[T], change: untyped, expected: T) =
  ## Test state changes
  let initialValue = state.get()
  change
  check state.get() == expected

# Layout Testing
proc verifyLayout*(widget: Widget, checks: proc()) =
  ## Test layout results
  widget.solveLayout()
  checks()

proc expectPosition*(widget: Widget, x, y: float32) =
  ## Check widget position
  check widget.rect.x == x
  check widget.rect.y == y

proc expectSize*(widget: Widget, width, height: float32) =
  ## Check widget size
  check widget.rect.width == width
  check widget.rect.height == height

# Event Simulation
proc simulateClick*(widget: Widget) =
  ## Simulate mouse click
  let center = widget.rect.center
  widget.handleMouseDown(center)
  widget.handleMouseUp(center)

proc simulateHover*(widget: Widget) =
  ## Simulate mouse hover
  widget.handleMouseMove(widget.rect.center)

proc simulateKeyPress*(key: Key, modifiers: set[Key] = {}) =
  ## Simulate keyboard input
  let event = KeyEvent(
    key: key,
    modifiers: modifiers
  )
  app.handleKeyPress(event)

proc simulateGesture*(start, finish: Point, duration = 0.3) =
  ## Simulate touch gesture
  var event = TouchEvent(
    kind: teTouchBegin,
    position: start
  )
  app.handleTouchEvent(event)
  
  # Simulate movement
  let steps = 10
  for i in 1..steps:
    let t = i.float32 / steps.float32
    event.position = lerp(start, finish, t)
    event.kind = teTouchMove
    app.handleTouchEvent(event)
  
  event.kind = teTouchEnd
  event.position = finish
  app.handleTouchEvent(event)

# Theme Testing
proc withTestTheme*(widget: Widget, theme: Theme, test: proc()) =
  ## Test with temporary theme
  let oldTheme = widget.theme
  widget.theme = theme
  test()
  widget.theme = oldTheme

# Query Testing
proc queryWidget*(path: string): Widget =
  ## Find widget by path
  result = app.root.findWidget(path)

proc expectWidgetState*(path: string, checks: proc(state: JsonNode)) =
  ## Test widget state
  let state = queryState(path)
  checks(state)

# Animation Testing
proc advanceTime*(delta: float) =
  ## Advance animation time
  app.time += delta
  app.updateAnimations()

template expectAnimationCompletion*(anim: Animation, timeout = 1.0) =
  ## Test animation completion
  var elapsed = 0.0
  while not anim.isCompleted and elapsed < timeout:
    advanceTime(0.016)  # One frame
    elapsed += 0.016
  check anim.isCompleted

# Resource Testing
proc trackResources*(test: proc()) =
  ## Track resource allocation
  let initial = getResourceCount()
  test()
  GC_fullCollect()
  check getResourceCount() == initial

# Accessibility Testing
proc expectAccessible*(widget: Widget) =
  ## Test accessibility properties
  check widget.accessibilityLabel.len > 0
  check widget.accessibilityRole != arNone

# Performance Testing
template benchmark*(name: string, test: untyped) =
  ## Simple benchmark
  let start = epochTime()
  test
  let duration = epochTime() - start
  echo name, ": ", duration * 1000, "ms"

# Common Test Patterns
template testInteraction*(widget: Widget, body: untyped) =
  ## Test widget interactions
  let ctx = WidgetTestContext(
    widget: widget,
    app: newTestApp()
  )
  body

# Example usage:
suite "Button Tests":
  test "Click handling":
    testInteraction Button():
      var clicked = false
      widget.onClick = proc() = clicked = true
      
      simulateClick(widget)
      check clicked

suite "Layout Tests":
  test "Center constraint":
    let parent = Panel(width: 400, height: 400)
    let child = Panel(width: 100, height: 100)
    
    verifyLayout child:
      center in parent
    do:
      expectPosition(child, 150, 150)

suite "Theme Tests":
  test "Theme change":
    let button = Button()
    withTestTheme(button, darkTheme):
      check button.getComputedStyle().backgroundColor == 
        darkTheme.colors.primary

suite "State Tests":
  test "Counter state":
    let counter = Store[int](value: 0)
    let changes = trackStateChanges(counter)
    
    expectStateChange counter:
      counter.set(counter.get() + 1)
    do: 1

# More testing helpers and examples

# Debug Helpers
type
 DebugInfo* = object
   widgetTree*: string
   layoutInfo*: string
   stateChanges*: seq[StateChange]
   eventLog*: seq[EventLog]
   constraintViolations*: seq[ConstraintViolation]

 StateChange* = object
   path*: string
   oldValue*, newValue*: JsonNode
   timestamp*: float

 EventLog* = object
   kind*: EventKind
   widget*: string
   data*: JsonNode
   timestamp*: float

 ConstraintViolation* = object
   widget*: string
   constraint*: string
   expected*, actual*: float32

proc dumpWidgetTree*(widget: Widget, indent = 0): string =
 ## Create debug view of widget hierarchy
 result = repeat("  ", indent) & widget.id & ":\n"
 result &= repeat("  ", indent + 1) & 
   fmt"pos: ({widget.rect.x}, {widget.rect.y})\n"
 result &= repeat("  ", indent + 1) & 
   fmt"size: {widget.rect.width}x{widget.rect.height}\n"
 
 for child in widget.children:
   result &= dumpWidgetTree(child, indent + 1)

proc debugLayout*(widget: Widget): string =
 ## Show layout debug info
 result = "Layout Debug:\n"
 result &= fmt"Widget: {widget.id}\n"
 result &= fmt"Position: ({widget.rect.x}, {widget.rect.y})\n"
 result &= fmt"Size: {widget.rect.width}x{widget.rect.height}\n"
 result &= "Constraints:\n"
 for c in widget.constraints:
   result &= fmt"  {c}\n"

proc startDebugLog*(): DebugInfo =
 ## Start collecting debug info
 result = DebugInfo()
 app.onStateChange = proc(change: StateChange) =
   result.stateChanges.add(change)
 app.onEvent = proc(event: EventLog) =
   result.eventLog.add(event)

# Usage Examples

suite "Complex Widget Tests":
 test "Data grid with sorting and filtering":
   # Set up test data
   let data = @[
     {"id": %1, "name": %"Alice", "age": %25},
     {"id": %2, "name": %"Bob", "age": %30},
     {"id": %3, "name": %"Charlie", "age": %20}
   ]

   testInteraction DataGrid():
     # Configure grid
     widget.columns = @[
       Column(field: "name", sortable: true),
       Column(field: "age", sortable: true)
     ]
     widget.data = data

     # Test sorting
     simulateClick(widget.getColumnHeader("age"))
     check widget.getData()[0]["age"].getInt == 20

     # Test filtering
     widget.setFilter("age", FilterOp.Greater, 25)
     check widget.getData().len == 2

     # Test selection
     simulateClick(widget.getRow(0))
     check widget.selectedIndices == @[0]

 test "Form validation":
   testInteraction Form():
     # Add form fields
     widget.addField TextField(
       id: "email",
       validator: proc(value: string): bool =
         value.contains('@')
     )
     widget.addField NumberInput(
       id: "age",
       min: 0,
       max: 120
     )

     # Test validation
     widget.setFieldValue("email", "invalid")
     check not widget.validate()
     check "email" in widget.errors

     widget.setFieldValue("email", "test@example.com")
     check widget.validate()

 test "Drag and drop":
   testInteraction DragDropList():
     # Setup list
     widget.items = @["Item 1", "Item 2", "Item 3"]

     # Start drag
     let startPos = widget.getItemRect(0).center
     let endPos = widget.getItemRect(2).center
     
     simulateGesture(startPos, endPos)
     
     # Verify reorder
     check widget.items == @["Item 2", "Item 3", "Item 1"]

suite "Layout Debug Tests":
 test "Complex layout debugging":
   let debugLog = startDebugLog()
   
   testInteraction Panel():
     # Create complex layout
     layout:
       widget:
         width = 400
         height = 300

         hstack:
           spacing = 16
           
           sidebar:
             width = 100
             height = fill
           
           vstack:
             width = fill
             height = fill
             spacing = 8
             
             header:
               height = 40
             
             content:
               width = fill
               height = fill

     # Debug layout
     echo debugLayout(widget)
     
     # Verify layout
     verifyLayout widget:
       # Get computed layout info
       let info = debugLayout(widget)
       check "width = 400" in info
       check "sidebar width = 100" in info

     # Check constraint violations
     for violation in debugLog.constraintViolations:
       echo fmt"Violation in {violation.widget}: {violation.constraint}"
       echo fmt"Expected: {violation.expected}, Got: {violation.actual}"

suite "State Debugging":
 test "Track complex state changes":
   let debugLog = startDebugLog()
   
   testInteraction TodoApp():
     # Perform actions
     simulateClick(widget.getAddButton())
     widget.setNewTodoText("Test todo")
     simulateClick(widget.getAddButton())
     
     # Check state change log
     for change in debugLog.stateChanges:
       echo fmt"State change at {change.path}:"
       echo fmt"  {change.oldValue} -> {change.newValue}"

     # Verify final state
     check widget.todos.len == 1
     check widget.todos[0].text == "Test todo"

suite "Event Debugging":
 test "Track event propagation":
   let debugLog = startDebugLog()
   
   testInteraction NestedButtons():
     # Trigger events
     simulateClick(widget.getInnerButton())
     
     # Check event log
     for event in debugLog.eventLog:
       echo fmt"Event: {event.kind} on {event.widget}"
       echo fmt"Data: {event.data}"
       
     # Verify event bubbling
     check debugLog.eventLog.len >= 2  # Click + bubble

# Performance Debug
suite "Performance Tests":
 test "Layout performance":
   var times: seq[float]
   
   benchmark "Grid layout (100 items)":
     testInteraction GridLayout():
       # Add 100 items
       for i in 0..99:
         widget.add Panel()
       
       # Measure multiple layouts
       for i in 0..10:
         let start = epochTime()
         widget.solveLayout()
         times.add(epochTime() - start)
       
       # Report stats
       echo fmt"Min: {min(times)}ms"
       echo fmt"Max: {max(times)}ms"
       echo fmt"Avg: {mean(times)}ms"