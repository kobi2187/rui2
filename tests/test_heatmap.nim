## CalendarHeatmap (modern/heatmap.nim): weeks in columns ending at the end
## date, Monday at the top; values in levels of the largest; a click reports
## the day and its value.

import std/[unittest, tables, times]
import rui
import ui_harness

suite "CalendarHeatmap":
  teardown: clearRepaints()

  test "levels: nothing is 0, then shares of the largest":
    check heatLevel(0, 10) == 0
    check heatLevel(1, 10) == 1
    check heatLevel(10, 10) == 4
    check heatLevel(6, 10) == 3
    check heatLevel(5, 0) == 0

  test "cells: Monday at the top, the last column ends at the end day":
    let endDay = parse("2026-10-28", "yyyy-MM-dd", utc())   # a Wednesday
    let cells = heatCells(endDay, 2)
    check cells[0].day == "2026-10-19" and cells[0].col == 0 and cells[0].row == 0
    check cells[^1].day == "2026-10-28" and cells[^1].col == 1 and cells[^1].row == 2
    check cells.len == 10

  test "a click on a day reports it with its value":
    var got: seq[(string, float)]
    var vals = initTable[string, float]()
    vals["2026-10-27"] = 5
    let h = newCalendarHeatmap(values = vals, endDate = "2026-10-28", weeks = 4,
                               onDayClick = proc(d: string, v: float) = got.add (d, v))
    let r = newRig(stack(h), 400, 200)
    var at = -1
    for i, c in h.cells:
      if c.day == "2026-10-27": at = i
    let step = h.cellSize + h.gap
    let cx = h.bounds.x + 28 + float32(h.cells[at].col) * step + 4
    let cy = h.bounds.y + 16 + float32(h.cells[at].row) * step + 4
    r.click(cx, cy)
    check got == @[("2026-10-27", 5.0)]
    disposeTree(r.root)
