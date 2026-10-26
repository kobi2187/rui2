## The wave reader: a line glides down the page; above it the next page is
## already there, below it the page you are reading. When the line reaches the
## bottom, the page you were reading is gone, the next one is whole, and the
## line starts again at the top.
##
## Built only from ordinary widgets -- no drawing code at all:
## - the two pages are two wrapped Labels, each in a `Clip` that shows its part
##   (the next page above the line, this page below it), stacked;
## - the line is a Rectangle in a `Positioned`, marked `.subpixel()` so it
##   glides by fractions of a pixel instead of hopping;
## - the Stack takes the keys (`.focusable()`, `.onKey`) and moves the line each
##   frame (`.onTick`), at the speed the slider sets;
## - Up/Down step the line a text line (`lineHeight`), Space pauses.
##
## The book is read lazily: a `TextPager` over `newLinesSource` (one paragraph
## a line) lays out only the two pages on screen, from the paragraphs they
## need, read in the background. Each Label holds one page, never the book. A
## page still being read shows when it arrives. The place is a text position,
## so resizing the window re-lays the pages from the same spot.
##
## The timer is the content's own pace, so the user's motion preference does
## not stop it.
##
##   nim c -r -d:useGraphics examples/widgets/wave_reader.nim [theme] [book.txt]
##
## Without a book it writes a long sample one to the temp directory.

import rui
import std/[os, options, strutils]
from raylib import KeyboardKey   # rui keeps its Menu/Up/Down names out of scope

let app = newApp("RUI2 - Wave reader", 720, 560)
app.setTheme(if paramCount() >= 1: paramStr(1) else: "forest")

const sample = [
  "The line moves down the page at the speed you set. Above it, the next page is " &
  "already written; below it, the page you are reading. Read ahead of the line and " &
  "nothing ever turns: the page is replaced while you are still on it, a little at a time.",
  "By the time the line reaches the bottom, the whole of the next page is here, and " &
  "the line begins again at the top. Up and Down move the line by a line of text; " &
  "Space stops it and starts it again; the slider sets how fast it goes.",
  "Only the pages on the screen are laid out, and only the paragraphs they need are " &
  "read from the file, so a book of any length opens at once.",
  "When the book ends it starts over, because a wave has no end."]

proc bookPath(): string =
  if paramCount() >= 2: return paramStr(2)
  result = getTempDir() / "rui_wave_reader_book.txt"
  if not fileExists(result):
    var text = ""
    for chapter in 1 .. 400:              # about 1,600 paragraphs, 4,000 pages' worth
      text.add "Chapter " & $chapter & "\n\n"
      for p in sample: text.add p & "\n\n"
    writeFile(result, text)

const textStyle = TextStyle(fontSize: 22, fontFamily: "Serif")

let book = newTextPager(newLinesSource(bookPath()), textStyle)
var here = TextPos()                   # where the page you are reading starts
var turns = 0
var lineY = 0.0'f32                    # the line, from the top of the pages
var speed = 24.0'f32                   # px a second
var paused = false
var area: Stack
var below, above: Clip
var current, next: Label
var rule: Positioned
var status: Label

proc nextStart(): TextPos =
  ## Where the page after this one starts: the beginning again after the last.
  let cur = book.pageAt(here)
  if cur.isNone: return here
  if book.atEnd(cur.get.next): TextPos() else: cur.get.next

proc showPages() =
  ## The two pages on screen, laid out now; one not read yet stays blank and
  ## fills in when its paragraphs arrive (the source calls this again).
  book.setArea(max(0'f32, area.bounds.width - 2), area.bounds.height)
  let cur = book.pageAt(here)
  let after = book.pageAt(nextStart())
  let a = if cur.isSome: cur.get.text else: ""
  let b = if after.isSome and cur.isSome: after.get.text else: ""
  if current.text != a: current.text = a
  if next.text != b: next.text = b

proc showStatus() =
  status.text = (if paused: "paused" else: $int(speed) & " px/s") &
                "  ·  page " & $(turns + 1) & "  ·  paragraph " & $(here.row + 1)

proc place() =
  ## Put the line at lineY, and cut each page to its side of it.
  let h = area.bounds.height
  above.cut = EdgeInsets(bottom: max(0'f32, h - lineY))   # next page: above the line
  below.cut = EdgeInsets(top: lineY)                      # this page: below it
  rule.top = lineY
  area.layoutDirty = true
  area.markDirtyToRoot()

proc move(by: float32) =
  let h = area.bounds.height
  if h <= 0: return
  lineY += by
  while lineY >= h:                    # reached the bottom: the next page is now this one
    lineY -= h
    here = nextStart()
    turns = if here == TextPos(): 0 else: turns + 1   # the book starts over after its end
    showStatus()
  lineY = max(0'f32, lineY)
  showPages()
  place()


let root = ui:
  Column(spacing = 10.0, crossAxisAlignment = CrossAxisAlignment.stretch,
         padding = EdgeInsets.all(16.0)):
    Row(spacing = 10.0, crossAxisAlignment = CrossAxisAlignment.center):
      Label(text = "Speed")
      Slider(initialValue = 24, minValue = 0, maxValue = 120, showValue = false,
             onChange = proc(v: float32) =
               speed = v
               showStatus()).frame(width = 220).named("speed")
      status = Label(text = "").named("status")
    Expanded():
      area = Stack(fit = StackFit.expand).focusable().named("wave"):
        below = Clip().named("below"):
          current = Label(text = "", fontSize = textStyle.fontSize,
                          fontFamily = textStyle.fontFamily, wrap = true).named("current")
        above = Clip().named("above"):
          next = Label(text = "", fontSize = textStyle.fontSize,
                       fontFamily = textStyle.fontFamily, wrap = true).named("next")
        rule = Positioned(left = 0, right = 0, top = 0, height = 2).subpixel().named("rule"):
          Rectangle(color = Color(r: 47, g: 125, b: 74, a: 255))

area.onKey(proc(key: KeyboardKey): bool =
  case key
  of KeyboardKey.Down: move(lineHeight(textStyle)); true
  of KeyboardKey.Up: move(-lineHeight(textStyle)); true
  of KeyboardKey.Space:
    paused = not paused
    showStatus()
    true
  else: false)
var laidAt: tuple[w, h: float32]
area.onTick(proc(dt: float) =
  let size = (area.bounds.width, area.bounds.height)
  if not paused and speed > 0: move(speed * dt.float32)
  elif size != laidAt: move(0)         # resized while still: lay the pages out again
  laidAt = size)

book.source.attach(area, proc(change: SeqChange) = showPages())  # pages as they arrive
showStatus()
app.setRootWidget(root)
app.focusManager.setFocus(area)
app.start()
