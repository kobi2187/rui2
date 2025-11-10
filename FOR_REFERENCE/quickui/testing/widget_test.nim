# widget_test.nim
type
  TestAction* = object
    widget*: string    # Widget path
    action*: string    # What to do
    params*: JsonNode  # Parameters
    expect*: JsonNode  # Expected result

  Testable*[T] = concept widget
    widget.id is string
    widget.getTestValue() is T
    widget.handleTestAction(string, JsonNode) is bool

# Example widget with testing support
defineWidget Button:
  props:
    text: string
    onClick: proc()

  testing:  # New section for test/script support
    # Define testable actions
    actions:
      click:
        widget.onClick()
        return true
      
      getText:
        return widget.text
      
      isEnabled:
        return widget.enabled

# Test usage
let test = TestAction(
  widget: "mainForm/saveButton",
  action: "click",
  expect: %*{"clicked": true}
)

# Can be used both for testing and scripting
test.execute()