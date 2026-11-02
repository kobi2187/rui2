## Phone-style widgets (rui_widgets/mobile), through the real event router:
## the AppBar's leading button and actions, BottomNav picking (click and the
## pick-one keys), the FAB pressing as a button, and the BottomSheet opening,
## dragging between snaps, settling, and closing by scrim, drag and Escape.

import std/[unittest, options]
import rui
import ui_harness
from raylib import KeyboardKey

suite "AppBar":
  teardown: clearRepaints()
  test "the leading button calls onLeading; actions sit at the right end":
    var opened = 0
    var act: Button
    var bar: AppBar
    let root = ui:
      Column(crossAxisAlignment = CrossAxisAlignment.stretch):
        bar = AppBar(title = "Inbox", leading = "☰", onLeading = proc() = inc opened):
          act = Button(text = "Edit")
    let r = newRig(root, 400, 300)
    r.click(bar.bounds.x + 20, bar.bounds.y + bar.bounds.height / 2)
    check opened == 1
    check act.bounds.x + act.bounds.width <= bar.bounds.x + bar.bounds.width
    check act.bounds.x > bar.bounds.x + bar.bounds.width / 2
    r.click(bar.bounds.x + 200, bar.bounds.y + 10)    # the title: nothing
    check opened == 1
    disposeTree(r.root)

suite "BottomNav":
  teardown: clearRepaints()
  test "a press picks; Left/Right/Home/End move along; badges do not get in the way":
    var picked: seq[int]
    let nav = newBottomNav(items = @[navItem("⌂", "Home"), navItem("✉", "Mail", badge = 3),
                                     navItem("⚙", "Settings")],
                           onSelect = proc(i: int) = picked.add i)
    let r = newRig(stack(nav.frame(width = 300, height = 64)), 300, 100)
    let s = slotRect(nav.bounds, 3, 1)
    r.click(s.x + s.width / 2, s.y + s.height / 2)
    check nav.selected == 1
    r.focus(nav)
    r.key(KeyboardKey.Right)
    check nav.selected == 2
    r.key(KeyboardKey.Home)
    check nav.selected == 0 and picked == @[1, 2, 0]
    disposeTree(r.root)

suite "FloatingActionButton":
  teardown: clearRepaints()
  test "it presses as a button: a click, and Space when focused":
    var n = 0
    let f = newFloatingActionButton(icon = "+", onClick = proc() = inc n)
    let r = newRig(stack(f), 200, 200)
    r.click(f)
    r.focus(f)
    r.key(KeyboardKey.Space)
    check n == 2
    let ext = newFloatingActionButton(icon = "+", label = "Compose")
    ext.layout()
    check ext.bounds.width > ext.bounds.height
    disposeTree(r.root)

suite "BottomSheet":
  teardown:
    motion = motionFull
    clearRepaints()

  proc rig(): (Rig, BottomSheet, Button) =
    var sheet: BottomSheet
    var under: Button
    let root = ui:
      Stack(fit = StackFit.expand):
        under = Button(text = "under")
        sheet = BottomSheet(snaps = @[0.4'f32, 0.9]):
          Label(text = "sheet content")
    let r = newRig(root, 400, 500)                 # (the App applies the preferences' motion)
    motion = motionReduced                         # no easing: positions at once
    (r, sheet, under)

  test "closed it is out of the way; open it rises to the first snap over a scrim":
    var (r, sheet, under) = rig()
    var clicks = 0
    under.onClick = proc() = inc clicks
    r.click(under)
    check clicks == 1                              # closed: the page has the pointer
    sheet.open()
    r.frame(2)
    check sheet.visible and abs(sheet.height - 200) < 0.5      # 0.4 of 500
    r.click(under)                                 # the scrim takes it -- and closes the sheet
    check clicks == 1
    r.frame(2)
    check not sheet.isOpen and not sheet.visible
    disposeTree(r.root)

  test "the handle drags it; let go it settles at the nearest snap, or closes low":
    var (r, sheet, _) = rig()
    sheet.open()
    r.frame(2)
    let top = sheet.bounds.y + sheet.bounds.height - sheet.height
    r.drag(200, top + 10, 200, top - 220)           # up past the middle: to 0.9
    r.frame(2)
    check abs(sheet.height - 450) < 0.5
    let top2 = sheet.bounds.y + sheet.bounds.height - sheet.height
    r.drag(200, top2 + 10, 200, 480)                # far down: closes
    r.frame(2)
    check not sheet.isOpen
    disposeTree(r.root)

  test "Escape from inside closes it; snaps are pure arithmetic":
    var (r, sheet, _) = rig()
    sheet.open()
    r.frame(2)
    r.key(KeyboardKey.Escape)
    r.frame(2)
    check not sheet.isOpen
    check nearestSnap(260, 500, @[0.4'f32, 0.9], true) == 200
    check nearestSnap(400, 500, @[0.4'f32, 0.9], true) == 450
    check nearestSnap(60, 500, @[0.4'f32, 0.9], true) == 0
    check nearestSnap(60, 500, @[0.4'f32, 0.9], false) == 200
    disposeTree(r.root)
