## Kanban board arithmetic: hit-testing, drop targets and moves.

import std/[unittest, options, monotimes]
from raylib import KeyboardKey
import rui

proc board(): seq[KanbanColumn] =
  @[column("Todo", card("a", "A"), card("b", "B"), card("c", "C")),
    column("Doing", card("d", "D")),
    column("Done")]

proc ids(cols: seq[KanbanColumn], i: int): seq[string] =
  for c in cols[i].cards: result.add c.id

let g = KanbanGeometry(origin: (x: 10.0'f32, y: 20.0'f32), height: 300,
                       columnWidth: 100, columnGap: 10, headerHeight: 30,
                       cardHeight: 40, cardGap: 5, pad: 8)

suite "geometry":

  test "columns sit side by side, cards stack under the header":
    check g.columnRect(0) == Rect(x: 10, y: 20, width: 100, height: 300)
    check g.columnRect(2).x == 230.0
    check g.cardRect(0, 0) == Rect(x: 18, y: 58, width: 84, height: 40)   # 20+30+8
    check g.cardRect(0, 2).y == 148.0
    check g.cardRect(0, 0, scrollY = 10).y == 48

  test "which column holds an x, the gap after it included":
    check g.columnAt(3, 12) == some(0)
    check g.columnAt(3, 112) == some(0)       # in the gap: still the left one
    check g.columnAt(3, 121) == some(1)
    check g.columnAt(3, 5).isNone
    check g.columnAt(3, 400).isNone

  test "the card under a point":
    let cols = board()
    check g.cardAt(cols, @[], 30, 70) == some((0, 0))
    check g.cardAt(cols, @[], 30, 108) == some((0, 1))
    check g.cardAt(cols, @[], 30, 101).isNone       # the gap between cards
    check g.cardAt(cols, @[], 30, 40).isNone        # the header
    check g.cardAt(cols, @[], 140, 70) == some((1, 0))
    check g.cardAt(cols, @[], 250, 70).isNone       # an empty column

  test "a scrolled column shifts its cards":
    let cols = board()
    check g.cardAt(cols, @[45.0'f32], 30, 70) == some((0, 1))

  test "scrolling is only possible when the cards overflow":
    check g.maxScroll(1) == 0
    check g.maxScroll(10) > 0
    check g.contentHeight(0) == 16

suite "drop targets":

  test "the slot is the number of cards whose middle is above the pointer":
    let cols = board()
    check g.dropTarget(cols, @[], 30, 50) == some((0, 0))     # above the first
    check g.dropTarget(cols, @[], 30, 100) == some((0, 1))    # past A's middle
    check g.dropTarget(cols, @[], 30, 300) == some((0, 3))    # below all
    check g.dropTarget(cols, @[], 250, 100) == some((2, 0))   # an empty column
    check g.dropTarget(cols, @[], 5, 100).isNone

suite "moves":

  test "to another column":
    let r = applyMove(board(), (0, 1), (1, 1))
    check r.ids(0) == @["a", "c"]
    check r.ids(1) == @["d", "b"]

  test "into an empty column":
    let r = applyMove(board(), (0, 0), (2, 0))
    check r.ids(2) == @["a"] and r.ids(0) == @["b", "c"]

  test "within a column, down and up":
    check applyMove(board(), (0, 0), (0, 3)).ids(0) == @["b", "c", "a"]
    check applyMove(board(), (0, 2), (0, 0)).ids(0) == @["c", "a", "b"]
    check applyMove(board(), (0, 0), (0, 2)).ids(0) == @["b", "a", "c"]

  test "dropping a card where it already is changes nothing":
    check applyMove(board(), (0, 1), (0, 1)) == board()
    check applyMove(board(), (0, 1), (0, 2)) == board()     # just below itself

  test "nonsense is ignored, not a crash":
    check applyMove(board(), (9, 0), (0, 0)) == board()
    check applyMove(board(), (0, 9), (0, 0)) == board()
    check applyMove(board(), (0, 0), (9, 0)) == board()
    check applyMove(board(), (0, 0), (1, 99)).ids(1) == @["d", "a"]   # clamped

  test "no card is ever lost or duplicated":
    let before = board()
    for fc in 0 .. 2:
      for fi in 0 ..< before[fc].cards.len:
        for tc in 0 .. 2:
          for ti in 0 .. 4:
            let r = applyMove(before, (fc, fi), (tc, ti))
            var all: seq[string]
            for col in 0 .. 2:
              all.add r.ids(col)
            check all.len == 4
            for want in ["a", "b", "c", "d"]:
              check want in all

suite "the widget: dragging cards":

  proc setup(): KanbanBoard =
    setCurrentTheme(brandTheme(daylightSpec()))
    result = newKanbanBoard(columns = board())
    result.bounds = Rect(x: 0, y: 0, width: 700, height: 400)
    result.layout()

  proc press(b: KanbanBoard, kind: EventKind, x, y: float32): bool =
    b.handleInput(GuiEvent(kind: kind, mousePos: Point(x: x, y: y)))

  test "dragging a card to another column moves it and reports it":
    let b = setup()
    var got: (string, int, int, int)
    b.onMove = proc(id: string, fc, tc, ti: int) = got = (id, fc, tc, ti)
    let from0 = cardRect(geometryOf(b), 0, 1)            # card "b"
    let to0 = cardRect(geometryOf(b), 1, 0)
    discard b.press(evMouseDown, from0.x + 5, from0.y + 5)
    discard b.press(evMouseMove, to0.x + 5, to0.y + 40)   # past D's middle: slot 1
    check b.dragging
    discard b.press(evMouseUp, to0.x + 5, to0.y + 40)
    check not b.dragging
    check got == ("b", 0, 1, 1)
    check b.columns[0].cards.len == 2 and b.columns[1].cards.len == 2
    check b.columns[1].cards[1].id == "b"

  test "a press that does not move is a click, not a drag":
    let b = setup()
    var clicked = ""
    var moved = false
    b.onCardClick = proc(id: string) = clicked = id
    b.onMove = proc(id: string, fc, tc, ti: int) = moved = true
    let r = cardRect(geometryOf(b), 0, 0)
    discard b.press(evMouseDown, r.x + 5, r.y + 5)
    discard b.press(evMouseMove, r.x + 6, r.y + 6)        # under the threshold
    check not b.dragging
    discard b.press(evMouseUp, r.x + 6, r.y + 6)
    check clicked == "a" and not moved

  test "a drop back where it started changes nothing":
    let b = setup()
    var moved = false
    b.onMove = proc(id: string, fc, tc, ti: int) = moved = true
    let r = cardRect(geometryOf(b), 0, 1)
    discard b.press(evMouseDown, r.x + 5, r.y + 5)
    discard b.press(evMouseMove, r.x + 5, r.y + 25)
    discard b.press(evMouseUp, r.x + 5, r.y + 25)
    check not moved
    check b.columns == board()

  test "a press on empty space is not ours":
    let b = setup()
    check not b.press(evMouseDown, 650, 380)

suite "kanban from the keyboard":
  proc keyBoard(): KanbanBoard =
    result = newKanbanBoard(columns = @[
      column("Todo", card("a", "A"), card("b", "B"), card("c", "C")),
      column("Doing", card("d", "D")),
      column("Done")])
    result.bounds = Rect(x: 0, y: 0, width: 700, height: 400)
    result.layout()
    result.focused = true

  proc key(w: Widget, k: KeyboardKey): bool =
    w.handleInput(GuiEvent(kind: evKeyDown, key: k, timestamp: getMonoTime()))

  proc ids(b: KanbanBoard, c: int): seq[string] =
    for card in b.columns[c].cards: result.add card.id

  test "arrows move between cards and columns; Enter opens a card":
    let b = keyBoard()
    var opened: seq[string]
    b.onCardClick = proc(id: string) = opened.add id
    discard b.key(KeyboardKey.Down)
    discard b.key(KeyboardKey.Down)
    check b.focus == (0, 2)
    discard b.key(KeyboardKey.Right)
    check b.focus == (1, 0)                              # Doing has one card
    discard b.key(KeyboardKey.Enter)
    check opened == @["d"]

  test "Space picks a card up, the arrows carry it, Space drops it":
    let b = keyBoard()
    var moves: seq[(string, int, int, int)]
    b.onMove = proc(id: string, f, t, i: int) = moves.add (id, f, t, i)
    discard b.key(KeyboardKey.Space)                     # pick up A
    discard b.key(KeyboardKey.Down)                      # below B
    check b.ids(0) == @["b", "a", "c"]
    discard b.key(KeyboardKey.Right)                     # into Doing, same row
    check b.ids(1) == @["d", "a"]
    discard b.key(KeyboardKey.Space)
    check not b.carrying
    check moves == @[("a", 0, 1, 1)]

  test "Escape puts a carried card back":
    let b = keyBoard()
    discard b.key(KeyboardKey.Space)
    discard b.key(KeyboardKey.Right)
    discard b.key(KeyboardKey.Right)
    check b.ids(2) == @["a"]
    discard b.key(KeyboardKey.Escape)
    check b.ids(0) == @["a", "b", "c"] and b.ids(2).len == 0
    check b.focus == (0, 0)
