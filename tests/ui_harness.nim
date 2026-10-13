## Drive a widget tree like a user: every helper pushes real events through the
## app's router (`stepHeadless`), so a regression anywhere between event source
## and widget state shows up here, named by the scenario that broke.

import std/[monotimes, os, unittest]
import rui
from raylib import KeyboardKey

type Rig* = object
  app*: App
  src*: ListEventSource
  root*: Widget

proc newRig*(root: Widget, w = 400, h = 300): Rig =
  let app = newApp(title = "rig", width = w.int32, height = h.int32)
  let src = newListEventSource()
  app.eventSource = src
  root.bounds = Rect(x: 0, y: 0, width: w.float32, height: h.float32)
  app.setRootWidget(root)
  app.stepHeadless()
  releasePointer()
  Rig(app: app, src: src, root: root)

proc ev(kind: EventKind, x, y: float32): GuiEvent =
  GuiEvent(kind: kind, priority: epHigh, timestamp: getMonoTime(),
           mousePos: Point(x: x, y: y))

proc frame*(r: Rig, n = 2) =
  for _ in 0 ..< n: r.app.stepHeadless()

proc centre*(w: Widget): Point =
  Point(x: w.bounds.x + w.bounds.width / 2, y: w.bounds.y + w.bounds.height / 2)

proc moveTo*(r: Rig, x, y: float32) =
  r.src.push ev(evMouseMove, x, y); r.frame()

proc moveTo*(r: Rig, p: Point) = r.moveTo(p.x, p.y)
proc moveTo*(r: Rig, w: Widget) = r.moveTo(centre(w))

proc press*(r: Rig, x, y: float32) =
  r.src.push ev(evMouseMove, x, y); r.src.push ev(evMouseDown, x, y); r.frame()

proc release*(r: Rig, x, y: float32) =
  r.src.push ev(evMouseMove, x, y); r.src.push ev(evMouseUp, x, y); r.frame()

proc click*(r: Rig, x, y: float32) =
  r.press(x, y); r.release(x, y)

proc click*(r: Rig, w: Widget) =
  let c = centre(w); r.click(c.x, c.y)

proc clickAt*(r: Rig, w: Widget, dx, dy: float32) =
  ## Click at an offset from the widget's top-left.
  r.click(w.bounds.x + dx, w.bounds.y + dy)

proc drag*(r: Rig, x0, y0, x1, y1: float32, steps = 4) =
  r.press(x0, y0)
  for i in 1 .. steps:
    let t = i.float32 / steps.float32
    r.src.push ev(evMouseMove, x0 + (x1 - x0) * t, y0 + (y1 - y0) * t)
    r.frame(1)
  r.release(x1, y1)

proc wheel*(r: Rig, x, y, delta: float32) =
  sleep(55)                       # the event manager throttles wheel events to one per 50 ms
  var e = ev(evMouseWheel, x, y); e.wheelDelta = delta
  r.src.push ev(evMouseMove, x, y); r.src.push e; r.frame()

proc key*(r: Rig, k: KeyboardKey) =
  r.src.push GuiEvent(kind: evKeyDown, priority: epHigh, timestamp: getMonoTime(), key: k)
  r.frame()

proc typeText*(r: Rig, s: string) =
  for ch in s:
    r.src.push GuiEvent(kind: evChar, priority: epHigh, timestamp: getMonoTime(), char: ch)
  r.frame()

proc focus*(r: Rig, w: Widget) =
  r.app.focusManager.setFocus(w); r.frame(1)

proc stack*(ws: varargs[Widget]): Widget =
  let v = newVStack(padding = 4.0, spacing = 6.0)
  for w in ws: v.addChild w
  v
