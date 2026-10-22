## Containers that move their children (`.animateLayout()`, layout_motion.nim):
## the first placement is where it lands, a reflow travels there over the
## theme's layoutSeconds, children go with a container that moves, and the
## user's `motion: reduced` preference -- or a theme with no layout time --
## turns it all back into snapping.

import std/[unittest, os, options]
import rui

proc panel(h: float32): Widget = newLabel(text = "panel").frame(width = 100, height = h)

proc settle(w: Widget) =
  ## One layout pass, as a frame would run it.
  w.layoutDirty = true
  w.layoutPass()

proc column(animated: bool): (Widget, Widget, Widget) =
  let first = panel(40)
  let second = panel(40)
  let col = newColumn(spacing = 0.0, crossAxisAlignment = CrossAxisAlignment.start)
  col.addChild(first)
  col.addChild(second)
  discard col.animateLayout(animated)
  col.bounds = Rect(x: 0, y: 0, width: 200, height: 300)
  col.settle()
  (col, first, second)

suite "containers that move their children":
  setup:
    animationsEnabled = true

  test "without animateLayout a reflow snaps, as it always did":
    let (col, first, second) = column(animated = false)
    check second.bounds.y == 40
    discard first.frame(height = 120)
    col.settle()
    check second.bounds.y == 120

  test "the first placement is where it lands: nothing flies in from 0,0":
    let (_, _, second) = column(animated = true)
    check second.bounds.y == 40

  test "a reflow travels: the sibling starts where it was and arrives in the theme's time":
    let (col, first, second) = column(animated = true)
    discard first.frame(height = 120)                  # the first panel grows
    col.settle()
    check second.bounds.y == 40                        # still where it was this frame
    sleep(int(currentTheme.layoutSeconds * 1000 / 2))
    col.settle()
    check second.bounds.y > 40 and second.bounds.y < 120    # on its way
    sleep(int(currentTheme.layoutSeconds * 1000) + 30)
    col.settle()
    check second.bounds.y == 120                       # arrived

  test "a theme set before the first placement does not make the first reflow snap":
    inc settleEpoch                                    # what setTheme does
    let (col, first, second) = column(animated = true)
    discard first.frame(height = 120)
    col.settle()
    check second.bounds.y == 40

  test "a container that moves takes its children with it at once":
    let (col, _, second) = column(animated = true)
    col.bounds.y = 50                                  # e.g. its own parent animates it
    col.settle()
    check second.bounds.y == 90                        # 50 + 40, no lag

  test "settled for a script (animationsEnabled off) snaps everything":
    let (col, first, second) = column(animated = true)
    animationsEnabled = false
    discard first.frame(height = 120)
    col.settle()
    check second.bounds.y == 120
    animationsEnabled = true

  test "a theme with no layout time snaps too":
    var t = currentTheme
    t.animation.durationNormal = some(0.0'f32)
    let saved = currentTheme
    currentTheme = t
    let (col, first, second) = column(animated = true)
    discard first.frame(height = 120)
    col.settle()
    check second.bounds.y == 120
    currentTheme = saved

suite "the motion preference":
  test "full, reduced and none, in the words people use (and YAML's on/off)":
    for (value, want) in [("full", motionFull), ("on", motionFull), ("system", motionSystem),
                          ("reduced", motionReduced), ("none", motionNone),
                          ("off", motionNone), ("snappy", motionNone)]:
      let (prefs, problems) = parsePreferences("motion: " & value & "\n")
      check problems.len == 0
      check prefs.motion == want

  test "reduced and none both make a reflow snap":
    for level in [motionReduced, motionNone]:
      motion = level
      let (col, first, second) = column(animated = true)
      discard first.frame(height = 120)
      col.settle()
      check second.bounds.y == 120
    motion = motionFull

suite "Accordion: one section open, the rest folded to their headers":
  proc accordion(): (Accordion, seq[Expander]) =
    var sections: seq[Expander]
    let acc = newAccordion(spacing = 0.0)
    for (title, open) in [("Inbox", true), ("Calendar", true), ("Notes", false)]:
      let e = newExpander(title = title, initialExpanded = open)
      e.addChild(newLabel(text = title & " content").frame(height = 40))
      acc.addChild(e)
      sections.add e
    acc.bounds = Rect(x: 0, y: 0, width: 300, height: 400)
    acc.settle()
    (acc, sections)

  test "the first expanded section is open, it takes the room left, the others are headers":
    animationsEnabled = false
    let (acc, s) = accordion()
    check acc.openIndex == 0
    check s[0].expanded and not s[1].expanded and not s[2].expanded
    let head = s[1].bounds.height
    check s[2].bounds.height == head
    check s[0].bounds.height == 400 - 2 * head
    check s[2].bounds.y + s[2].bounds.height == 400
    animationsEnabled = true

  test "opening another folds the open one, and the sections slide there":
    let (acc, s) = accordion()
    let headerY = s[2].bounds.y
    s[2].expanded = true                       # as a click on its header does
    acc.settle()
    check not s[0].expanded and acc.openIndex == 2
    check s[2].bounds.y == headerY             # this frame: still where it was
    sleep(int(currentTheme.layoutSeconds * 1000) + 40)
    acc.settle()
    check s[2].bounds.y == 2 * s[0].bounds.height   # moved up under two headers
    check s[2].bounds.y + s[2].bounds.height == 400

  test "open(-1) folds them all; measuring does not set anything moving":
    animationsEnabled = false
    let (acc, s) = accordion()
    acc.open(-1)
    acc.settle()
    check acc.openIndex == -1 and not s[0].expanded
    discard acc.measure(unbounded().withWidth(300))
    acc.settle()
    check s[0].bounds.height == s[1].bounds.height
    animationsEnabled = true
