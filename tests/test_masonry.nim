## Masonry (layout/masonry.nim): as many columns as fit, each child in the
## shortest column, full column width, its own height.

import std/unittest
import rui
import ui_harness

suite "Masonry":
  test "as many columns as fit, or as many as asked":
    check columnsFor(600, 180, 10, 0) == 3
    check columnsFor(100, 180, 10, 0) == 1
    check columnsFor(600, 180, 10, 2) == 2

  test "each child goes to the shortest column, as wide as a column":
    let heights = [100'f32, 40, 60, 30, 50]
    var kids: seq[Widget]
    for h in heights: kids.add newRectangle().frame(height = h)
    let m = newMasonry(columns = 3, spacing = 10)
    for k in kids: m.addChild k
    let r = newRig(stack(m.frame(width = 320)), 400, 300)
    let colW = (320'f32 - 20) / 3
    check kids[0].bounds.width == colW
    check kids[0].bounds.x == m.bounds.x and kids[1].bounds.x == m.bounds.x + colW + 10
    # 4th (30) goes under the 2nd (40: the shortest), 5th (50) under the 4th (40+10+30=80 < 100, 60)
    check kids[3].bounds.x == kids[1].bounds.x and kids[3].bounds.y == m.bounds.y + 50
    check kids[4].bounds.x == kids[2].bounds.x and kids[4].bounds.y == m.bounds.y + 70
    check m.bounds.height == 120
    disposeTree(r.root)
