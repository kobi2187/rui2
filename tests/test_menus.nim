## Menus driven the way people drive them: F10 and Alt+letter, the arrows,
## Enter, Escape, and a click elsewhere to close. Whole frames, headless.

import std/[unittest, monotimes]
import rui
from raylib import KeyboardKey

type Fixture = object
  app: App
  source: ListEventSource
  bar: MenuBar
  chosen: seq[string]

proc item(f: ref Fixture, text: string, disabled = false): MenuItem =
  result = newMenuItem(text = text, disabled = disabled)
  let name = text
  result.onClick = proc() = f.chosen.add name

proc fixture(): ref Fixture =
  result = new Fixture
  let f = result
  clearPopups()
  let bar = newMenuBar()
  let file = newMenu(title = "File")
  file.addChild f.item("Open")
  file.addChild newMenuItem(separator = true)
  file.addChild f.item("Print", disabled = true)
  file.addChild f.item("Save")
  let edit = newMenu(title = "Edit")
  edit.addChild f.item("Undo")
  edit.addChild f.item("Redo")
  bar.addChild file
  bar.addChild edit
  let root = newColumn(crossAxisAlignment = CrossAxisAlignment.stretch)
  root.addChild bar
  root.addChild newButton(text = "elsewhere")
  f.app = newApp(title = "menus", width = 500, height = 300)
  f.source = newListEventSource()
  f.app.eventSource = f.source
  f.app.setRootWidget(root)
  f.bar = bar
  f.app.stepHeadless()

proc key(f: ref Fixture, k: KeyboardKey, mods: set[KeyMod] = {}) =
  f.source.push GuiEvent(kind: evKeyDown, key: k, mods: mods, timestamp: getMonoTime())
  f.app.stepHeadless()

proc click(f: ref Fixture, x, y: float32) =
  for kind in [evMouseDown, evMouseUp]:
    f.source.push GuiEvent(kind: kind, mousePos: Point(x: x, y: y), timestamp: getMonoTime())
  f.app.stepHeadless()

proc openMenu(f: ref Fixture): rui.Menu =
  if f.bar.activeMenuIndex < 0: nil
  else: rui.Menu(f.bar.children[f.bar.activeMenuIndex])

suite "the menu bar from the keyboard":

  test "F10 opens the first menu with its first item highlighted":
    let f = fixture()
    f.key(KeyboardKey.F10)
    check f.openMenu != nil and f.openMenu.title == "File"
    check MenuItem(f.openMenu.children[0]).highlighted
    check f.app.focusManager.focusedWidget == f.bar

  test "Down skips the separator and the disabled item; Enter chooses and closes":
    let f = fixture()
    f.key(KeyboardKey.F10)
    f.key(KeyboardKey.Down)
    check MenuItem(f.openMenu.children[3]).highlighted        # Save
    f.key(KeyboardKey.Enter)
    check f.chosen == @["Save"]
    check f.openMenu == nil

  test "Right moves to the next menu; Escape closes it":
    let f = fixture()
    f.key(KeyboardKey.F10)
    f.key(KeyboardKey.Right)
    check f.openMenu.title == "Edit"
    f.key(KeyboardKey.Escape)
    check f.openMenu == nil

  test "Alt+letter opens the menu that starts with it; a letter picks an item":
    let f = fixture()
    f.key(KeyboardKey.E, {kmAlt})
    check f.openMenu.title == "Edit"
    f.key(KeyboardKey.R)
    f.key(KeyboardKey.Enter)
    check f.chosen == @["Redo"]

suite "closing menus by mouse":

  test "choosing an item with the mouse closes its menu":
    let f = fixture()
    f.key(KeyboardKey.F10)
    let open = MenuItem(f.openMenu.children[0])
    f.click(open.bounds.x + 5, open.bounds.y + 5)
    check f.chosen == @["Open"]
    check f.openMenu == nil

  test "a click elsewhere closes an open menu":
    let f = fixture()
    f.key(KeyboardKey.F10)
    f.click(450, 280)                                          # empty space
    check f.openMenu == nil
    check f.chosen.len == 0

