## CalendarHeatmap -- a year (or any run of weeks) of daily values as a grid
## of squares, darker for more: contributions, workouts, sales.
##
## ```nim
## var days = initTable[string, float]()
## days["2026-10-27"] = 4
## ui:
##   CalendarHeatmap(values = days, weeks = 26,
##                   onDayClick = proc(day: string, v: float) = echo day, ": ", v)
## ```
##
## A column a week, Monday at the top, the newest week on the right ending at
## `endDate` (today when empty). Days are ISO dates ("2026-10-27"). Values
## fall into `levels` shades of the theme's accent, relative to the largest
## shown; no value (or 0) is the faint empty square. The day under the pointer
## shows its date and value.

import rui_core
import rui_drawing
import std/[options, tables, times, math]
import raylib

proc heatLevel*(value, largest: float, levels = 4): int =
  ## 0 for nothing; 1 .. levels by the share of the largest value.
  if value <= 0 or largest <= 0: return 0
  clamp(1 + int(floor(float(levels) * value / largest - 1e-9)), 1, levels)

proc isoDay*(d: DateTime): string = d.format("yyyy-MM-dd")

proc heatCells*(endDay: DateTime, weeks: int):
    seq[tuple[day: string, col, row: int]] =
  ## The days from the Monday `weeks - 1` weeks before `endDay`'s week up to
  ## `endDay`: column = week (0 the oldest), row = weekday (0 Monday).
  let back = ord(endDay.weekday)                      # Monday = 0
  let firstMonday = endDay - initDuration(days = back + 7 * (weeks - 1))
  var d = firstMonday
  var i = 0
  while d <= endDay:
    result.add (isoDay(d), i div 7, i mod 7)
    d = d + initDuration(days = 1)
    inc i

proc cellRect(widget: Widget, col, row: int): Rect
proc dayAt(widget: Widget, p: Point): int

const
  LabelW = 28'f32               ## the weekday labels on the left
  LabelH = 16'f32               ## the month labels on top

definePrimitive(CalendarHeatmap):
  props:
    values: Table[string, float] = initTable[string, float]()
    endDate: string = ""          ## "" for today
    weeks: int = 53
    cellSize: float32 = 12.0
    gap: float32 = 3.0
    levels: int = 4
    intent: ThemeIntent = Default

  state:
    hover: int                    ## index into cells under the pointer; -1: none
    cells: seq[tuple[day: string, col, row: int]]

  actions:
    onDayClick(day: string, value: float)

  init:
    widget.hover = -1

  events:
    on_mouse_move:
      let i = widget.dayAt(event.mousePos)
      if i != widget.hover:
        widget.hover = i
        widget.isDirty = true
      return false

    on_mouse_down:
      let i = widget.dayAt(event.mousePos)
      if i < 0 or widget.onDayClick == nil: return false
      let day = widget.cells[i].day
      widget.onDayClick(day, widget.values.getOrDefault(day, 0))
      return true

  layout:
    let last = if widget.endDate.len > 0: parse(widget.endDate, "yyyy-MM-dd", utc())
               else: now().utc
    widget.cells = heatCells(last, max(1, widget.weeks))
    if widget.bounds.width <= 0:
      widget.bounds.width = LabelW + float32(max(1, widget.weeks)) * (widget.cellSize + widget.gap)
    if widget.bounds.height <= 0:
      widget.bounds.height = LabelH + 7 * (widget.cellSize + widget.gap) + 4

  render:
    let props = currentTheme.getThemeProps(widget.intent, Normal)
    let ink = props.foregroundColor.get(BLACK)
    let accent = props.activeColor.get(ink)
    var largest = 0.0
    for c in widget.cells: largest = max(largest, widget.values.getOrDefault(c.day, 0))
    var style = props.captionStyle(ink.withAlpha(0.7))
    style.fontSize = max(9'f32, style.fontSize - 4)
    for row, name in [(0, "Mon"), (2, "Wed"), (4, "Fri")]:
      drawStyledText(name[1], widget.bounds.x, widget.cellRect(0, name[0]).y - 1, style)
    var lastMonth = ""
    var labelEnd = -1e9'f32                         # a month label must not run into the last
    let r = min(3'f32, widget.cellSize / 4)
    for c in widget.cells:
      let box = widget.cellRect(c.col, c.row)
      if c.row == 0 and c.day[5 .. 6] != lastMonth:     # a month's first column
        lastMonth = c.day[5 .. 6]
        let name = parse(c.day, "yyyy-MM-dd", utc()).format("MMM")
        if box.x >= labelEnd + 4:
          drawStyledText(name, box.x, widget.bounds.y, style)
          labelEnd = box.x + measureText(name, style).width
      let level = heatLevel(widget.values.getOrDefault(c.day, 0), largest, widget.levels)
      let fill = if level == 0: ink.withAlpha(0.07)
                 else: accent.withAlpha(0.2 + 0.8 * float32(level) / float32(widget.levels))
      discard drawSdfBox(box, r, 0, fill, fill)
    if widget.hover >= 0 and widget.hover < widget.cells.len:
      let c = widget.cells[widget.hover]
      let box = widget.cellRect(c.col, c.row)
      discard drawSdfBox(box, r, 1.5, Color(), ink)
      let v = widget.values.getOrDefault(c.day, 0)
      let text = c.day & ": " & (if v == float(int(v)): $int(v) else: $v)
      var tip = props.captionStyle(ink)
      tip.fontSize = max(10'f32, tip.fontSize - 2)
      let size = measureText(text, tip)
      var x = box.x + box.width + 6
      if x + size.width + 10 > widget.bounds.x + widget.bounds.width: x = box.x - size.width - 16
      let y = max(widget.bounds.y, box.y - size.height - 6)
      let bubble = Rect(x: x, y: y, width: size.width + 16, height: size.height + 6)
      drawBox(bubble, 4, props.backgroundColor.get(WHITE), ink.withAlpha(0.4), 1)
      drawStyledText(text, bubble.x + 8, bubble.y + 3, tip)

proc cellRect(widget: Widget, col, row: int): Rect =
  let widget = CalendarHeatmap(widget)
  let step = widget.cellSize + widget.gap
  Rect(x: widget.bounds.x + LabelW + float32(col) * step,
       y: widget.bounds.y + LabelH + float32(row) * step,
       width: widget.cellSize, height: widget.cellSize)

proc dayAt(widget: Widget, p: Point): int =
  ## The cell under `p`, or -1.
  let widget = CalendarHeatmap(widget)
  for i, c in widget.cells:
    if widget.cellRect(c.col, c.row).contains(p.x, p.y): return i
  -1
