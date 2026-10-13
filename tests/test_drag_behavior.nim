## Anything draggable keeps the drag while the pointer is outside it, and ends it
## on a release outside: the widget takes the pointer when the drag starts.

import std/unittest
import rui
import ui_harness

type Draggable = object
  name: string
  make: proc(): Widget
  dragging: proc(w: Widget): bool
  start: proc(w: Widget): Point     ## where to press

let draggables = @[
  Draggable(name: "Slider",
    make: proc(): Widget = newSlider(minValue = 0, maxValue = 100, showValue = false),
    dragging: proc(w: Widget): bool = Slider(w).dragging,
    start: proc(w: Widget): Point = centre(w)),
  Draggable(name: "RangeSlider",
    make: proc(): Widget = newRangeSlider(minValue = 0, maxValue = 100, initialLow = 10, initialHigh = 90),
    dragging: proc(w: Widget): bool = RangeSlider(w).dragging,
    start: proc(w: Widget): Point = centre(w)),
  Draggable(name: "ScrollBar",
    make: proc(): Widget = newScrollBar(minValue = 0, maxValue = 100, vertical = false),
    dragging: proc(w: Widget): bool = ScrollBar(w).dragging,
    start: proc(w: Widget): Point = centre(w)),
  Draggable(name: "SplitView",
    make: proc(): Widget =
      let s = newSplitView(initialRatio = 0.5)
      s.addChild(newLabel(text = "a")); s.addChild(newLabel(text = "b"))
      s.sizeRequest = Size(width: 300, height: 100)
      s,
    dragging: proc(w: Widget): bool = SplitView(w).dragging,
    start: proc(w: Widget): Point = Point(x: w.bounds.x + w.bounds.width * 0.5, y: w.bounds.y + 50)),
  Draggable(name: "TextInput (selection)",
    make: proc(): Widget = newTextInput(initialText = "abcdefghijklmnop"),
    dragging: proc(w: Widget): bool = TextInput(w).dragging,
    start: proc(w: Widget): Point = Point(x: w.bounds.x + 12, y: w.bounds.y + w.bounds.height / 2)),
  Draggable(name: "Timeline (pan)",
    make: proc(): Widget =
      let t = Timeline(newWidgetByName("Timeline").get); t.sizeRequest = Size(width: 300, height: 120); t,
    dragging: proc(w: Widget): bool = Timeline(w).isDragging,
    start: proc(w: Widget): Point = Point(x: w.bounds.x + 150, y: w.bounds.y + 100)),
  Draggable(name: "MapWidget (pan)",
    make: proc(): Widget =
      let m = newMapWidget(); m.sizeRequest = Size(width: 300, height: 200); m,
    dragging: proc(w: Widget): bool = MapWidget(w).isPanning,
    start: proc(w: Widget): Point = centre(w)),
]

suite "every draggable widget keeps its drag off the widget":
  for d in draggables:
    let drg = d
    test drg.name & ": the drag survives the pointer leaving, and a release outside ends it":
      let w = drg.make()
      let r = newRig(stack(w))
      let p = drg.start(w)
      r.press(p.x, p.y)
      check drg.dragging(w)
      r.moveTo(395, 295)
      r.moveTo(5, 295)
      check drg.dragging(w)                  # still dragging, off the widget
      r.release(5, 295)
      check not drg.dragging(w)
      check pointerCapture() == nil

  test "a Slider dragged far off its track still follows the pointer":
    let s = newSlider(minValue = 0, maxValue = 100, showValue = false)
    let r = newRig(stack(s))
    let p = centre(s)
    r.press(p.x, p.y)
    r.moveTo(s.bounds.x + s.bounds.width + 50, 295)    # past the end and far below
    check s.value >= 99
    r.release(5, 295)
