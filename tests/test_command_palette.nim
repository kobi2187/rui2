## CommandPalette (menus/command_palette.nim), through the real event router:
## opens with the keyboard in its field, typing filters fuzzily, Up/Down
## choose, Enter runs and closes, a click on a row runs it, Escape and a click
## elsewhere close it.

import std/[unittest, options]
import rui
import ui_harness
from raylib import KeyboardKey

proc rig(): tuple[r: Rig, p: CommandPalette, ran: ref seq[string], other: Button] =
  let ran = new(seq[string])
  var p: CommandPalette
  var other: Button
  let root = ui:
    Column(padding = EdgeInsets.all(10.0)):
      other = Button(text = "elsewhere")
      p = CommandPalette(commands = @[
        command("Open File", "Ctrl+O", proc() = ran[].add "open"),
        command("Save", "Ctrl+S", proc() = ran[].add "save"),
        command("Save As...", "Ctrl+Shift+S", proc() = ran[].add "saveAs"),
        command("Toggle Word Wrap", "", proc() = ran[].add "wrap")])
  let r = newRig(root, 600, 400)
  (r, p, ran, other)

suite "CommandPalette":
  teardown: clearRepaints()

  test "closed it takes no room; open, every command is there and the field has the keys":
    let (r, p, _, _) = rig()
    check p.bounds.width == 0
    p.open()
    r.frame(2)
    check p.isOpen and p.shown.len == 4
    check p.field.focused
    check Widget(p) in overlays()
    disposeTree(r.root)

  test "typing filters fuzzily, best first; Enter runs the chosen one and closes":
    let (r, p, ran, _) = rig()
    p.open()
    r.frame(2)
    r.typeText("sav")
    check p.shown.len == 2 and p.commands[p.shown[0].index].name == "Save"
    r.key(KeyboardKey.Down)
    check p.chosen == 1
    r.key(KeyboardKey.Enter)
    check ran[] == @["saveAs"] and not p.isOpen
    disposeTree(r.root)

  test "a click on a row runs it; Escape and a click elsewhere close it":
    let (r, p, ran, other) = rig()
    p.open()
    r.frame(2)
    r.typeText("wrap")
    let row = p.rowRect(0)
    r.click(row.x + 20, row.y + row.height / 2)
    check ran[] == @["wrap"] and not p.isOpen
    p.open()
    r.frame(2)
    r.key(KeyboardKey.Escape)
    check not p.isOpen
    p.open()
    r.frame(2)
    r.click(other)
    check not p.isOpen
    disposeTree(r.root)
