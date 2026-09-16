## The inspection surface — geometry and structure as text
##
## These answer what a screenshot answers badly: where a widget actually lands
## once clipping is applied, what a click would hit, the shape of the tree.
## Appearance stays in the framebuffer, deliberately.
##
## The procs are exported unconditionally so they can be tested; only the
## *wiring* into the scripting protocol is gated behind -d:ruiInspect.

import std/unittest
import std/[options, json]
import rui

proc labelled(text: string, id: string): Label =
  result = newLabel(text = text, fontSize = 14.0)
  result.stringId = id

suite "effective visibility":

  test "an unclipped widget is fully visible":
    let w = labelled("x", "w")
    w.bounds = Rect(x: 10, y: 10, width: 100, height: 20)
    check w.visibleRect == w.bounds
    check w.isShowing
    check w.clippingAncestor == nil

  test "a hidden widget is not showing, whatever its bounds":
    let w = labelled("x", "w")
    w.bounds = Rect(x: 0, y: 0, width: 100, height: 20)
    w.visible = false
    check not w.isShowing

  test "a ScrollView's clip cuts a row down":
    # This is the number `visible` sounds like it reports and does not: the
    # flag stays true for a row scrolled out of its viewport.
    let sv = newScrollView(padding = 0.0, scrollbarWidth = 16.0)
    sv.bounds = Rect(x: 0, y: 0, width: 200, height: 100)
    sv.stringId = "scroll"
    sv.childClip = some(Rect(x: 0, y: 0, width: 184, height: 100))

    let row = labelled("row", "row")
    row.bounds = Rect(x: 0, y: 0, width: 300, height: 20)
    sv.addChild(row)

    check row.visible                       # the flag says yes
    check row.visibleRect.width == 184.0    # the truth is narrower
    check not (row.visibleRect == row.bounds)
    check row.isShowing

  test "the clipping ancestor is named":
    let sv = newVStack()
    sv.bounds = Rect(x: 0, y: 0, width: 200, height: 100)
    sv.stringId = "scroll"
    sv.childClip = some(Rect(x: 0, y: 0, width: 100, height: 100))
    let row = labelled("row", "row")
    row.bounds = Rect(x: 0, y: 0, width: 300, height: 20)
    sv.addChild(row)

    check row.clippingAncestor == Widget(sv)

  test "a row scrolled past the bottom is not showing at all":
    let sv = newVStack()
    sv.bounds = Rect(x: 0, y: 0, width: 200, height: 100)
    sv.childClip = some(Rect(x: 0, y: 0, width: 200, height: 100))
    let row = labelled("row", "row")
    row.bounds = Rect(x: 0, y: 400, width: 200, height: 20)   # scrolled away
    sv.addChild(row)

    check row.visible                       # still flagged visible
    check not row.isShowing                 # but nobody can see it
    check row.visibleRect.height == 0.0

  test "clips compose down the chain":
    let outer = newVStack()
    outer.bounds = Rect(x: 0, y: 0, width: 300, height: 300)
    outer.childClip = some(Rect(x: 0, y: 0, width: 200, height: 300))
    let inner = newVStack()
    inner.bounds = Rect(x: 0, y: 0, width: 300, height: 300)
    inner.childClip = some(Rect(x: 0, y: 0, width: 300, height: 150))
    outer.addChild(inner)
    let row = labelled("row", "row")
    row.bounds = Rect(x: 0, y: 0, width: 300, height: 300)
    inner.addChild(row)

    let seen = row.visibleRect
    check seen.width == 200.0       # outer's clip
    check seen.height == 150.0      # inner's clip

  test "the report says both what the flag claims and what is true":
    let sv = newVStack()
    sv.bounds = Rect(x: 0, y: 0, width: 200, height: 100)
    sv.stringId = "scroll"
    sv.childClip = some(Rect(x: 0, y: 0, width: 100, height: 100))
    let row = labelled("row", "row")
    row.bounds = Rect(x: 0, y: 0, width: 300, height: 20)
    sv.addChild(row)

    let j = inspectVisible(row)
    check j["visibleFlag"].getBool()
    check j["showing"].getBool()
    check not j["fullyVisible"].getBool()
    check j["visibleRect"]["width"].getFloat() == 100.0
    check j["clippedBy"].getStr() == "scroll"

suite "what is under a point":

  setup:
    let button = newButton(text = "Go")
    button.stringId = "go"
    button.bounds = Rect(x: 0, y: 0, width: 100, height: 40)
    button.layout()                       # builds its Rectangle and Label
    var hitTest = newHitTestSystem()
    proc insertAll(w: Widget) =
      hitTest.insertWidget(w)
      for c in w.children: insertAll(c)
    insertAll(Widget(button))

  test "nothing there is reported as nothing, not an error":
    let j = inspectHit(hitTest, 500.0, 500.0)
    check j["hit"].kind == JNull
    check j["chain"].len == 0

  test "a hit names the innermost primitive, which is rarely what you meant":
    # A click on a Button lands on its Rectangle. Seeing that is the point.
    let j = inspectHit(hitTest, 10.0, 10.0)
    check j["hit"].getStr() != "go"
    check j["type"].getStr() == "Rectangle"

  test "the chain shows where the event would bubble to":
    let j = inspectHit(hitTest, 10.0, 10.0)
    var chain: seq[string] = @[]
    for entry in j["chain"]:
      chain.add(entry.getStr())
    check chain[0] == "Rectangle"         # innermost first
    check "go" in chain                   # and the Button is reachable

  test "focusTarget is where a click would actually put the focus":
    # The bug this would have caught directly: focus used to go to the hit
    # primitive, which is not focusable and not in the focus chain, so the next
    # Tab restarted from the top of the form.
    let j = inspectHit(hitTest, 10.0, 10.0)
    check j["focusTarget"].getStr() == "go"

suite "the tree dump":

  test "it is one line per widget, indented by depth":
    let root = ui:
      VStack():
        Label(text = "a", fontSize = 14.0)
        HStack():
          Label(text = "b", fontSize = 14.0)
    root.stringId = "root"

    let dump = inspectTree(root)
    let lines = dump.strip().splitLines()
    check lines.len == 4
    check lines[0].startsWith("VStack root")
    check lines[1].startsWith("  Label")
    check lines[2].startsWith("  HStack")
    check lines[3].startsWith("    Label")

  test "an empty tree is empty, not a crash":
    check inspectTree(nil) == ""

  test "it records the flags worth diffing":
    let w = newButton(text = "x")
    w.stringId = "b"
    w.focused = true
    let dump = inspectTree(Widget(w))
    check "focused" in dump
    check "tabstop" in dump

  test "it says when a child is clipped, and by how much":
    let sv = newVStack()
    sv.bounds = Rect(x: 0, y: 0, width: 200, height: 100)
    sv.childClip = some(Rect(x: 0, y: 0, width: 100, height: 100))
    let row = labelled("row", "row")
    row.bounds = Rect(x: 0, y: 0, width: 300, height: 20)
    sv.addChild(row)

    check "clipped=100x20" in inspectTree(Widget(sv))

  test "the dump is stable, so it can be diffed between frames":
    let root = ui:
      VStack():
        Label(text = "a", fontSize = 14.0)
    check inspectTree(root) == inspectTree(root)
