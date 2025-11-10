# test/events/test_propagation.nim
suite "Event Tests":
  test "Child gets parent's theme":
    let parent = Panel()
    let child = Panel()
    parent.addChild(child)
    
    parent.theme = customTheme()
    check child.getTheme() == parent.theme

  test "Focus handling":
    let input1 = TextInput()
    let input2 = TextInput()
    
    input1.focus()
    check input1.focused
    
    input2.focus()
    check not input1.focused
    check input2.focused