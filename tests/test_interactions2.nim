## More widgets as a user drives them -- see test_interactions.nim.

import std/[unittest, sets, tables, json, sequtils, os, strutils]
import rui
import ui_harness
from raylib import KeyboardKey, Space, Enter, Escape, Left, Right, Up, Down, Home, End, Tab, Backspace, Delete, A

suite "Switch":
  test "click toggles and reports; Space toggles when focused; disabled ignores":
    let s = newSwitch(text = "Wifi")
    let r = newRig(stack(s))
    var log: seq[bool]
    s.onToggle = proc(v: bool) = log.add v
    r.click(s); check s.on
    r.click(s); check not s.on
    r.focus(s); r.key(Space); check s.on
    check log == @[true, false, true]
    s.disabled = true
    r.click(s); check s.on

suite "ToolButton and IconButton":
  test "ToolButton click fires; toggleable toggles and reports":
    let t = newToolButton(iconText = "B", toggleable = true)
    let r = newRig(stack(t))
    var states: seq[bool]
    t.onToggle = proc(v: bool) = states.add v
    r.click(t); check t.toggled
    r.click(t); check not t.toggled
    check states == @[true, false]
  test "ToolButton: press then leave then release is not stuck":
    let t = newToolButton(iconText = "B")
    let r = newRig(stack(t))
    var fired = 0
    t.onClick = proc() = inc fired
    let c = centre(t)
    r.press(c.x, c.y)
    r.release(390, 290)
    check not t.isPressed
    check fired == 0
  test "IconButton click fires once, not pressed afterwards":
    let b = newIconButton(iconText = "+")
    let r = newRig(stack(b))
    var fired = 0
    b.onClick = proc() = inc fired
    r.click(b)
    check fired == 1
    check not b.isPressed
  test "IconButton press, leave, release: no click, not stuck":
    let b = newIconButton(iconText = "+")
    let r = newRig(stack(b))
    var fired = 0
    b.onClick = proc() = inc fired
    let c = centre(b)
    r.press(c.x, c.y)
    r.release(390, 290)
    check fired == 0
    check not b.isPressed

suite "Hyperlink":
  test "click marks visited and fires both actions":
    let h = newHyperlink(text = "docs", url = "https://example.org")
    let r = newRig(stack(h))
    var clicked = 0
    var url = ""
    h.onClick = proc() = inc clicked
    h.onNavigate = proc(u: string) = url = u
    r.click(h)
    check h.visited
    check clicked == 1
    check url == "https://example.org"

suite "TextInput editing":
  proc rig(initial = ""): (Rig, TextInput) =
    let t = newTextInput(initialText = initial)
    let r = newRig(stack(t))
    r.click(t)
    (r, t)

  test "typing appends; Backspace and Delete remove":
    let (r, t) = rig()
    r.typeText("hello")
    r.key(Backspace)
    check t.text == "hell"
    r.key(Home); r.key(Delete)
    check t.text == "ell"
  test "arrows, Home and End move the caret":
    let (r, t) = rig("abc")
    r.key(End); check t.cursorPos == 3
    r.key(Left); check t.cursorPos == 2
    r.key(Home); check t.cursorPos == 0
    r.key(Right); check t.cursorPos == 1
  test "typing inserts at the caret":
    let (r, t) = rig("ac")
    r.key(Home); r.key(Right)
    r.typeText("b")
    check t.text == "abc"
  test "Shift+Right extends a selection; typing replaces it":
    let (r, t) = rig("hello")
    r.key(Home)
    r.key(Right, {kmShift}); r.key(Right, {kmShift})
    check t.selectionStart != t.selectionEnd
    r.typeText("J")
    check t.text == "Jllo"
  test "Ctrl+A selects everything; Backspace clears it":
    let (r, t) = rig("hello")
    r.key(A, {kmCtrl})
    r.key(Backspace)
    check t.text == ""
  test "Enter submits a single-line input":
    let (r, t) = rig("go")
    var got = ""
    t.onSubmit = proc(s: string) = got = s
    r.key(Enter)
    check got == "go"
    check t.text == "go"
  test "maxLength stops insertion":
    let t = newTextInput(initialText = "", maxLength = 3)
    let r = newRig(stack(t))
    r.click(t)
    r.typeText("abcdef")
    check t.text == "abc"
  test "onChange fires per edit":
    let (r, t) = rig()
    var log: seq[string]
    t.onChange = proc(s: string) = log.add s
    r.typeText("ab")
    check log.len >= 1
    check log[^1] == "ab"
  test "clicking inside text places the caret there":
    let (r, t) = rig("abcdefghij")
    sleep(600)                           # not a double-click
    r.clickAt(t, 3, t.bounds.height / 2)
    check t.cursorPos <= 1
    sleep(600)
    r.clickAt(t, t.bounds.width - 3, t.bounds.height / 2)
    check t.cursorPos >= 9 or t.cursorPos == 10
  test "drag selects a range":
    let (r, t) = rig("abcdefghij")
    r.drag(t.bounds.x + 4, t.bounds.y + t.bounds.height / 2, t.bounds.x + 60, t.bounds.y + t.bounds.height / 2)
    check abs(t.selectionEnd - t.selectionStart) >= 2
    check not t.dragging
  test "a disabled input takes no text":
    let t = newTextInput(initialText = "x", disabled = true)
    let r = newRig(stack(t))
    r.click(t)
    r.typeText("y")
    check t.text == "x"

