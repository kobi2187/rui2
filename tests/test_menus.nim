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
