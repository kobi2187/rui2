## Widgets as a user drives them: pointer and keyboard events through the real
## router, state asserted after each step. One suite per widget; each scenario
## names the behaviour, so a red test says what broke and where.

import std/[unittest, sets, sequtils]
import rui
import ui_harness
from raylib import KeyboardKey, Space, Enter, Escape, Left, Right, Up, Down, Home, End, Tab, PageDown, PageUp

suite "Button":
  var clicks = 0
  proc rig(): (Rig, Button) =
    clicks = 0
    let b = newButton(text = "Go")
    b.onClick = proc() = inc clicks
    (newRig(stack(b)), b)

  test "click fires once and leaves it neither pressed nor hovered-sticky":
    let (r, b) = rig()
    r.click(b)
    check clicks == 1
    check not b.isPressed
  test "press shows pressed, release restores":
    let (r, b) = rig()
    let c = centre(b)
    r.press(c.x, c.y)
    check b.isPressed
    r.release(c.x, c.y)
    check not b.isPressed
  test "press, drag out, release outside: no click, not stuck":
    let (r, b) = rig()
    let c = centre(b)
    r.press(c.x, c.y)
    r.release(390, 290)
    check clicks == 0
    check not b.isPressed
  test "hover on enter, off on leave":
    let (r, b) = rig()
    r.moveTo(b)
    check b.isHovered
    r.moveTo(390, 290)
    check not b.isHovered
  test "three clicks fire three times":
    let (r, b) = rig()
    for _ in 1 .. 3: r.click(b)
    check clicks == 3
  test "disabled button ignores clicks":
    let (r, b) = rig()
    b.disabled = true
    r.click(b)
    check clicks == 0
  test "keyboard: Space and Enter activate when focused":
    let (r, b) = rig()
    r.focus(b)
    r.key(Space)
    r.key(Enter)
    check clicks == 2
  test "click elsewhere does not fire":
    let (r, b) = rig()
    r.click(390, 290)
    check clicks == 0

suite "Checkbox":
  proc rig(): (Rig, Checkbox, ref seq[bool]) =
    let log = new seq[bool]
    let c = newCheckbox(text = "Opt")
    c.onToggle = proc(v: bool) = log[].add v
    (newRig(stack(c)), c, log)

  test "click toggles on then off and reports each":
    let (r, c, log) = rig()
    r.click(c); check c.checked
    r.click(c); check not c.checked
    check log[] == @[true, false]
  test "Space toggles when focused":
    let (r, c, _) = rig()
    r.focus(c); r.key(Space)
    check c.checked
  test "press outside then release on it does not toggle":
    let (r, c, _) = rig()
    r.press(390, 290)
    let p = centre(c)
    r.release(p.x, p.y)
    check not c.checked
  test "disabled does not toggle":
    let (r, c, _) = rig()
    c.disabled = true
    r.click(c)
    check not c.checked
  test "initialChecked is honoured":
    let c = newCheckbox(text = "x", initialChecked = true)
    check c.checked

suite "Slider":
  proc rig(): (Rig, Slider, ref seq[float32]) =
    let log = new seq[float32]
    let s = newSlider(minValue = 0, maxValue = 100, initialValue = 50, showValue = false)
    s.onChange = proc(v: float32) = log[].add v
    (newRig(stack(s)), s, log)

  test "click at the left end sets minimum, right end maximum":
    let (r, s, _) = rig()
    r.clickAt(s, 1, s.bounds.height / 2)
    check s.value <= 3
    r.clickAt(s, s.bounds.width - 1, s.bounds.height / 2)
    check s.value >= 97
  test "click in the middle is about half":
    let (r, s, _) = rig()
    r.clickAt(s, s.bounds.width * 0.25, s.bounds.height / 2)
    check abs(s.value - 25) < 8
  test "drag moves value monotonically and ends not dragging":
    let (r, s, log) = rig()
    let y = s.bounds.y + s.bounds.height / 2
    r.drag(s.bounds.x + 10, y, s.bounds.x + s.bounds.width - 10, y)
    check not s.dragging
    check s.value > 80
    check log[].len > 1
  test "drag past the end clamps":
    let (r, s, _) = rig()
    let y = s.bounds.y + s.bounds.height / 2
    r.drag(s.bounds.x + 20, y, 399, y)
    check s.value <= 100
    r.drag(s.bounds.x + 20, y, 0, y)
    check s.value >= 0
  test "arrows, Home, End when focused":
    let (r, s, _) = rig()
    r.focus(s)
    r.key(Right); check s.value > 50
    r.key(Left); r.key(Left); check s.value < 50
    r.key(Home); check s.value == 0
    r.key(End); check s.value == 100
  test "wheel changes the value":
    let (r, s, _) = rig()
    let c = centre(s)
    r.wheel(c.x, c.y, 1)
    check s.value == 50                  # by design: only a focused slider takes the wheel
    r.focus(s)
    r.wheel(c.x, c.y, 1)
    check s.value > 50
    r.wheel(c.x, c.y, -1)
    r.wheel(c.x, c.y, -1)
    check s.value < 50

