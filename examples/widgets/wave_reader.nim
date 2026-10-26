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
## The timer is the content's own pace, so the user's motion preference does
## not stop it.
##
##   nim c -r -d:useGraphics examples/widgets/wave_reader.nim [theme]

import rui
import std/os
from raylib import KeyboardKey   # rui keeps its Menu/Up/Down names out of scope

let app = newApp("RUI2 - Wave reader", 720, 560)
app.setTheme(if paramCount() >= 1: paramStr(1) else: "forest")

const book = [
  "The line moves down the page at the speed you set. Above it, the next page is " &
  "already written; below it, the page you are reading. Read ahead of the line and " &
  "nothing ever turns: the page is replaced while you are still on it, a little at a time.",
  "This is the second page. You saw its first lines appear above the line while you " &
  "were still reading the first one. By the time the line reaches the bottom, the whole " &
  "of it is here, and the line begins again at the top.",
  "A third page, so you can watch it happen twice. Up and Down move the line by a line " &
  "of text; Space stops it and starts it again; the slider sets how fast it goes.",
  "The last page. After it the book starts over, because a wave has no end."]

const textStyle = TextStyle(fontSize: 22, fontFamily: "Serif")

var page = 0
var lineY = 0.0'f32                    # the line, from the top of the pages
var speed = 24.0'f32                   # px a second
var paused = false
var area: Stack
var below, above: Clip
var current, next: Label
var rule: Positioned
var status: Label

proc showPages() =
  current.text = book[page]
  next.text = book[(page + 1) mod book.len]

proc showStatus() =
  status.text = (if paused: "paused" else: $int(speed) & " px/s") & "  ·  page " & $(page + 1)

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
    page = (page + 1) mod book.len
    showPages()
    showStatus()
  lineY = max(0'f32, lineY)
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
area.onTick(proc(dt: float) =
  if not paused and speed > 0: move(speed * dt.float32))

showPages()
showStatus()
app.setRootWidget(root)
app.focusManager.setFocus(area)
app.start()
