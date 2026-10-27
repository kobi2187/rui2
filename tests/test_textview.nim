## TextView (data/textview.nim): a long text scrolled by lines, read only as far
## as it is shown. Driven through the real event router: wheel, keys and the
## scroll bar, a source that counts what was read, and the place kept as a
## text position.

import std/[unittest, options, strutils, os]
import rui
import ui_harness
from raylib import KeyboardKey

type CountingSource = ref object of RowSource
  inner: MemorySource
  asked: int                      ## the highest row whose text was read

method count(s: CountingSource): int = s.inner.count
method cell(s: CountingSource, row, col: int): string =
  s.asked = max(s.asked, row)
  s.inner.cell(row, col)

proc book(n: int): CountingSource =
  var rows: seq[seq[string]]
  for i in 0 ..< n:
    rows.add @["Paragraph " & $i & ": " & "word ".repeat(4 + i mod 20).strip]
  CountingSource(inner: newMemorySource(@["text"], rows), asked: -1)

var rigs: seq[Rig]

proc reader(src: RowSource): (TextView, Rig) =
  let v = newTextView(source = src).frame(width = 360, height = 240)
  let r = newRig(stack(v), 400, 300)
  rigs.add r
  r.frame(2)
  (TextView(v), r)

proc shownText(v: TextView): string = Label(v.children[0]).text

suite "TextView":
  teardown:
    for r in rigs: disposeTree(r.root)
    rigs.setLen(0)

  test "only what is shown is read; the label holds only the visible lines":
    let src = book(100_000)
    let (v, _) = reader(src)
    check v.shownText.startsWith("Paragraph 0")
    check src.asked < 100                  # of 100,000 paragraphs
    check v.shownText.split('\n').len <= 240 div 16

  test "the wheel and the arrow keys scroll by lines; Home goes back to the start":
    let (v, r) = reader(book(500))
    var reported: seq[TextPos]
    v.onScroll = proc(p: TextPos) = reported.add p
    r.wheel(200, 150, -1)                  # a notch down: three lines
    r.frame(1)
    let afterWheel = v.top
    check afterWheel != TextPos()
    check reported.len == 1
    r.focus(v)
    r.key(KeyboardKey.Down)
    r.frame(1)
    check v.top != afterWheel
    r.key(KeyboardKey.Up)
    r.frame(1)
    check v.top == afterWheel
    r.key(KeyboardKey.Home)
    r.frame(1)
    check v.top == TextPos() and v.shownText.startsWith("Paragraph 0")

  test "it stops with the last line at the bottom":
    let (v, r) = reader(book(30))
    r.focus(v)
    r.key(KeyboardKey.End)
    r.frame(1)
    let atEnd = v.top
    check v.shownText.replace("\n", " ").endsWith("Paragraph 29: " & "word ".repeat(4 + 29 mod 20).strip)
    r.key(KeyboardKey.PageDown)
    r.frame(1)
    check v.top == atEnd                   # no further
    check v.shownText.split('\n').len >= 240 div 30   # a full screen, not one line

  test "dragging the scroll bar jumps to a paragraph without reading the ones before":
    let src = book(100_000)
    let (v, r) = reader(src)
    let bar = Rect(x: v.bounds.x + v.bounds.width - 6, y: v.bounds.y + 2,
                   width: 2, height: 2)
    r.drag(bar.x, v.bounds.y + 20, bar.x, v.bounds.y + v.bounds.height / 2)
    r.frame(1)
    check v.top.row > 30_000
    check v.shownText.startsWith("Paragraph " & $v.top.row)
    check src.asked < v.top.row + 200

  test "a saved place reopens there; a new width keeps the paragraph":
    let (v, r) = reader(book(2000))
    v.scrollTo(TextPos(row: 1234, line: 0))
    r.frame(1)
    check v.shownText.startsWith("Paragraph 1234")
    v.bounds.width = 0
    discard v.frame(width = 250, height = 240)
    v.layoutDirty = true
    r.frame(2)
    check v.top.row == 1234 and v.shownText.startsWith("Paragraph 1234")

  test "lines from a file read in the background fill in when they arrive":
    let path = getTempDir() / "rui_textview.txt"
    var text = ""
    for i in 0 ..< 20_000: text.add "Line " & $i & " of a long file\n"
    writeFile(path, text)
    let src = newLinesSource(path)
    defer:
      src.close()
      removeFile(path)
    let (v, r) = reader(src)
    for _ in 0 ..< 200:
      if v.shownText.startsWith("Line 0"): break
      r.frame(1)
      sleep(5)
    check v.shownText.startsWith("Line 0")
