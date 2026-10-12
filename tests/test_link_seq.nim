## LinkSeq: edits are reported as edits, and positions can be carried across them.

import std/[unittest, sets]
import rui

proc record(s: LinkSeq[string]): ref seq[SeqChange] =
  result = new(seq[SeqChange])
  let log = result
  discard s.listen(proc(c: SeqChange) = log[].add c)

suite "LinkSeq edits":

  test "each edit is reported with its position":
    let s = newLinkSeq(@["a", "b", "c"])
    let log = record(s)
    s.add "d"
    s.insert(1, "x")
    s.delete(0)
    s.move(0, 2)
    s[1] = "y"
    s.reset(@["z"])
    check s.toSeq == @["z"]
    check log[].len == 6
    check log[][0] == SeqChange(kind: scInsert, index: 3, count: 1)
    check log[][1] == SeqChange(kind: scInsert, index: 1, count: 1)
    check log[][2] == SeqChange(kind: scRemove, index: 0, count: 1)
    check log[][3] == SeqChange(kind: scMove, index: 0, to: 2, count: 1)
    check log[][4].kind == scReplace
    check log[][5].kind == scReset

  test "the contents follow the edits":
    let s = newLinkSeq(@["a", "b", "c", "d"])
    s.move(0, 3)
    check s.toSeq == @["b", "c", "d", "a"]
    s.deleteRange(1, 2)
    check s.toSeq == @["b", "a"]
    s.insertAll(1, ["x", "y"])
    check s.toSeq == @["b", "x", "y", "a"]
    check s.len == 4 and s[2] == "y" and "x" in s and s.find("a") == 3

  test "setting an equal value is not a change":
    let s = newLinkSeq(@["a"])
    let log = record(s)
    s[0] = "a"
    check log[].len == 0

  test "unlisten stops the calls":
    let s = newLinkSeq(@["a"])
    var n = 0
    let id = s.listen(proc(c: SeqChange) = inc n)
    s.add "b"
    s.unlisten id
    s.add "c"
    check n == 1 and s.listenerCount == 0

suite "carrying positions across an edit":

  test "insert shifts what is at or after it":
    let c = SeqChange(kind: scInsert, index: 2, count: 3)
    check c.remap(1) == 1 and c.remap(2) == 5 and c.remap(9) == 12

  test "remove drops its range and closes the gap":
    let c = SeqChange(kind: scRemove, index: 2, count: 2)
    check c.remap(1) == 1 and c.remap(2) == -1 and c.remap(3) == -1 and c.remap(4) == 2

  test "move: the item travels, the ones it passes shift":
    let down = SeqChange(kind: scMove, index: 1, to: 3, count: 1)
    check down.remap(1) == 3 and down.remap(2) == 1 and down.remap(3) == 2 and
          down.remap(0) == 0 and down.remap(4) == 4
    let up = SeqChange(kind: scMove, index: 3, to: 1, count: 1)
    check up.remap(3) == 1 and up.remap(1) == 2 and up.remap(2) == 3 and up.remap(0) == 0

  test "replace keeps positions; reset voids them":
    check SeqChange(kind: scReplace, index: 1).remap(1) == 1
    check SeqChange(kind: scReset).remap(0) == -1

  test "remap agrees with doing the edit on a list of tags (every kind, every index)":
    # Tag each item with its old index, apply the edit, and see where each tag is.
    for kind in [scInsert, scRemove, scMove]:
      for index in 0 ..< 5:
        for other in 0 ..< 5:
          let s = newLinkSeq(@[0, 1, 2, 3, 4])
          var change: SeqChange
          discard s.listen(proc(c: SeqChange) = change = c)
          case kind
          of scInsert: s.insert(index, 99)
          of scRemove: s.delete(index)
          else: s.move(index, other)
          for old in 0 ..< 5:
            let found = s.find(old)
            check change.remap(old) == found       # -1 when removed: find says -1 too

  test "a selection is remapped as a set":
    let c = SeqChange(kind: scRemove, index: 1, count: 1)
    check c.remap(toHashSet([0, 1, 2, 3])) == toHashSet([0, 1, 2])

suite "following a LinkSeq":

  test "apply makes a copy follow the source edit by edit":
    let s = newLinkSeq(@["a", "b", "c"])
    var copy = s.toSeq
    discard s.listen(proc(c: SeqChange) = c.apply(copy, s))
    s.add "d"; s.insert(0, "z"); s.move(0, 3); s.delete(1); s[0] = "q"
    check copy == s.toSeq
    s.reset(@["only"])
    check copy == @["only"]

  test "a widget attached to it is released when disposed":
    let s = newLinkSeq(@["a"])
    let w = newLabel()
    s.attach(w, proc(c: SeqChange) = discard)
    check s.dependentCount == 1 and s.listenerCount == 1
    disposeTree(w)
    check s.dependentCount == 0 and s.listenerCount == 0
