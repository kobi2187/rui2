# File: src/quickui/testing/types.nim

import json, tables, options
import ../core/types as core_types

type
  TestAction* = object
    widgetPath*: string    # Path to target widget
    action*: string        # Action to perform
    params*: JsonNode      # Action parameters
    expect*: JsonNode      # Expected result

  TestResult* = object
    passed*: bool
    message*: string
    widgetState*: JsonNode
    timestamp*: float
    duration*: float

  UITest* = object
    name*: string
    description*: string
    setup*: seq[TestAction]
    actions*: seq[TestAction]
    cleanup*: seq[TestAction]
    timeout*: float

  TestSuite* = object
    name*: string
    tests*: seq[UITest]

  TestableWidget* = concept w
    w.id is string
    w.handleTestAction(string, JsonNode) is bool
    w.getTestState() is JsonNode
```

# File: src/quickui/testing/runner.nim
```nim
import json, tables, times
import types
import ../core/types as core_types
import ../core/widgets as core_widgets

type
  TestRunner* = ref object
    app*: core_widgets.Widget  # Root widget
    results*: seq[TestResult]
    currentTest*: Option[UITest]

proc newTestRunner*(app: core_widgets.Widget): TestRunner =
  TestRunner(app: app, results: @[])

proc findWidget(app: core_widgets.Widget, path: string): Option[core_widgets.Widget] =
  # Implement widget path resolution
  var current = app
  for part in path.split('/'):
    var found = false
    for child in current.children:
      if child.id == part:
        current = child
        found = true
        break
    if not found:
      return none(core_widgets.Widget)
  return some(current)

proc executeAction(runner: TestRunner, action: TestAction): TestResult =
  let startTime = epochTime()

  # Find target widget
  let widget = runner.app.findWidget(action.widgetPath)
  if widget.isNone:
    return TestResult(
      passed: false,
      message: "Widget not found: " & action.widgetPath,
      timestamp: startTime,
      duration: 0.0
    )

  # Execute action
  let target = widget.get()
  if target of TestableWidget:
    let testable = TestableWidget(target)
    let success = testable.handleTestAction(action.action, action.params)
    let state = testable.getTestState()

    # Verify expectations if any
    var passed = success
    var message = if success: "Action executed successfully" else: "Action failed"

    if not action.expect.isNil:
      passed = state == action.expect
      if not passed:
        message = "State mismatch. Expected: " & $action.expect & ", Got: " & $state

    return TestResult(
      passed: passed,
      message: message,
      widgetState: state,
      timestamp: startTime,
      duration: epochTime() - startTime
    )
  else:
    return TestResult(
      passed: false,
      message: "Widget is not testable: " & action.widgetPath,
      timestamp: startTime,
      duration: epochTime() - startTime
    )

proc runTest*(runner: TestRunner, test: UITest): TestResult =
  runner.currentTest = some(test)
  let startTime = epochTime()

  # Run setup actions
  for action in test.setup:
    let result = runner.executeAction(action)
    if not result.passed:
      return result

  # Run test actions
  for action in test.actions:
    let result = runner.executeAction(action)
    if not result.passed:
      return result

  # Run cleanup
  for action in test.cleanup:
    discard runner.executeAction(action)

  return TestResult(
    passed: true,
    message: "Test completed successfully",
    timestamp: startTime,
    duration: epochTime() - startTime
  )

proc runSuite*(runner: TestRunner, suite: TestSuite): seq[TestResult] =
  for test in suite.tests:
    result.add(runner.runTest(test))
```

# File: src/quickui/testing/scriptable.nim
```nim
import macros, json
import types

macro makeTestable*(T: typed): untyped =
  # Generate testable implementation for widget type
  result = newStmtList()

  # Add required methods
  result.add quote do:
    method handleTestAction*(widget: `T`, action: string, params: JsonNode): bool =
      case action
      of "isVisible":
        result = widget.visible
      of "isEnabled":
        result = widget.enabled
      else:
        result = false

    method getTestState*(widget: `T`): JsonNode =
      result = %*{
        "id": widget.id,
        "visible": widget.visible,
        "enabled": widget.enabled
      }

macro testable*(widget: untyped, body: untyped): untyped =
  # Add testable actions to a widget
  result = newStmtList()

  for action in body:
    let actionName = action[0]
    let actionBody = action[1]

    result.add quote do:
      method handleTestAction*(widget: `widget`, action: string, params: JsonNode): bool =
        case action
        of `actionName`:
          `actionBody`
        else:
          procCall widget.Widget.handleTestAction(action, params)
```

# File: src/quickui/testing/widgets/button.nim
```nim
import ../types
import ../../core/widgets/button

testable Button:
  "click":
    if widget.enabled:
      widget.onClick()
      true
    else:
      false

  "getText":
    result = %*{"text": widget.text}

  "setText":
    widget.text = params["text"].getStr
    true

  "enable":
    widget.enabled = params["enabled"].getBool
    true
```

# File: src/quickui/testing/widgets/textinput.nim
```nim
import ../types
import ../../core/widgets/textinput

testable TextInput:
  "setText":
    widget.text = params["text"].getStr
    true

  "getText":
    result = %*{"text": widget.text}

  "clear":
    widget.text = ""
    true

  "focus":
    widget.focused = true
    true
```

# File: examples/test_example.nim
```nim
import quickui/testing

# Define a test suite
let loginSuite = TestSuite(
  name: "Login Tests",
  tests: @[
    UITest(
      name: "Successful Login",
      setup: @[
        TestAction(
          widgetPath: "loginForm/username",
          action: "setText",
          params: %*{"text": "testuser"}
        ),
        TestAction(
          widgetPath: "loginForm/password",
          action: "setText",
          params: %*{"text": "password"}
        )
      ],
      actions: @[
        TestAction(
          widgetPath: "loginForm/loginButton",
          action: "click"
        ),
        TestAction(
          widgetPath: "mainView",
          action: "isVisible",
          expect: %*{"visible": true}
        )
      ]
    ),
    UITest(
      name: "Invalid Login",
      setup: @[
        TestAction(
          widgetPath: "loginForm/username",
          action: "setText",
          params: %*{"text": "invalid"}
        ),
        TestAction(
          widgetPath: "loginForm/password",
          action: "setText",
          params: %*{"text": "wrong"}
        )
      ],
      actions: @[
        TestAction(
          widgetPath: "loginForm/loginButton",
          action: "click"
        ),
        TestAction(
          widgetPath: "loginForm/errorMessage",
          action: "isVisible",
          expect: %*{"visible": true}
        )
      ]
    )
  ]
)

# Run tests
let app = initApp()
let runner = newTestRunner(app)
let results = runner.runSuite(loginSuite)

# Report results
for result in results:
  echo result.message
