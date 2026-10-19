## Every registered widget, put through the same user gestures: nothing may
## crash, leave a hover or a pointer capture behind, or leave an overlay open
## after a click elsewhere. Cheap breadth: the invariants a new widget most
## often breaks first, found by name when it does.

import std/[unittest, strutils, sets]
import rui
import ui_harness
from raylib import KeyboardKey, Space, Enter, Escape, Left, Right, Up, Down, Home, End, Tab, PageDown, PageUp

const skip = ["dialog", "messagebox", "filedialog", "helpoverlay", "toast",
              "focusring", "tooltiptip", "comboList", "calendarpopup", "colorpopup",
              "tablerow", "docked", "positioned", "expanded", "flexible"]

proc skipped(name: string): bool =
  for s in skip:
    if name.toLowerAscii.replace("_", "") == s.toLowerAscii: return true

suite "every widget under the same gestures":
  for name in registeredWidgets():
    if skipped(name): continue
    let typeName = name

    test typeName & ": click, keys, wheel and drag leave no hover, capture or overlay behind":
      let w = newWidgetByName(typeName).get
      w.sizeRequest = Size(width: 160, height: 60)
      let r = newRig(stack(w))
      clearOverlays()
      let c = centre(w)
      r.moveTo(c)
      r.click(c.x, c.y)
      for k in [Tab, Down, Up, Right, Left, Home, End, PageDown, PageUp, Space, Enter, Escape]:
        r.key(k)
      r.wheel(c.x, c.y, -2)
      r.wheel(c.x, c.y, 2)
      r.drag(c.x - 20, c.y, c.x + 20, c.y)
      r.click(395, 295)                      # empty space: closes anything open
      r.moveTo(395, 295)
      check not w.hovered
      check pointerCapture() == nil
      check overlays().len == 0

suite "every widget under several fingers":
  for mode in [imDesktop, imTouch]:
    for name in registeredWidgets():
      if skipped(name): continue
      let typeName = name
      let m = mode

      test $m & " " & typeName & ": a pinch, a two-finger drag and a flick leave no pointer held":
        setInputMode(m)
        defer:
          unpinInputMode()
          releaseAllPointers()
        let w = newWidgetByName(typeName).get
        w.sizeRequest = Size(width: 160, height: 60)
        let r = newRig(stack(w))
        clearOverlays()
        let c = centre(w)
        # a pinch
        r.press(c.x - 10, c.y)
        r.pointerDown(1, c.x + 10, c.y)
        for i in 1 .. 4:
          r.pointerMove(0, c.x - 10 - i.float32 * 8, c.y)
          r.pointerMove(1, c.x + 10 + i.float32 * 8, c.y)
        r.pointerUp(1, c.x + 40, c.y)
        r.release(c.x - 40, c.y)
        # two fingers dragging together, lifted in the other order
        r.press(c.x, c.y)
        r.pointerDown(1, c.x + 20, c.y)
        r.pointerMove(0, c.x, c.y - 20); r.pointerMove(1, c.x + 20, c.y - 20)
        r.release(c.x, c.y - 20)
        r.pointerUp(1, c.x + 20, c.y - 20)
        # a flick, and a stray second finger with no first
        r.drag(c.x, c.y + 20, c.x, c.y - 20, steps = 3)
        r.pointerDown(2, c.x, c.y); r.pointerMove(2, c.x + 5, c.y); r.pointerUp(2, c.x + 5, c.y)
        r.click(395, 295)
        r.moveTo(395, 295)
        check not w.hovered
        check pointerCapture(0) == nil
        check pointerCapture(1) == nil
        check pointerCapture(2) == nil
        check overlays().len == 0
