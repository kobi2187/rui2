
# Layout DSL with Testing:
# Layout DSL that generates both UI and tests
layout mainForm:
  panel:
    width = 80%
    height = 90%

    testing:  # Embedded test cases
      verify:
        width == parent.width * 0.8
        height == parent.height * 0.9

type
  UITest = object
    setup: seq[TestAction]
    actions: seq[TestAction]
    cleanup: seq[TestAction]

  TestResult = object
    passed: bool
    message: string
    widgetState: JsonNode

# Example test
let test = UITest(
  setup: @[
    TestAction(widget: "loginForm/username", action: "setText", params: %*{"text": "testuser"}),
    TestAction(widget: "loginForm/password", action: "setText", params: %*{"text": "password"})
  ],
  actions: @[
    TestAction(widget: "loginForm/loginButton", action: "click"),
    TestAction(widget: "mainView", action: "isVisible", expect: %*{"visible": true})
  ]
)

# Run test
let result = runTest(test)
