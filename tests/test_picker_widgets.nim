## Date, time and colour pickers, Autocomplete, RangeSlider, Icon, Dialog and
## the SearchInput clear button -- driven with real events, no window.

import std/[unittest, options, monotimes, unicode]
import rui
from raylib import KeyboardKey

proc key(k: KeyboardKey, focused: Widget = nil): GuiEvent =
  GuiEvent(kind: evKeyDown, key: k, timestamp: getMonoTime())

proc press(x, y: float32): GuiEvent =
  GuiEvent(kind: evMouseDown, mousePos: Point(x: x, y: y), timestamp: getMonoTime())

proc typed(c: char): GuiEvent =
  GuiEvent(kind: evChar, rune: Rune(ord(c)), timestamp: getMonoTime())

proc settle(w: Widget, width = 400.0'f32) =
  inc layoutPassNumber
  w.bounds = Rect(x: 20, y: 20, width: 0, height: 0)
  w.layoutDirty = true
  w.layoutPass()

suite "TimePicker":

  test "Up and Down step the focused part and wrap":
    let t = newTimePicker(initialValue = "23:58", minuteStep = 1)
    t.focused = true
    check t.handleInput(key(KeyboardKey.Up))              # hour 23 -> 00
    check t.value == "00:58"
    discard t.handleInput(key(KeyboardKey.Right))
    discard t.handleInput(key(KeyboardKey.Up))
    discard t.handleInput(key(KeyboardKey.Up))
    check t.value == "00:00"                              # minutes wrap, no carry
    discard t.handleInput(key(KeyboardKey.Down))
    check t.value == "00:59"

  test "digits type a part and move on":
    let t = newTimePicker(initialValue = "00:00")
    t.focused = true
    for c in "1435": discard t.handleInput(typed(c))
    check t.value == "14:35"

  test "a hour that cannot be a tens digit completes at once":
    let t = newTimePicker(initialValue = "00:00")
    t.focused = true
    discard t.handleInput(typed('7'))
    check t.value == "07:00"
    check t.part == 1

  test "minuteStep":
    let t = newTimePicker(initialValue = "10:00", minuteStep = 15)
    t.focused = true
    discard t.handleInput(key(KeyboardKey.Right))
    discard t.handleInput(key(KeyboardKey.Up))
    check t.value == "10:15"

  test "onChange reports text, and not when nothing changed":
    var heard: seq[string]
    let t = newTimePicker(initialValue = "10:00", onChange = proc(v: string) = heard.add v)
    t.focused = true
    discard t.handleInput(key(KeyboardKey.Up))
    check heard == @["11:00"]

  test "12-hour mode flips AM/PM with the third part":
    let t = newTimePicker(initialValue = "09:30", use24h = false)
    t.focused = true
    discard t.handleInput(key(KeyboardKey.Right))
    discard t.handleInput(key(KeyboardKey.Right))
    discard t.handleInput(key(KeyboardKey.Up))
    check t.value == "21:30"

  test "stepPart":
    check stepPart(23 * 60 + 59, 0, 1, 1, true) == 59
    check stepPart(0, 1, -1, 5, true) == 55

suite "DatePicker":

  test "arrows move the value by day, week and month":
    let d = newDatePicker(initialValue = "2026-10-11")
    d.focused = true
    discard d.handleInput(key(KeyboardKey.Right))
    check d.value == "2026-10-12"
    discard d.handleInput(key(KeyboardKey.Down))
    check d.value == "2026-10-19"
    discard d.handleInput(key(KeyboardKey.Up))
    discard d.handleInput(key(KeyboardKey.Left))
    check d.value == "2026-10-11"
    discard d.handleInput(key(KeyboardKey.PageDown))
    check d.value == "2026-11-11"

  test "clicking a day in the open calendar picks it and closes":
    var picked = ""
    let d = newDatePicker(initialValue = "2026-10-11", onChange = proc(v: string) = picked = v)
    settle d
    discard d.handleInput(press(d.bounds.x + 5, d.bounds.y + 5))   # open
    check d.isOpen
    settle d
    let cells = calendarCells(2026, 10)
    var target = -1
    for i, c in cells:
      if c == Ymd(year: 2026, month: 10, day: 20): target = i
    let r = calCellRect(d.popup.bounds, target)
    discard d.popup.handleInput(press(r.x + 3, r.y + 3))
    check picked == "2026-10-20"
    check not d.isOpen

  test "the arrows in the header change the month shown, not the value":
    let d = newDatePicker(initialValue = "2026-10-11")
    settle d
    discard d.handleInput(press(d.bounds.x + 5, d.bounds.y + 5))
    settle d
    let n = calNextRect(d.popup.bounds)
    discard d.popup.handleInput(press(n.x + 3, n.y + 3))
    check d.viewMonth == 11
    check d.value == "2026-10-11"

  test "an empty picker starts on today when a key opens it":
    let d = newDatePicker()
    d.focused = true
    discard d.handleInput(key(KeyboardKey.Enter))
    check parseIsoDate(d.value).isSome

suite "ColorPicker":

  test "the square sets saturation and value, the bar the hue":
    let c = newColorPicker(initialValue = "#ff0000")
    settle c
    discard c.handleInput(press(c.bounds.x + 5, c.bounds.y + 5))
    settle c
    let sv = colSvRect(c.popup.bounds)
    discard c.popup.handleInput(press(sv.x + sv.width / 2, sv.y + sv.height / 2))
    let mid = parseHexColor(c.value).get.toHsv
    check abs(mid.s - 0.5) < 0.02 and abs(mid.v - 0.5) < 0.02
    let bar = colHueRect(c.popup.bounds)
    discard c.popup.handleInput(press(bar.x + bar.width / 3, bar.y + 4))
    check abs(c.hsv.h - 120) < 2

  test "hue survives full desaturation":
    let c = newColorPicker(initialValue = "#00ff00")
    c.focused = true
    let hue = c.hsv.h
    c.hsv.s = 0
    discard c.handleInput(key(KeyboardKey.Up))
    check c.hsv.h == hue

  test "arrows turn the hue and brighten":
    let c = newColorPicker(initialValue = "#ff0000")
    c.focused = true
    discard c.handleInput(key(KeyboardKey.Right))
    check c.hsv.h == 5
    discard c.handleInput(key(KeyboardKey.Down))
    check c.hsv.v < 1

  test "a bad initial value falls back to a real colour":
    let c = newColorPicker(initialValue = "nonsense")
    check parseHexColor(c.value).isSome

suite "Autocomplete":

  test "prefix matches come before substring matches, case ignored, exact excluded":
    check suggestionsFor(["Bergen", "Bern", "Berlin", "Amber"], "ber", 10) ==
          @["Bergen", "Bern", "Berlin", "Amber"]
    check suggestionsFor(["Bern", "Bergen"], "bern", 10).len == 0       # exact already
    check suggestionsFor(["a1", "a2", "a3"], "a", 2).len == 2
    check suggestionsFor(["x"], "", 5).len == 0

  test "typing opens the list; Down and Enter take a suggestion":
    var picked = ""
    let a = newAutocomplete(suggestions = @["Berlin", "Bern"],
                            onPick = proc(s: string) = picked = s)
    settle a
    a.input.focused = true
    for ch in "ber": discard a.input.handleInput(typed(ch))
    check a.matches == @["Berlin", "Bern"]
    check a.isOpen
    check a.handleInput(key(KeyboardKey.Down))
    check a.hoverIndex == 0
    discard a.input.handleInput(key(KeyboardKey.Enter))
    check picked == "Berlin"
    check a.input.text == "Berlin"
    check not a.isOpen

  test "Escape closes the list but keeps the text":
    let a = newAutocomplete(suggestions = @["Berlin"])
    settle a
    a.input.focused = true
    for ch in "ber": discard a.input.handleInput(typed(ch))
    check a.handleInput(key(KeyboardKey.Escape))
    check not a.isOpen and a.input.text == "ber"

suite "RangeSlider":

  test "the nearest thumb is taken":
    check nearestThumb(10, 20, 80) == 0
    check nearestThumb(70, 20, 80) == 1
    check nearestThumb(30, 50, 50) == 0
    check nearestThumb(60, 50, 50) == 1

  test "thumbs never cross":
    let r = newRangeSlider(initialLow = 30, initialHigh = 40)
    r.focused = true
    r.active = 0
    for i in 0 ..< 30: discard r.handleInput(key(KeyboardKey.Right))
    check r.low == 40 and r.high == 40
    discard r.handleInput(key(KeyboardKey.Space))
    discard r.handleInput(key(KeyboardKey.Left))
    check r.high == 40                          # blocked by the low thumb

  test "dragging moves the closer thumb and reports both":
    var heard: tuple[lo, hi: float32]
    let r = newRangeSlider(initialLow = 20, initialHigh = 80,
                           onChange = proc(lo, hi: float32) = heard = (lo, hi))
    r.bounds = Rect(x: 0, y: 0, width: 200, height: 24)
    discard r.handleInput(press(180, 12))
    check heard.hi == 90 and heard.lo == 20
    discard r.handleInput(GuiEvent(kind: evMouseUp, mousePos: Point(x: 180, y: 12)))
    discard r.handleInput(press(20, 12))
    check heard.lo == 10

suite "Dialog":

  test "closed it is invisible; show makes it a modal, Escape closes":
    var closed = 0
    let d = ui:
      Dialog(title = "Rename", onClose = proc() = inc closed):
        Label(text = "Name")
    check not d.visible
    d.show()
    check d.visible and d.isOpen
    check d.handleInput(press(1, 1))             # a modal takes every click
    check d.handleInput(key(KeyboardKey.Escape))
    check not d.visible and closed == 1

  test "closeOnBackdrop closes on a click outside the panel only":
    let d = ui:
      Dialog(title = "x", closeOnBackdrop = true):
        Label(text = "hello")
    d.bounds = Rect(x: 0, y: 0, width: 800, height: 600)
    d.show()
    discard d.handleInput(press(400, 300))       # inside the centred panel
    check d.isOpen
    discard d.handleInput(press(5, 5))
    check not d.isOpen

suite "Icon and SearchInput":

  test "an Icon with onClick is a click target":
    var clicks = 0
    let i = newIcon(glyph = "*", onClick = proc() = inc clicks)
    check i.handleInput(press(1, 1))
    check clicks == 1
    check not newIcon(glyph = "*").handleInput(press(1, 1))

  test "the search field's x empties it, and so does Escape":
    let s = newSearchInput(initialText = "hello")
    s.bounds = Rect(x: 0, y: 0, width: 200, height: 32)
    s.focused = true
    check s.clearRect.contains(190, 16)
    check s.handleInput(press(190, 16))
    check s.text == ""
    s.replaceText("again")
    check s.handleInput(key(KeyboardKey.Escape))
    check s.text == ""
    check not s.handleInput(key(KeyboardKey.Escape))     # empty: Escape is someone else's