suite "ComboBox":
  proc rig(): (Rig, ComboBox, ref seq[int]) =
    let log = new seq[int]
    let c = newComboBox(items = @["a", "b", "c"], initialSelectedIndex = 0)
    c.onSelect = proc(i: int) = log[].add i
    (newRig(stack(c)), c, log)

  test "click opens, second click closes":
    let (r, c, _) = rig()
    r.click(c); check c.isOpen
    r.click(c); check not c.isOpen
  test "picking an item selects it and closes":
    let (r, c, log) = rig()
    r.click(c)
    check c.isOpen
    let row = c.list.bounds
    r.click(row.x + row.width / 2, row.y + c.itemHeight * 2 + c.itemHeight / 2)
    check c.selectedIndex == 2
    check not c.isOpen
    check log[] == @[2]
  test "click outside closes without changing selection":
    let (r, c, log) = rig()
    r.click(c)
    r.click(390, 290)
    check not c.isOpen
    check c.selectedIndex == 0
    check log[].len == 0
  test "Escape closes an open list":
    let (r, c, _) = rig()
    r.click(c); r.key(Escape)
    check not c.isOpen
  test "disabled never opens":
    let (r, c, _) = rig()
    c.disabled = true
    r.click(c)
    check not c.isOpen

suite "SegmentedControl":
  test "clicking a segment selects exactly that one":
    let s = newSegmentedControl(options = @["A", "B", "C"])
    let r = newRig(stack(s))
    var got = -1
    s.onSelect = proc(i: int) = got = i
    # Segments size to their text, so sweep the width and watch the order.
    var seen: seq[int]
    var x = 2.0'f32
    while x < s.bounds.width:
      r.clickAt(s, x, s.bounds.height / 2)
      if s.selectedIndex notin seen: seen.add s.selectedIndex
      x += 4
    check seen == @[0, 1, 2]
    check got == 2
    r.clickAt(s, 2, s.bounds.height / 2)
    check s.selectedIndex == 0

suite "RadioGroup":
  test "click selects option; others deselect":
    let g = newRadioGroup(options = @["x", "y", "z"])
    let r = newRig(stack(g))
    r.clickAt(g, 10, g.spacing * 1 + 8)
    check g.selectedIndex == 1
    r.clickAt(g, 10, g.spacing * 2 + 8)
    check g.selectedIndex == 2
  test "hover tracks pointer and clears on leave":
    let g = newRadioGroup(options = @["x", "y", "z"])
    let r = newRig(stack(g))
    r.moveTo(g.bounds.x + 10, g.bounds.y + g.spacing + 8)
    check g.hoverIndex == 1
    r.moveTo(390, 290)
    check g.hoverIndex == -1

suite "TabControl":
  test "clicking tabs switches the active tab and reports":
    let t = newTabControl(tabs = @["One", "Two", "Three"])
    let r = newRig(stack(t))
    var seen: seq[int]
    t.onTabChanged = proc(i: int) = seen.add i
    let third = t.bounds.x + t.bounds.width * 0.85
    r.click(third, t.bounds.y + 8)
    check t.activeTab == 2
    check seen == @[2]
  test "tab hover clears on leave":
    let t = newTabControl(tabs = @["One", "Two"])
    let r = newRig(stack(t))
    r.moveTo(t.bounds.x + 20, t.bounds.y + 8)
    check t.hoverTab >= 0
    r.moveTo(390, 290)
    check t.hoverTab == -1

