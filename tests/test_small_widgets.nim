## Switch, SegmentedControl, Rating, Sparkline, Toast: small widgets, each with
## its arithmetic checked as plain values and its behaviour through real events.

import std/[unittest, math, monotimes, times, options, sets]
import rui
from raylib import KeyboardKey

proc down(x, y: float32): GuiEvent = GuiEvent(kind: evMouseDown, mousePos: Point(x: x, y: y))
proc key(k: string): GuiEvent = GuiEvent(kind: evKeyDown, key: chord(k).key)

suite "Switch":

  setup:
    setCurrentTheme(brandTheme(daylightSpec()))

  test "initialOn seeds the state, and a click toggles it and reports":
    let s = newSwitch(text = "Notifications", initialOn = true)
    check s.on
    var seen: seq[bool]
    s.onToggle = proc(on: bool) = seen.add on
    s.bounds = Rect(x: 0, y: 0, width: 150, height: 24)
    check s.handleInput(down(10, 10))
    check not s.on
    discard s.handleInput(down(10, 10))
    check seen == @[false, true]

  test "Space and Enter toggle it only while it has focus":
    let s = newSwitch()
    check not s.handleInput(key("Space"))
    s.focused = true
    check s.handleInput(key("Space"))
    check s.on
    check s.handleInput(key("Enter"))
    check not s.on

  test "a disabled switch does nothing":
    let s = newSwitch(disabled = true)
    check not s.handleInput(down(5, 5))
    check not s.on

  test "the track and thumb arithmetic":
    check switchTrack(20) == (36.0'f32, 20.0'f32)
    let track = Rect(x: 10, y: 0, width: 36, height: 20)
    check thumbX(track, 0) == 12.0                 # 2px in from the left
    check thumbX(track, 1) == 28.0                # flush with the right margin
    check thumbX(track, 0.5) > thumbX(track, 0) and thumbX(track, 0.5) < thumbX(track, 1)
    check thumbX(track, 5) == thumbX(track, 1)     # clamped

  test "the thumb is where it should be once settled, with no animation":
    animationsEnabled = false
    defer: animationsEnabled = true
    let s = newSwitch(initialOn = true)
    s.layout()
    check s.thumbT == 1.0
    s.on = false
    s.layout()
    check s.thumbT == 0.0

