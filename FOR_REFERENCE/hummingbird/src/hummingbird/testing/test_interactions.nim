
# test/scripting/test_interactions.nim
suite "Widget Interaction Tests":
  test "Button click triggers callback":
    var clicked = false
    let button = Button(
      text: "Click Me",
      onClick: proc() = clicked = true
    )

    # Query initial state
    let initialState = queryState("button")
    check initialState["enabled"].getBool == true

    # Simulate click
    sendMessage("button", "click")

    # Verify callback was triggered
    check clicked == true

  test "Text input updates":
    let input = TextInput()
    
    # Set text via message
    sendMessage("input", "setText", %*{"text": "Hello"})
    
    # Query new state
    let state = queryState("input")
    check state["text"].getStr == "Hello"