suite "Rating":
  test "click sets value; preview clears after leaving":
    let g = newRating(maxStars = 5)
    let r = newRig(stack(g))
    var got = 0
    g.onRate = proc(v: int) = got = v
    let pitch = currentTheme.indicatorSize * 1.2'f32 + 4
    r.clickAt(g, pitch * 2.5, g.bounds.height / 2)
    check g.value == 3
    check got == g.value
    r.moveTo(390, 290)
    check g.preview == 0
  test "readOnly ignores clicks":
    let g = newRating(maxStars = 5, readOnly = true)
    let r = newRig(stack(g))
    let pitch = currentTheme.indicatorSize * 1.2'f32 + 4
    r.clickAt(g, pitch * 2.5, g.bounds.height / 2)
    check g.value == 0

suite "Expander":
  test "clicking the header toggles":
    let e = newExpander(title = "More")
    let r = newRig(stack(e))
    check e.expanded
    r.clickAt(e, 20, 10)
    check not e.expanded
    r.clickAt(e, 20, 10)
    check e.expanded

let rowH = currentTheme.rowHeight(24.0)

suite "ListView":
  proc rig(n = 40): (Rig, ListView) =
    let items = toSeq(0 ..< n).mapIt("item " & $it)
    let l = newListView(items = items, visibleRows = 8)
    (newRig(stack(l)), l)

  test "click selects that row only":
    let (r, l) = rig()
    r.clickAt(l, 20, rowH * 2.5)
    check l.selection == [2].toHashSet
    r.clickAt(l, 20, rowH * 4.5)
    check l.selection == [4].toHashSet
  test "wheel scrolls down then back":
    let (r, l) = rig()
    let c = centre(l)
    r.wheel(c.x - 20, c.y, -3)
    check l.scrollY > 0
    let down = l.scrollY
    r.wheel(c.x - 20, c.y, 3)
    check l.scrollY < down
  test "scroll never goes below zero or past the end":
    let (r, l) = rig()
    let c = centre(l)
    r.wheel(c.x - 20, c.y, 100)
    check l.scrollY == 0
    for _ in 1 .. 60: r.wheel(c.x - 20, c.y, -5)
    check l.scrollY <= rowH * 40
    check l.scrollY > 0
  test "keyboard arrows move the focus row and Home/End jump":
    let (r, l) = rig()
    r.focus(l)
    r.key(Down); r.key(Down)
    check l.focusIndex == 2 or l.focusIndex == 1
    r.key(End)
    check l.focusIndex == 39
    r.key(Home)
    check l.focusIndex == 0
  test "scrollbar thumb drag scrolls; release ends drag":
    let (r, l) = rig()
    let x = l.bounds.x + l.bounds.width - 4
    r.drag(x, l.bounds.y + 12, x, l.bounds.y + 60)
    check l.scrollY > 0
    check not l.barDragging
  test "hover tracks rows and clears on leave":
    let (r, l) = rig()
    r.moveTo(l.bounds.x + 20, l.bounds.y + rowH * 1.5)
    check l.hoverIndex == 1
    r.moveTo(390, 290)
    check l.hoverIndex == -1

suite "TextInput through the router":
  test "click focuses, typing inserts, Backspace deletes":
    let t = newTextInput(initialText = "")
    let r = newRig(stack(t))
    r.click(t)
    check r.app.currentFocusedWidget() == Widget(t)
    r.typeText("abc")
    check t.text == "abc"
  test "typing without focus changes nothing":
    let t = newTextInput(initialText = "x")
    let r = newRig(stack(t))
    r.typeText("zz")
    check t.text == "x"
  test "Tab moves focus between inputs":
    let a = newTextInput(initialText = "")
    let b = newTextInput(initialText = "")
    let r = newRig(stack(a, b))
    r.focus(a)
    r.key(Tab)
    check r.app.currentFocusedWidget() == Widget(b)
    r.typeText("q")
    check b.text == "q"
    check a.text == ""