suite "TextArea editing":
  test "Enter makes a new line; Up/Down move between lines":
    let t = newTextArea(initialText = "ab\ncd")
    let r = newRig(stack(t))
    r.click(t)
    r.key(End, {kmCtrl})
    r.typeText("!")
    check t.text == "ab\ncd!"
    r.key(Enter)
    r.typeText("x")
    check t.text == "ab\ncd!\nx"
  test "wheel scrolls a long document and stays in range":
    var lines: seq[string]
    for i in 0 ..< 200: lines.add "line " & $i
    let t = newTextArea(initialText = lines.join("\n"), visibleLines = 5)
    let r = newRig(stack(t))
    let c = centre(t)
    r.wheel(c.x, c.y, -3)
    check t.scrollY > 0
    for _ in 1 .. 100: r.wheel(c.x, c.y, 5)
    check t.scrollY == 0

suite "DataTable":
  proc rig(): (Rig, DataTable) =
    var rows: seq[DataRow]
    for (n, role) in [("ada", "eng"), ("grace", "adm"), ("alan", "eng")]:
      var v = initTable[string, JsonNode]()
      v["name"] = %n; v["role"] = %role
      rows.add DataRow(id: n, values: v)
    let t = newDataTable(
      columns = @[DataColumn(id: "name", title: "Name", width: 120.0, sortable: true),
                  DataColumn(id: "role", title: "Role", width: 120.0, sortable: true)],
      data = rows, visibleRows = 5)
    (newRig(stack(t)), t)

  test "clicking a row selects it; clicking another moves the selection":
    let (r, t) = rig()
    let rowH = currentTheme.rowHeight(24.0)
    let top = t.bounds.y + currentTheme.barHeight(28.0) + currentTheme.barHeight(26.0)
    r.click(t.bounds.x + 20, top + rowH * 0.5)
    check t.selected.len == 1
    let first = toSeq(t.selected)[0]
    r.click(t.bounds.x + 20, top + rowH * 1.5)
    check t.selected.len == 1
    check toSeq(t.selected)[0] != first
  test "header click sorts ascending then descending, reporting each":
    let (r, t) = rig()
    var log: seq[string]
    t.onSort = proc(c: string, o: SortOrder) = log.add c & $o
    let y = t.bounds.y + currentTheme.barHeight(26.0) + 8
    r.click(t.bounds.x + 30, y)
    r.click(t.bounds.x + 30, y)
    check log.len == 2
    check log[0] != log[1]
  test "hover row clears when the pointer leaves":
    let (r, t) = rig()
    let rowH = currentTheme.rowHeight(24.0)
    r.moveTo(t.bounds.x + 20, t.bounds.y + currentTheme.barHeight(28.0) + currentTheme.barHeight(26.0) + rowH * 0.5)
    check t.hoverRow >= 0
    r.moveTo(390, 290)
    check t.hoverRow == -1

suite "TreeView":
  proc rig(): (Rig, TreeView) =
    let root = TreeNode(id: "root", text: "root", expanded: true, children: @[
      TreeNode(id: "a", text: "a", expanded: false, children: @[TreeNode(id: "a1", text: "a1")]),
      TreeNode(id: "b", text: "b")])
    let t = newTreeView(rootNode = root, visibleRows = 6)
    (newRig(stack(t)), t)

  test "clicking a row selects it":
    let (r, t) = rig()
    let h = currentTheme.rowHeight(24.0)
    r.click(t.bounds.x + 80, t.bounds.y + h * 2.5)
    check t.selectedId in ["a", "b"]
  test "clicking the twisty expands and collapses, reporting":
    let (r, t) = rig()
    var log: seq[string]
    t.onExpand = proc(id: string) = log.add "+" & id
    t.onCollapse = proc(id: string) = log.add "-" & id
    let h = currentTheme.rowHeight(24.0)
    let n0 = t.flatNodes.len
    r.click(t.bounds.x + 20 + 6, t.bounds.y + h * 1.5)    # a's twisty, one indent in
    check t.flatNodes.len == n0 + 1
    r.click(t.bounds.x + 20 + 6, t.bounds.y + h * 1.5)
    check t.flatNodes.len == n0
    check log == @["+a", "-a"]
  test "hover clears on leave":
    let (r, t) = rig()
    r.moveTo(t.bounds.x + 40, t.bounds.y + 10)
    check t.hoveredId != ""
    r.moveTo(390, 290)
    check t.hoveredId == ""

