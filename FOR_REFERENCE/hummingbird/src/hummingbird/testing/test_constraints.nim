# test/layout/test_constraints.nim
suite "Layout Tests":
  test "Centered widget is actually centered":
    let parent = Panel(width: 400, height: 400)
    let child = Panel(width: 100, height: 100)
    
    layout:
      child:
        center in parent
    
    # Solve constraints
    parent.solveLayout()
    
    # Verify position
    check child.x == 150
    check child.y == 150

  test "Grid layout columns are equal":
    let grid = GridLayout(
      columns: 3,
      spacing: 10
    )
    
    for i in 0..5:
      grid.add Panel()
    
    grid.solveLayout()
    
    # Verify column widths
    let firstColWidth = grid.children[0].width
    for child in grid.children:
      check child.width == firstColWidth