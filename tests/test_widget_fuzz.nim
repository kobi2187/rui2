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
