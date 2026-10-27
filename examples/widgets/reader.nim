## A book reader whose controls stay out of the way: HoverReveal.
##
## The page is all you see. Along the bottom, and in the top-right corner,
## only a faint outline marks where the controls are; bring the pointer near
## and they are there at once (page turning and position at the bottom, text
## size in the corner), gone again a second after it leaves. Hidden, they
## cannot be clicked -- on a touch screen the first tap only reveals them.
##
##   nim c -r -d:useGraphics examples/widgets/reader.nim [theme]

import rui
import std/os

let app = newApp("RUI2 - Reader", 720, 520)
app.setTheme(if paramCount() >= 1: paramStr(1) else: "forest")

const chapter = [
  "It was a bright cold day in April, and the reader had not yet looked up from the page. " &
  "The controls were there, of course -- they always are -- but they kept to the edges and " &
  "said nothing until they were wanted.",
  "A good page asks for nothing. It does not blink, it does not slide, it does not remind " &
  "you of the buttons you might press. It waits, and when you reach for the corner it " &
  "answers at once, and when you go back to reading it lets you be.",
  "That is the whole trick: the outline tells you where to reach, the reach brings the " &
  "controls, and the page is yours again a moment after you let go.",
  "The last page. Turn back with the bar below, or drag along it to any place in the book."]

var page = 0
var size = 20.0'f32
var text, where: Label
var position: Slider

proc show() =
  text.text = chapter[page]
  where.text = "page " & $(page + 1) & " of " & $chapter.len
  position.value = page.float32

proc turn(by: int) =
  page = clamp(page + by, 0, chapter.high)
  show()

proc resize(by: float32) =
  size = clamp(size + by, 14, 32)
  text.fontSize = size

let root = ui:
  Stack(fit = StackFit.expand):
    Padding(padding = EdgeInsets(left: 70, top: 60, right: 70, bottom: 90)):
      text = Label(text = "", fontSize = 20.0, fontFamily = "Serif", wrap = true).named("page")
    Positioned(left = 90, right = 90, bottom = 18, height = 56):
      HoverReveal(hideDelay = 1.0).named("pageBar"):
        Row(spacing = 10.0, crossAxisAlignment = CrossAxisAlignment.center):
          Button(text = "Prev", onClick = proc() = turn(-1)).named("prev")
          Expanded():
            position = Slider(minValue = 0, maxValue = float32(chapter.high), step = 1,
                              showValue = false,
                              onChange = proc(v: float32) =
                                if int(v) != page: turn(int(v) - page)).named("position")
          where = Label(text = "").named("where")
          Button(text = "Next", onClick = proc() = turn(1)).named("next")
    Positioned(right = 18, top = 14, width = 120, height = 52):
      HoverReveal(hideDelay = 1.0).named("textBar"):
        Row(spacing = 8.0):
          Button(text = "A-", onClick = proc() = resize(-2)).named("smaller")
          Button(text = "A+", onClick = proc() = resize(2)).named("larger")

show()
app.setRootWidget(root)
app.start()
