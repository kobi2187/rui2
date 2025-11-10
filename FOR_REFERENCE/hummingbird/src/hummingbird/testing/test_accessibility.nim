
      # 7. Accessibility Testing
suite "Accessibility Tests":
  test "Screen reader labels are set":
    let button = Button(
      text: "Save",
      accessibilityLabel: "Save document"
    )
    check button.getAccessibilityInfo().label == "Save document"

  test "Tab navigation order":
    let container = Panel()
    let input1 = TextInput()
    let input2 = TextInput()
    let button = Button()
    
    container.addChildren([input1, input2, button])
    check getFocusOrder(container) == @[input1, input2, button]

# 8. Resource Management Tests
suite "Resource Tests":
  test "Resources are properly cleaned up":
    var widget: Widget
    new(widget)
    
    # Track resources
    var resourcesFreed = false
    widget.onDispose = proc() =
      resourcesFreed = true
    
    # Simulate widget disposal
    widget = nil
    GC_fullCollect()
    check resourcesFreed

  test "Theme resources don't leak":
    let initialThemeCount = getThemeResourceCount()
    block:
      let theme = customTheme()
      # Theme should be freed after block
    
    GC_fullCollect()
    check getThemeResourceCount() == initialThemeCount

# 9. Input Handling Tests
suite "Input Tests":
  test "Gesture recognition":
    let gesture = PanGesture()
    gesture.onPanUpdate = proc(delta: Point) =
      check delta.x != 0 or delta.y != 0
    
    simulateGesture(
      startPos = Point(x: 0, y: 0),
      moves = @[Point(x: 10, y: 10)],
      endPos = Point(x: 20, y: 20)
    )

  test "Key combinations":
    var triggered = false
    let shortcut = KeyboardShortcut(
      key: Key.S,
      modifiers: {ModControl}
    )
    shortcut.onTriggered = proc() =
      triggered = true
    
    simulateKeyPress(Key.S, {ModControl})
    check triggered

# 10. Animation Tests
suite "Animation Tests":
  test "Animation completion":
    let panel = Panel()
    var completed = false
    
    animate panel:
      opacity:
        from = 0.0
        to = 1.0
        duration = 0.1
        onComplete = proc() =
          completed = true
    
    # Fast forward time
    advanceTime(0.2)
    check completed
    check panel.opacity == 1.0

  test "Spring animation physics":
    let box = Panel()
    animateSpring box.x:
      to = 100.0
      stiffness = 100
      damping = 10
    
    # Test physical properties
    advanceTime(0.016)  # One frame
    check box.x > 0 and box.x < 100

# 11. State Synchronization Tests
suite "State Sync Tests":
  test "Multiple widgets sync to same state":
    let state = Store[int](value: 0)
    let label1 = Label(text: $state.get())
    let label2 = Label(text: $state.get())
    
    state.set(42)
    check label1.text == "42"
    check label2.text == "42"

# 12. Platform Adaptation Tests
suite "Platform Tests":
  test "Touch vs mouse input":
    let button = Button()
    
    # Test mouse click
    simulateMouseClick(button.rect.center)
    check button.wasClicked
    
    # Test touch
    simulateTouchTap(button.rect.center)
    check button.wasClicked

# 13. Widget Tree Tests
suite "Widget Tree Tests":
  test "Find widgets by path":
    let root = Panel()
    let child = TextInput(id: "nameInput")
    root.addChild(child)
    
    let found = root.findWidget("nameInput")
    check found == child

  test "Widget tree modifications":
    let root = Panel()
    let child = Button()
    
    root.addChild(child)
    check child.parent == root
    
    root.removeChild(child)
    check child.parent == nil

# 14. Error Handling Tests
suite "Error Tests":
  test "Layout error handling":
    let panel = Panel()
    
    # Create impossible constraints
    expect ConstraintError:
      layout:
        panel:
          width = 100
          width = 200  # Conflicting constraint

  test "Invalid state updates":
    let state = Store[range[0..10]](value: 0)
    
    expect RangeDefect:
      state.set(20)

# 15. Serialization Tests
suite "Serialization Tests":
  test "Widget state serialization":
    let button = Button(
      text: "Click me",
      enabled: true
    )
    
    let json = button.serialize()
    let deserialized = deserializeWidget[Button](json)
    
    check deserialized.text == button.text
    check deserialized.enabled == button.enabled