suite "SegmentedControl":

  test "edges and hit-testing":
    let w = [40.0'f32, 60.0, 50.0]
    check segmentEdges(w) == @[0.0'f32, 40, 100, 150]
    check segmentAt(w, 0) == 0 and segmentAt(w, 39.9) == 0
    check segmentAt(w, 40) == 1 and segmentAt(w, 149) == 2
    check segmentAt(w, 150) == -1 and segmentAt(w, -1) == -1

  test "a click selects the segment under it, reporting only changes":
    setCurrentTheme(brandTheme(daylightSpec()))
    let c = newSegmentedControl(options = @["Day", "Week", "Month"], initialSelectedIndex = 1)
    c.bounds = Rect(x: 0, y: 0, width: 0, height: 0)
    c.layout()
    var picked: seq[int]
    c.onSelect = proc(i: int) = picked.add i
    check c.selectedIndex == 1
    discard c.handleInput(down(c.bounds.x + c.bounds.width - 5, c.bounds.y + 5))   # last segment
    check c.selectedIndex == 2
    discard c.handleInput(down(c.bounds.x + c.bounds.width - 5, c.bounds.y + 5))   # again: no change
    check picked == @[2]

  test "Left and Right step, and at the ends leave the key for navigation":
    let c = newSegmentedControl(options = @["a", "b", "c"], initialSelectedIndex = 1)
    c.focused = true
    check c.handleInput(key("Right"))
    check c.selectedIndex == 2
    check not c.handleInput(key("Right"))          # at the end: not ours
    check c.handleInput(key("Left"))
    check c.selectedIndex == 1

suite "Rating":

  test "a star has ten corners, point up":
    let p = starPoints(50, 50, 10)
    check p[0].x == 50 and abs(p[0].y - 40) < 1e-4          # the top point
    for k in 0 ..< 10:
      let d = sqrt((p[k].x - 50) ^ 2 + (p[k].y - 50) ^ 2)
      check abs(d - (if k mod 2 == 0: 10.0'f32 else: 4.0'f32)) < 1e-3

  test "which star a point is over":
    check starAt(5, 0, 24, 5) == 1
    check starAt(30, 0, 24, 5) == 2
    check starAt(119, 0, 24, 5) == 5
    check starAt(120, 0, 24, 5) == 0              # past the last
    check starAt(-1, 0, 24, 5) == 0

  test "clicking sets the rating; clicking the current one clears it":
    setCurrentTheme(brandTheme(daylightSpec()))
    let r = newRating(initialValue = 2)
    r.layout()
    var got: seq[int]
    r.onRate = proc(v: int) = got.add v
    let step = currentTheme.indicatorSize * 1.2'f32 + 4
    discard r.handleInput(down(r.bounds.x + step * 3 + 2, r.bounds.y + 5))   # 4th star
    check r.value == 4
    discard r.handleInput(down(r.bounds.x + step * 3 + 2, r.bounds.y + 5))   # same: clear
    check r.value == 0
    check got == @[4, 0]

  test "read-only and disabled ratings cannot be changed":
    let r = newRating(initialValue = 3, readOnly = true)
    r.layout()
    check not r.handleInput(down(r.bounds.x + 2, r.bounds.y + 5))
    check r.value == 3

  test "arrow keys adjust within 0..maxStars":
    let r = newRating(maxStars = 5, initialValue = 5)
    r.focused = true
    check not r.handleInput(key("Up"))             # already at the top
    check r.handleInput(key("Down"))
    check r.value == 4

suite "Sparkline":

  let area = Rect(x: 0, y: 0, width: 100, height: 20)

  test "the smallest value is at the bottom, the largest at the top, spread evenly":
    let p = sparkPoints([1.0, 5.0, 3.0], area)
    check p.len == 3
    check p[0] == (0.0'f32, 20.0'f32)             # min: bottom left
    check p[1] == (50.0'f32, 0.0'f32)             # max: top, middle
    check p[2].x == 100 and p[2].y == 10          # halfway up

  test "a flat series sits in the middle, a single value is centred":
    check sparkPoints([4.0, 4.0, 4.0], area)[1].y == 10
    check sparkPoints([7.0], area) == @[(50.0'f32, 10.0'f32)]

  test "NaN is skipped and an empty series is empty":
    check sparkPoints([1.0, NaN, 3.0], area).len == 2
    check sparkPoints(newSeq[float](), area).len == 0

suite "Toast":

  test "a toast is an overlay at the bottom centre, and goes by itself":
    clearOverlays()
    clearRepaints()
    let app = newApp("toast")
    app.toast("Saved", seconds = 3.0)
    check overlays().len == 1
    let t = overlays()[0]
    check abs((t.bounds.x + t.bounds.width / 2) - app.window.width.float32 / 2) < 1
    check t.bounds.y + t.bounds.height <= app.window.height.float32
    check nextRepaint().isSome                    # an idle window wakes to remove it
    app.pruneToasts(getMonoTime())                # too early
    check overlays().len == 1
    app.pruneToasts(getMonoTime() + initDuration(seconds = 4))
    check overlays().len == 0
    clearRepaints()

  test "several toasts stack upwards without overlapping, and close up when one goes":
    clearOverlays()
    let app = newApp("toast")
    app.toast("first", seconds = 1.0)
    app.toast("second", seconds = 10.0)
    let a = overlays()[0]
    let b = overlays()[1]
    check b.bounds.y > a.bounds.y                 # the newer one is lowest
    check a.bounds.y + a.bounds.height < b.bounds.y
    app.pruneToasts(getMonoTime() + initDuration(seconds = 2))
    check overlays().len == 1
    check overlays()[0].bounds.y + overlays()[0].bounds.height <= app.window.height.float32 - 24 + 0.5
    clearOverlays()
    clearRepaints()

suite "Space and Enter press a focused button-like control":

  test "a Button, but not a Slider":
    let app = newApp("press")
    let root = newVStack()
    let b = newButton(text = "Go")
    let s = newSlider()
    root.addChild b
    root.addChild s
    root.bounds = Rect(x: 0, y: 0, width: 300, height: 200)
    root.layout()
    app.setRootWidget(root)
    var clicks = 0
    b.onClick = proc() = inc clicks
    app.focusManager.setFocus(b)
    check app.pressFocused(key("Space"))
    check clicks == 1
    app.focusManager.setFocus(s)
    let before = s.value
    check not app.pressFocused(key("Space"))
    check s.value == before                       # no jump to the middle

suite "slider from the keyboard and the wheel":
  proc send(w: Widget, e: GuiEvent): bool =
    var e = e
    e.timestamp = getMonoTime()
    w.handleInput(e)

  proc focusedSlider(step = 0.0'f32): Slider =
    result = newSlider(initialValue = 50, minValue = 0, maxValue = 100, step = step)
    result.focused = true

  test "arrows move a step, PageUp/PageDown ten, Home/End to the ends":
    let s = focusedSlider(step = 5)
    check s.send(GuiEvent(kind: evKeyDown, key: KeyboardKey.Right))
    check s.value == 55
    discard s.send(GuiEvent(kind: evKeyDown, key: KeyboardKey.Down))
    check s.value == 50
    discard s.send(GuiEvent(kind: evKeyDown, key: KeyboardKey.PageUp))
    check s.value == 100                                   # clamped at the top
    discard s.send(GuiEvent(kind: evKeyDown, key: KeyboardKey.Home))
    check s.value == 0
    discard s.send(GuiEvent(kind: evKeyDown, key: KeyboardKey.End))
    check s.value == 100

  test "with no step, a step is a hundredth of the range":
    let s = focusedSlider()
    discard s.send(GuiEvent(kind: evKeyDown, key: KeyboardKey.Left))
    check s.value == 49

  test "the wheel moves it only while focused":
    let s = focusedSlider(step = 1)
    check s.send(GuiEvent(kind: evMouseWheel, wheelDelta: 1))
    check s.value == 51
    s.focused = false
    check not s.send(GuiEvent(kind: evMouseWheel, wheelDelta: 1))
    check s.value == 51

  test "unfocused, it leaves the keys alone":
    let s = newSlider(initialValue = 50)
    check not s.send(GuiEvent(kind: evKeyDown, key: KeyboardKey.Right))

  test "dragging snaps to the step":
    check snapped(47.3, 0, 5) == 45
    check snapped(47.3, 0, 0) == 47.3'f32
    check stepValue(97, 0, 100, 5, 1) == 100

suite "list view from the keyboard":
  proc send(w: Widget, e: GuiEvent): bool =
    var e = e
    e.timestamp = getMonoTime()
    w.handleInput(e)

  proc list(multi = false): ListView =
    var items: seq[string]
    for i in 0 ..< 50: items.add "item " & $i
    result = newListView(items = items, multiSelect = multi, itemHeight = 20)
    result.bounds = Rect(x: 0, y: 0, width: 200, height: 100)   # five rows
    result.focused = true

  test "Down moves the focus and the selection follows":
    let l = list()
    var fired = 0
    l.onSelect = proc(s: HashSet[int]) = inc fired
    discard l.send(GuiEvent(kind: evKeyDown, key: KeyboardKey.Down))
    discard l.send(GuiEvent(kind: evKeyDown, key: KeyboardKey.Down))
    check l.focusIndex == 2 and l.selection == [2].toHashSet
    check fired == 2

  test "End goes to the last row and scrolls it into view":
    let l = list()
    discard l.send(GuiEvent(kind: evKeyDown, key: KeyboardKey.End))
    check l.focusIndex == 49
    check l.scrollY == float32(49 * 20 - 100 + 20)

  test "Shift+Down selects a range in a multi-select list":
    let l = list(multi = true)
    discard l.send(GuiEvent(kind: evKeyDown, key: KeyboardKey.Down, mods: {kmShift}))
    discard l.send(GuiEvent(kind: evKeyDown, key: KeyboardKey.Down, mods: {kmShift}))
    check l.selection == [0, 1, 2].toHashSet

  test "Ctrl moves the focus alone; Space toggles":
    let l = list(multi = true)
    discard l.send(GuiEvent(kind: evKeyDown, key: KeyboardKey.Space))
    discard l.send(GuiEvent(kind: evKeyDown, key: KeyboardKey.Down, mods: {kmCtrl}))
    discard l.send(GuiEvent(kind: evKeyDown, key: KeyboardKey.Down, mods: {kmCtrl}))
    discard l.send(GuiEvent(kind: evKeyDown, key: KeyboardKey.Space))
    check l.selection == [0, 2].toHashSet

  test "Ctrl+A selects everything; Enter activates the focused row":
    let l = list(multi = true)
    discard l.send(GuiEvent(kind: evKeyDown, key: KeyboardKey.A, mods: {kmCtrl}))
    check l.selection.len == 50
    var clicked = -1
    l.onItemClick = proc(i: int) = clicked = i
    discard l.send(GuiEvent(kind: evKeyDown, key: KeyboardKey.Down))
    discard l.send(GuiEvent(kind: evKeyDown, key: KeyboardKey.Enter))
    check clicked == 1

  test "a key that does not navigate is left to others":
    let l = list()
    check not l.send(GuiEvent(kind: evKeyDown, key: KeyboardKey.Tab))

suite "tree view from the keyboard":
  proc send(w: Widget, e: GuiEvent): bool =
    var e = e
    e.timestamp = getMonoTime()
    w.handleInput(e)
  proc key(w: Widget, k: KeyboardKey): bool =
    w.send(GuiEvent(kind: evKeyDown, key: k))

  proc tree(): TreeView =
    let root = TreeNode(id: "root", text: "root", expanded: true, children: @[
      TreeNode(id: "a", text: "a", children: @[
        TreeNode(id: "a1", text: "a1"), TreeNode(id: "a2", text: "a2")]),
      TreeNode(id: "b", text: "b")])
    result = newTreeView(rootNode = root, nodeHeight = 20)
    result.bounds = Rect(x: 0, y: 0, width: 200, height: 200)
    result.layout()
    result.focused = true

  test "Down walks the visible rows and selects them":
    let t = tree()
    var picked: seq[string]
    t.onSelect = proc(id: string) = picked.add id
    discard t.key(KeyboardKey.Down)                      # from root to a
    discard t.key(KeyboardKey.Down)                      # b (a is closed)
    check picked == @["a", "b"]

  test "Right opens a branch, then steps into it; Left steps out, then closes":
    let t = tree()
    discard t.key(KeyboardKey.Down)                      # a
    discard t.key(KeyboardKey.Right)
    check t.flatNodes.rowOf("a").int >= 0 and t.flatNodes[1].node.expanded
    check t.selectedId == "a"                            # opening does not move
    discard t.key(KeyboardKey.Right)
    check t.selectedId == "a1"
    discard t.key(KeyboardKey.Left)
    check t.selectedId == "a"                            # out to the parent
    discard t.key(KeyboardKey.Left)
    check not t.flatNodes[1].node.expanded               # then closed
    check t.flatNodes.len == 3

  test "Space toggles a branch; End goes to the last row":
    let t = tree()
    discard t.key(KeyboardKey.Down)
    discard t.key(KeyboardKey.Space)
    check t.flatNodes.len == 5
    discard t.key(KeyboardKey.End)
    check t.selectedId == "b"

suite "tabs from the keyboard":
  proc tabs(): tuple[t: TabControl, inside: Button] =
    let t = newTabControl(tabs = @["One", "Two", "Three"])
    let inside = newButton(text = "in page one")
    t.addChild inside
    t.addChild newLabel(text = "two")
    t.addChild newLabel(text = "three")
    t.bounds = Rect(x: 0, y: 0, width: 300, height: 200)
    t.layout()
    (t, inside)

  proc press(fm: FocusManager, root: Widget, k: KeyboardKey, mods: set[KeyMod] = {}): bool =
    fm.handleKeyboardEvent(GuiEvent(kind: evKeyDown, key: k, mods: mods,
                                    timestamp: getMonoTime()), root)

  test "Ctrl+Tab from a control inside a page goes to the next tab":
    let (t, inside) = tabs()
    let fm = newFocusManager()
    fm.setFocus(inside)
    check fm.press(t, KeyboardKey.Tab, {kmCtrl})
    check t.activeTab == 1
    check fm.press(t, KeyboardKey.Tab, {kmCtrl, kmShift})
    check t.activeTab == 0
    check fm.press(t, KeyboardKey.PageUp, {kmCtrl})
    check t.activeTab == 2                               # wraps round

  test "the focused strip takes Left/Right and Home/End":
    let (t, _) = tabs()
    let fm = newFocusManager()
    fm.setFocus(t)
    check fm.press(t, KeyboardKey.Right)
    check t.activeTab == 1
    check fm.press(t, KeyboardKey.End)
    check t.activeTab == 2
    check fm.press(t, KeyboardKey.Home)
    check t.activeTab == 0

  test "plain arrows inside a page are not taken by the tabs":
    let (t, inside) = tabs()
    let fm = newFocusManager()
    fm.setFocus(inside)
    discard fm.press(t, KeyboardKey.Right)
    check t.activeTab == 0
