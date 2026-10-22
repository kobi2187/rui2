## `motion: none` means nothing moves: once a widget has had a click, keys, the
## wheel and a drag, and a few frames to land, nothing in it may still be
## asking for frames. A widget that animates behind the user's back -- a fade,
## a slide, a coast, a blink -- fails here by name.

import std/[unittest, strutils, monotimes, times, options]
import rui
import ui_harness
from raylib import KeyboardKey, Space, Enter, Escape, Down, Up, Tab

const skip = ["dialog", "messagebox", "filedialog", "helpoverlay", "toast",
              "focusring", "tooltiptip", "comboList", "calendarpopup", "colorpopup",
              "tablerow", "docked", "positioned", "expanded", "flexible"]

proc skipped(name: string): bool =
  for s in skip:
    if name.toLowerAscii.replace("_", "") == s.toLowerAscii: return true

proc stillAsking(): seq[string] =
  ## Repaints wanted within the next couple of frames: something moving.
  let now = getMonoTime()
  for (w, at) in pendingRepaints():
    if at - now < initDuration(milliseconds = 40):
      result.add w.getTypeName & " in " & $((at - now).inMilliseconds) & " ms"

const motionLevel {.strdefine.} = "none"
  ## -d:motionLevel=full runs the same check with motion on: it should fail,
  ## which shows the check can see motion at all.
let level = if motionLevel == "full": motionFull else: motionNone

suite "motion: none -- nothing keeps moving":
  setup:
    clearRepaints()
  teardown:
    motion = motionFull

  for name in registeredWidgets():
    if skipped(name): continue
    let typeName = name
    test typeName & ": after a click, keys and a drag it asks for no more frames":
      let w = newWidgetByName(typeName).get
      w.sizeRequest = Size(width: 160, height: 60)
      let r = newRig(stack(w))
      motion = level                 # after the App, which applies the user's own
      clearOverlays()
      let c = centre(w)
      r.moveTo(c)
      r.click(c.x, c.y)
      for k in [Tab, Down, Up, Space, Enter, Escape]:
        r.key(k)
      r.wheel(c.x, c.y, -2)
      r.drag(c.x - 30, c.y, c.x + 30, c.y)
      # Straight after: under `none` nothing is on its way anywhere. Timers
      # already due (a press shown for a moment) fire first; a delay further
      # off (a tooltip's half second) is not motion and is not counted.
      discard fireDueRepaints()
      r.frame(1)
      let asking = stillAsking()
      if asking.len > 0: echo "    still asking: ", asking
      check asking.len == 0

suite "motion: none -- what slides lands in one frame":
  setup:
    clearRepaints()
  teardown:
    motion = motionFull

  test "a Drawer, a SidePane and an Accordion section, opened and closed":
    let drawer = newDrawer(width = 120, initialOpen = false)
    drawer.addChild(newLabel(text = "menu"))
    let pane = newSidePane(title = "Chosen", width = 150)
    pane.addChild(newLabel(text = "files"))
    let acc = newAccordion()
    for t in ["One", "Two"]:
      let e = newExpander(title = t)
      e.addChild(newLabel(text = t))
      acc.addChild(e)
    let r = newRig(stack(drawer, pane, acc))
    motion = motionNone
    drawer.setOpen(true)
    pane.setExpanded(false)
    acc.open(1)
    r.frame(1)
    check drawer.bounds.width == 120
    check pane.bounds.width == pane.stripWidth
    check stillAsking().len == 0
