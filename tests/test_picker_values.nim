## Date, time and colour arithmetic behind the pickers.

import std/[unittest, options]
import rui
import ../packages/rui_widgets/src/input/picker_values

suite "dates":

  test "iso text round trips and rejects impossible days":
    check parseIsoDate("2026-10-11").get == Ymd(year: 2026, month: 10, day: 11)
    check isoDate(Ymd(year: 2026, month: 1, day: 5)) == "2026-01-05"
    check parseIsoDate("2026-02-30").isNone
    check parseIsoDate("2024-02-29").isSome              # a leap day
    check parseIsoDate("2023-02-29").isNone
    check parseIsoDate("tomorrow").isNone
    check parseIsoDate("2026-13-01").isNone

  test "weekday counts from Monday":
    check Ymd(year: 2026, month: 10, day: 11).weekday == 6    # a Sunday
    check Ymd(year: 2026, month: 10, day: 12).weekday == 0

  test "adding days crosses months and years":
    check Ymd(year: 2026, month: 12, day: 31).addDays(1) == Ymd(year: 2027, month: 1, day: 1)
    check Ymd(year: 2026, month: 3, day: 1).addDays(-1) == Ymd(year: 2026, month: 2, day: 28)
    check Ymd(year: 2024, month: 3, day: 1).addDays(-1).day == 29

  test "adding months clamps the day":
    check Ymd(year: 2026, month: 1, day: 31).addMonths(1) == Ymd(year: 2026, month: 2, day: 28)
    check Ymd(year: 2026, month: 11, day: 15).addMonths(2) == Ymd(year: 2027, month: 1, day: 15)
    check Ymd(year: 2026, month: 1, day: 15).addMonths(-1) == Ymd(year: 2025, month: 12, day: 15)

  test "the month grid starts on the right weekday and covers the month":
    let cells = calendarCells(2026, 10)                      # 1 Oct 2026 is a Thursday
    check cells[3] == Ymd(year: 2026, month: 10, day: 1)
    check cells[0] == Ymd(year: 2026, month: 9, day: 28)
    check cells[33] == Ymd(year: 2026, month: 10, day: 31)
    let sundayFirst = calendarCells(2026, 10, mondayFirst = false)
    check sundayFirst[4] == Ymd(year: 2026, month: 10, day: 1)

suite "times":

  test "format and parse":
    check formatTime(14 * 60 + 5) == "14:05"
    check formatTime(0, use24h = false) == "12:00 AM"
    check formatTime(13 * 60, use24h = false) == "1:00 PM"
    check parseTime("14:30").get == 870
    check parseTime("2:30 pm").get == 870
    check parseTime("12:00 am").get == 0
    check parseTime("0905").get == 545
    check parseTime("24:00").isNone
    check parseTime("10:60").isNone
    check parseTime("13:00 pm").isNone
    check parseTime("noon").isNone

  test "every minute of the day round trips":
    for m in 0 ..< 24 * 60:
      check parseTime(formatTime(m)).get == m
      check parseTime(formatTime(m, use24h = false)).get == m

suite "colours":

  test "hex":
    check parseHexColor("#3366cc").get == Color(r: 0x33, g: 0x66, b: 0xcc, a: 255)
    check parseHexColor("fa0").get == Color(r: 0xff, g: 0xaa, b: 0x00, a: 255)
    check parseHexColor("#11223380").get.a == 0x80
    check parseHexColor("#12").isNone
    check parseHexColor("#gggggg").isNone
    check formatHexColor(Color(r: 1, g: 2, b: 255, a: 255)) == "#0102ff"
    check formatHexColor(Color(r: 0, g: 0, b: 0, a: 0x80)) == "#00000080"

  test "hsv known points":
    check Hsv(h: 0, s: 1, v: 1).toColor == Color(r: 255, g: 0, b: 0, a: 255)
    check Hsv(h: 120, s: 1, v: 1).toColor == Color(r: 0, g: 255, b: 0, a: 255)
    check Hsv(h: 240, s: 1, v: 1).toColor == Color(r: 0, g: 0, b: 255, a: 255)
    check Hsv(h: 0, s: 0, v: 1).toColor == Color(r: 255, g: 255, b: 255, a: 255)
    check Hsv(h: 360, s: 1, v: 1).toColor == Hsv(h: 0, s: 1, v: 1).toColor
    check Color(r: 255, g: 0, b: 0, a: 255).toHsv.h == 0
    check Color(r: 0, g: 0, b: 255, a: 255).toHsv.h == 240

  test "rgb -> hsv -> rgb is exact for every grey and a sweep of colours":
    for v in 0 .. 255:
      let c = Color(r: uint8(v), g: uint8(v), b: uint8(v), a: 255)
      check c.toHsv.toColor == c
    for r in countup(0, 255, 17):
      for g in countup(0, 255, 17):
        for b in countup(0, 255, 17):
          let c = Color(r: uint8(r), g: uint8(g), b: uint8(b), a: 255)
          check c.toHsv.toColor == c
