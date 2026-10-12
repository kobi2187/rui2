## The values the date, time and colour pickers work in, and the arithmetic on
## them -- no widgets, no window, so each rule is testable on its own.
##
## A date is `Ymd`, written and read as ISO text ("2026-10-11"); a time is
## minutes since midnight, written "14:30" (or "2:30 PM"); a colour is hex text
## ("#3366cc"). Text is what crosses the widget boundary, so a picker binds to
## a plain `Link[string]` or a Store entry like any other field.

import std/[times, options, strutils, math]
import rui_core

type
  Ymd* = object
    year*, month*, day*: int

  Hsv* = object
    h*: float32          ## hue, 0..360
    s*, v*: float32      ## saturation and value, 0..1

# ---------------------------------------------------------------------------
# Dates

proc daysIn*(year, month: int): int =
  getDaysInMonth(Month(month), year)

proc isValid*(d: Ymd): bool =
  d.year in 1 .. 9999 and d.month in 1 .. 12 and d.day in 1 .. daysIn(d.year, d.month)

proc isoDate*(d: Ymd): string =
  align($d.year, 4, '0') & "-" & align($d.month, 2, '0') & "-" & align($d.day, 2, '0')

proc parseIsoDate*(text: string): Option[Ymd] =
  ## "2026-10-11" -> a valid date; anything else (including 2026-02-30) -> none.
  let parts = text.strip().split('-')
  if parts.len != 3: return none(Ymd)
  try:
    let d = Ymd(year: parseInt(parts[0]), month: parseInt(parts[1]),
                day: parseInt(parts[2]))
    if d.isValid: some(d) else: none(Ymd)
  except ValueError:
    none(Ymd)

proc weekday*(d: Ymd): int =
  ## 0 is Monday ... 6 is Sunday.
  ord(getDayOfWeek(d.day, Month(d.month), d.year))

proc addDays*(d: Ymd, n: int): Ymd =
  let moved = dateTime(d.year, Month(d.month), d.day, zone = utc()) + days(n)
  Ymd(year: moved.year, month: ord(moved.month), day: moved.monthday)

proc addMonths*(d: Ymd, n: int): Ymd =
  ## The same day `n` months on, or the month's last day when it has no such day
  ## (31 January + 1 month is 28 or 29 February).
  let index = d.year * 12 + (d.month - 1) + n
  let year = index div 12
  let month = index mod 12 + 1
  Ymd(year: year, month: month, day: min(d.day, daysIn(year, month)))

proc calendarCells*(year, month: int, mondayFirst = true): array[42, Ymd] =
  ## The six weeks a month grid shows: the month, padded either side with the
  ## days of its neighbours.
  let first = Ymd(year: year, month: month, day: 1)
  let lead = if mondayFirst: first.weekday else: (first.weekday + 1) mod 7
  for i in 0 ..< 42:
    result[i] = first.addDays(i - lead)

# ---------------------------------------------------------------------------
# Times: minutes since midnight

proc formatTime*(minutes: int, use24h = true): string =
  let m = clamp(minutes, 0, 24 * 60 - 1)
  let hour = m div 60
  let minute = align($(m mod 60), 2, '0')
  if use24h: align($hour, 2, '0') & ":" & minute
  else:
    let h12 = if hour mod 12 == 0: 12 else: hour mod 12
    $h12 & ":" & minute & (if hour < 12: " AM" else: " PM")

proc parseTime*(text: string): Option[int] =
  ## "14:30", "2:30 pm", "0905" are all read; hours past 23 or minutes past 59
  ## are not times.
  var t = text.strip().toLowerAscii
  var pm = false
  var meridiem = false
  for suffix in ["am", "pm"]:
    if t.endsWith(suffix):
      meridiem = true
      pm = suffix == "pm"
      t = t[0 ..< t.len - 2].strip()
  var hourText, minuteText: string
  if ':' in t:
    let parts = t.split(':')
    if parts.len != 2: return none(int)
    hourText = parts[0]; minuteText = parts[1]
  elif t.len == 4 and not meridiem:
    hourText = t[0 .. 1]; minuteText = t[2 .. 3]
  else:
    return none(int)
  try:
    var hour = parseInt(hourText)
    let minute = parseInt(minuteText)
    if minute notin 0 .. 59: return none(int)
    if meridiem:
      if hour notin 1 .. 12: return none(int)
      hour = hour mod 12 + (if pm: 12 else: 0)
    if hour notin 0 .. 23: return none(int)
    some(hour * 60 + minute)
  except ValueError:
    none(int)

# ---------------------------------------------------------------------------
# Colours

# parseHexColor lives in rui_core/widget_registry (documents set colours too).

proc formatHexColor*(c: Color): string =
  ## "#rrggbb", or "#rrggbbaa" when not opaque.
  result = "#" & toHex(int(c.r), 2).toLowerAscii & toHex(int(c.g), 2).toLowerAscii &
           toHex(int(c.b), 2).toLowerAscii
  if c.a != 255: result.add toHex(int(c.a), 2).toLowerAscii