suite "context menus":

  test "it takes the keyboard when it opens, and Escape closes it":
    let f = fixture()
    let cm = newContextMenu()
    cm.addChild f.item("Cut")
    cm.addChild f.item("Copy")
    f.app.tree.root.addChild cm
    f.app.stepHeadless()
    cm.openAt(100, 100)
    f.app.stepHeadless()
    check f.app.focusManager.focusedWidget == cm
    f.key(KeyboardKey.Down)
    f.key(KeyboardKey.Down)
    f.key(KeyboardKey.Enter)
    check f.chosen == @["Copy"]
    check not cm.isVisible
    cm.openAt(100, 100)
    f.app.stepHeadless()
    f.key(KeyboardKey.Escape)
    check not cm.isVisible

suite "combo box":
  proc combo(): ComboBox =
    clearPopups()
    result = newComboBox(items = @["Apple", "Banana", "Cherry", "Blueberry"])
    result.bounds = Rect(x: 0, y: 0, width: 160, height: 30)
    result.layout()
    result.focused = true

  proc key(w: Widget, k: KeyboardKey, mods: set[KeyMod] = {}): bool =
    w.handleInput(GuiEvent(kind: evKeyDown, key: k, mods: mods, timestamp: getMonoTime()))

  test "closed, the arrows and Home/End change the choice at once":
    let c = combo()
    var picked: seq[int]
    c.onSelect = proc(i: int) = picked.add i
    discard c.key(KeyboardKey.Down)
    discard c.key(KeyboardKey.End)
    discard c.key(KeyboardKey.Home)
    check picked == @[0, 3, 0]                         # nothing was chosen at first

  test "a letter jumps to the next item starting with it":
    let c = combo()
    discard c.key(KeyboardKey.B)
    check c.selectedIndex == 1
    discard c.key(KeyboardKey.B)
    check c.selectedIndex == 3                         # Blueberry, the next B

  test "open, the arrows move a highlight; Enter picks it, Escape does not":
    let c = combo()
    discard c.key(KeyboardKey.Down, {kmAlt})
    check c.isOpen
    discard c.key(KeyboardKey.Down)
    discard c.key(KeyboardKey.Down)
    check c.hoverIndex == 1 and c.selectedIndex == -1  # highlighted, not chosen
    discard c.key(KeyboardKey.Escape)
    check not c.isOpen and c.selectedIndex == -1
    discard c.key(KeyboardKey.Space)
    discard c.key(KeyboardKey.Down)
    discard c.key(KeyboardKey.Down)
    discard c.key(KeyboardKey.Enter)
    check not c.isOpen and c.selectedIndex == 1

  test "a press outside closes its list":
    let c = combo()
    discard c.key(KeyboardKey.Enter)
    check c.isOpen and anyPopupOpen()
    check dismissPopupsOutside(nil)
    check not c.isOpen

suite "floating dropdowns move nothing":
  test "an open combo box keeps its size, and a click on its list picks":
    clearPopups()
    clearOverlays()
    let combo = newComboBox(items = @["Small", "Medium", "Large"])
    let below = newButton(text = "below")
    let col = newColumn(crossAxisAlignment = CrossAxisAlignment.stretch)
    col.addChild combo
    col.addChild below
    let app = newApp(title = "combo", width = 300, height = 300)
    let source = newListEventSource()
    app.eventSource = source
    app.setRootWidget(col)
    app.stepHeadless()
    let closed = combo.bounds
    let belowY = below.bounds.y
    proc click(x, y: float32) =
      for kind in [evMouseDown, evMouseUp]:
        source.push GuiEvent(kind: kind, mousePos: Point(x: x, y: y), timestamp: getMonoTime())
      app.stepHeadless()
    click(closed.x + 10, closed.y + 5)                 # open
    check combo.isOpen
    check combo.bounds == closed                       # the box did not grow
    check below.bounds.y == belowY                     # and nothing moved
    check combo.list in overlays()
    let l = combo.list.bounds
    check l.y >= closed.y + closed.height - 0.5        # hangs below the box
    click(l.x + 10, l.y + combo.itemHeight * 1.5)      # "Medium", over the button
    check combo.selectedIndex == 1
    check not combo.isOpen and combo.list notin overlays()
