## ChipInput (input/chip_input.nim), through the real event router: Enter and
## a comma make chips, a suggestion makes one, duplicates are one chip,
## Backspace in the empty field and a chip's x remove, the field takes the room
## left after the chips.

import std/[unittest, strutils]
import rui
import ui_harness
from raylib import KeyboardKey

proc rig(chips: seq[string] = @[]): tuple[r: Rig, c: ChipInput, seen: ref seq[seq[string]]] =
  let seen = new(seq[seq[string]])
  let c = newChipInput(initialChips = chips, suggestions = @["raylib", "pango", "nim"],
                       onChange = proc(cs: seq[string]) = seen[].add cs)
  let r = newRig(stack(c.frame(width = 360)), 400, 200)
  r.focus(c.field.input)
  (r, c, seen)

suite "ChipInput":
  teardown: clearRepaints()

  test "Enter makes a chip of what was typed, and empties the field":
    let (r, c, seen) = rig()
    r.typeText("hello")
    r.key(KeyboardKey.Enter)
    check c.chips == @["hello"] and c.field.input.text == ""
    check seen[] == @[@["hello"]]
    disposeTree(r.root)

  test "a comma ends a chip as Enter does; parts are trimmed, the same twice is one":
    let (r, c, _) = rig(@["Nim"])
    r.typeText("a, b ,nim,")
    check c.chips == @["Nim", "a", "b"]
    check c.field.input.text == ""
    disposeTree(r.root)

  test "a suggestion taken from the list makes a chip":
    let (r, c, _) = rig()
    r.typeText("pan")
    check c.field.isOpen
    r.key(KeyboardKey.Down)
    r.key(KeyboardKey.Enter)
    check c.chips == @["pango"]
    disposeTree(r.root)

  test "Backspace in the empty field removes the last chip; in a word it edits the word":
    let (r, c, _) = rig(@["one", "two"])
    r.typeText("x")
    r.key(KeyboardKey.Backspace)
    check c.chips == @["one", "two"] and c.field.input.text == ""
    r.key(KeyboardKey.Backspace)
    check c.chips == @["one"]
    disposeTree(r.root)

  test "a chip's x removes it; chips flow into rows and the widget grows":
    let (r, c, _) = rig(@["alpha", "beta"])
    let lay1 = c.bounds.height
    var many: seq[string]
    for i in 0 ..< 12: many.add "tag" & $i
    r.typeText(many.join(","))
    r.key(KeyboardKey.Enter)
    r.frame(2)
    check c.chips.len == 14
    check c.bounds.height > lay1                  # more rows
    check c.field.bounds.x >= c.bounds.x and
          c.field.bounds.x + c.field.bounds.width <= c.bounds.x + c.bounds.width + 0.5
    let x = c.chipLayout.chips[0].closeRect
    r.click(x.x + x.width / 2, x.y + x.height / 2)
    check c.chips.len == 13 and c.chips[0] == "beta"
    disposeTree(r.root)