proc toHsv*(c: Color): Hsv =
  let r = c.r.float32 / 255
  let g = c.g.float32 / 255
  let b = c.b.float32 / 255
  let hi = max(r, max(g, b))
  let lo = min(r, min(g, b))
  let delta = hi - lo
  result.v = hi
  result.s = if hi <= 0: 0.0'f32 else: delta / hi
  if delta <= 0:
    result.h = 0
  elif hi == r:
    result.h = 60 * (((g - b) / delta) mod 6)
  elif hi == g:
    result.h = 60 * ((b - r) / delta + 2)
  else:
    result.h = 60 * ((r - g) / delta + 4)
  if result.h < 0: result.h += 360

proc toColor*(hsv: Hsv, alpha: uint8 = 255): Color =
  let h = hsv.h - 360 * floor(hsv.h / 360)
  let c = hsv.v * hsv.s
  let x = c * (1 - abs((h / 60) mod 2 - 1))
  let m = hsv.v - c
  var (r, g, b) = (0.0'f32, 0.0'f32, 0.0'f32)
  case int(h / 60)
  of 0: (r, g, b) = (c, x, 0.0'f32)
  of 1: (r, g, b) = (x, c, 0.0'f32)
  of 2: (r, g, b) = (0.0'f32, c, x)
  of 3: (r, g, b) = (0.0'f32, x, c)
  of 4: (r, g, b) = (x, 0.0'f32, c)
  else: (r, g, b) = (c, 0.0'f32, x)
  Color(r: uint8(round((r + m) * 255)), g: uint8(round((g + m) * 255)),
        b: uint8(round((b + m) * 255)), a: alpha)

# ---------------------------------------------------------------------------
# Calendar popup geometry: one place decides where things are, and both the
# drawing and the pointer go through it.

const
  CalCellW* = 34.0'f32
  CalCellH* = 28.0'f32
  CalHeaderH* = 32.0'f32
  CalWeekdayH* = 22.0'f32
  CalWidth* = CalCellW * 7
  CalHeight* = CalHeaderH + CalWeekdayH + CalCellH * 6

type
  CalHitKind* = enum calNone, calPrevMonth, calNextMonth, calDay
  CalHit* = object
    kind*: CalHitKind
    cell*: int           ## 0..41, for calDay

proc calCellRect*(popup: Rect, cell: int): Rect =
  Rect(x: popup.x + float32(cell mod 7) * CalCellW,
       y: popup.y + CalHeaderH + CalWeekdayH + float32(cell div 7) * CalCellH,
       width: CalCellW, height: CalCellH)

proc calPrevRect*(popup: Rect): Rect =
  Rect(x: popup.x, y: popup.y, width: CalCellW, height: CalHeaderH)

proc calNextRect*(popup: Rect): Rect =
  Rect(x: popup.x + popup.width - CalCellW, y: popup.y, width: CalCellW,
       height: CalHeaderH)

proc calHit*(popup: Rect, x, y: float32): CalHit =
  if not popup.contains(x, y): return CalHit(kind: calNone)
  if calPrevRect(popup).contains(x, y): return CalHit(kind: calPrevMonth)
  if calNextRect(popup).contains(x, y): return CalHit(kind: calNextMonth)
  let gridTop = popup.y + CalHeaderH + CalWeekdayH
  if y < gridTop: return CalHit(kind: calNone)
  let col = int((x - popup.x) / CalCellW)
  let row = int((y - gridTop) / CalCellH)
  if col in 0 .. 6 and row in 0 .. 5:
    CalHit(kind: calDay, cell: row * 7 + col)
  else:
    CalHit(kind: calNone)

# ---------------------------------------------------------------------------
# Colour popup geometry

const
  ColPad* = 8.0'f32
  ColSvW* = 220.0'f32
  ColSvH* = 150.0'f32
  ColHueH* = 18.0'f32
  ColLabelH* = 20.0'f32
  ColWidth* = ColSvW + ColPad * 2
  ColHeight* = ColPad + ColSvH + ColPad + ColHueH + ColPad + ColLabelH + ColPad

proc colSvRect*(popup: Rect): Rect =
  Rect(x: popup.x + ColPad, y: popup.y + ColPad, width: ColSvW, height: ColSvH)

proc colHueRect*(popup: Rect): Rect =
  Rect(x: popup.x + ColPad, y: popup.y + ColPad + ColSvH + ColPad,
       width: ColSvW, height: ColHueH)

proc svAt*(popup: Rect, x, y: float32, hue: float32): Hsv =
  ## The colour under (x, y) in the saturation/value square: saturation grows
  ## to the right, value falls going down. Clamped to the square.
  let r = colSvRect(popup)
  Hsv(h: hue, s: clamp((x - r.x) / r.width, 0.0'f32, 1.0'f32),
      v: 1 - clamp((y - r.y) / r.height, 0.0'f32, 1.0'f32))

proc hueAt*(popup: Rect, x: float32): float32 =
  let r = colHueRect(popup)
  clamp((x - r.x) / r.width, 0.0'f32, 1.0'f32) * 359.999'f32

proc inset*(r: Rect, by: float32): Rect =
  Rect(x: r.x + by, y: r.y + by, width: r.width - by * 2, height: r.height - by * 2)