suite "SplitView":
  test "dragging the divider changes the ratio within the minimums; release ends the drag":
    let s = newSplitView(initialRatio = 0.5)
    s.addChild(newLabel(text = "left"))
    s.addChild(newLabel(text = "right"))
    s.sizeRequest = Size(width: 300, height: 100)
    let r = newRig(stack(s), 400, 300)
    let y = s.bounds.y + 50
    let mid = s.bounds.x + s.bounds.width * 0.5
    var seen = 0.5'f32
    s.onResize = proc(v: float32) = seen = v
    r.drag(mid, y, s.bounds.x + s.bounds.width * 0.8, y)
    check s.ratio > 0.6
    check not s.dragging
    check seen == s.ratio
    r.drag(s.bounds.x + s.bounds.width * 0.8, y, s.bounds.x - 50, y)
    check s.ratio < 0.3
    check s.ratio > 0.0

suite "ScrollView":
  proc rig(): (Rig, ScrollView) =
    let sv = newScrollView()
    let col = newVStack(spacing = 4.0, padding = 4.0)
    for i in 0 ..< 40: col.addChild newLabel(text = "row " & $i)
    sv.addChild col
    sv.sizeRequest = Size(width: 200, height: 120)
    (newRig(stack(sv)), sv)

  test "wheel scrolls down and back, never below zero":
    let (r, sv) = rig()
    let c = centre(sv)
    r.wheel(c.x, c.y, -3)
    check sv.scrollOffsetY > 0
    let d = sv.scrollOffsetY
    r.wheel(c.x, c.y, 3)
    check sv.scrollOffsetY < d
    for _ in 1 .. 30: r.wheel(c.x, c.y, 5)
    check sv.scrollOffsetY == 0
  test "dragging the vertical thumb scrolls and releases cleanly":
    let (r, sv) = rig()
    let x = sv.bounds.x + sv.bounds.width - 4
    r.drag(x, sv.bounds.y + 10, x, sv.bounds.y + 60)
    check sv.scrollOffsetY > 0
    check sv.dragAxis == 0

suite "scroll bars on row widgets":
  ## One scenario for every widget that scrolls its own rows: the thumb drags,
  ## the track pages, the wheel scrolls, and none of them leave a drag behind.

  template scrollScenarios(name: string, build: untyped) =
    test name & ": dragging the thumb scrolls and ends cleanly":
      let (r, w) = build
      let x = w.bounds.x + w.bounds.width - 4
      let top = w.bounds.y + 40
      r.drag(x, top, x, top + 50)
      check w.scrollY > 0
      check not w.vbar.dragging
    test name & ": a track click below the thumb pages down, above it back up":
      let (r, w) = build
      let x = w.bounds.x + w.bounds.width - 4
      for _ in 1 .. 4: r.click(x, w.bounds.y + w.bounds.height - 6)
      check w.scrollY > 0
      let before = w.scrollY
      r.click(x, w.bounds.y + 42)      # the top of the track: above the thumb by now
      check w.scrollY < before
    test name & ": pointer over the bar shows bar hover; leaving clears it":
      let (r, w) = build
      let x = w.bounds.x + w.bounds.width - 4
      r.moveTo(x, w.bounds.y + 60)
      check w.vbar.hover
      r.moveTo(390, 290)
      check not w.vbar.hover
    test name & ": the wheel scrolls":
      let (r, w) = build
      let c = centre(w)
      r.wheel(c.x - 30, c.y, -3)
      check w.scrollY > 0

  proc many(n: int): seq[string] = toSeq(0 ..< n).mapIt("item " & $it)

  scrollScenarios("ListBox"):
    (block:
      let l = newListBox(items = many(100), visibleRows = 8)
      (newRig(stack(l)), l))

  scrollScenarios("TreeView"):
    (block:
      var kids: seq[TreeNode]
      for i in 0 ..< 100: kids.add TreeNode(id: "n" & $i, text: "node " & $i)
      let t = newTreeView(rootNode = TreeNode(id: "root", text: "root", expanded: true, children: kids),
                          visibleRows = 8)
      (newRig(stack(t)), t))

  scrollScenarios("DataTable"):
    (block:
      var rows: seq[DataRow]
      for i in 0 ..< 100:
        var v = initTable[string, JsonNode]()
        v["a"] = %i
        rows.add DataRow(id: $i, values: v)
      let t = newDataTable(columns = @[DataColumn(id: "a", title: "A", width: 120.0)],
                           data = rows, visibleRows = 8, showFilter = false)
      (newRig(stack(t)), t))

  scrollScenarios("DataGrid"):
    (block:
      var rows: seq[GridRow]
      for i in 0 ..< 100: rows.add GridRow(id: $i, values: @[%i])
      let g = newDataGrid(columns = @[GridColumn(id: "a", title: "A", width: 120.0)],
                          data = rows, visibleRows = 8)
      (newRig(stack(g)), g))
