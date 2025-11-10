# test/perf/test_performance.nim
suite "Performance Tests":
  test "Large list rendering":
    let list = ListView()
    
    # Add 1000 items
    for i in 0..999:
      list.add ListItem(text: $i)
    
    # Measure render time
    let start = epochTime()
    list.render()
    let duration = epochTime() - start
    
    check duration < 0.016  # Target 60fps

  test "Constraint solving performance":
    var widgets: seq[Widget]
    for i in 0..99:
      widgets.add Panel()
    
    # Time layout solve
    benchmark "100 widget layout":
      solveLayout(widgets)
      