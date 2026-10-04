## The keyboard-navigation highlight: a ring round the focused widget and a
## softer one round its container, only while the keyboard is driving.

import std/unittest
import rui

proc ringsOf(): seq[FocusRing] =
  for o in overlays():
    if o of FocusRing: result.add FocusRing(o)

suite "focus rings":

  proc build(): tuple[app: App, toolbar: Widget, a, b: Button, field: TextArea] =
    clearOverlays()
    let app = newApp("rings")
    let toolbar = newToolBar()
    let a = newButton(text = "A")
    let b = newButton(text = "B")
    toolbar.addChild a
    toolbar.addChild b
    let field = newTextInput()
    let root = newVStack(spacing = 8.0)
    root.addChild toolbar
    root.addChild field
    root.bounds = Rect(x: 0, y: 0, width: 400, height: 300)
    app.setRootWidget(root)
    root.layout()
    (app, Widget(toolbar), a, b, field)

  test "no ring until the keyboard is used":
    let (app, _, a, _, _) = build()
    app.focusManager.setFocus(a)
    app.syncFocusRings()
    check ringsOf().len == 0                      # focus by other means: no ring

  test "a key press shows a ring round the focused widget, a gap outside it":
    let (app, _, a, _, _) = build()
    app.focusManager.setFocus(a)
    app.keyboardMode = true
    app.syncFocusRings()
    let rings = ringsOf()
    check rings.len >= 1
    var found = false
    for r in rings:
      if r.bounds == Rect(x: a.bounds.x - 3, y: a.bounds.y - 3,
                          width: a.bounds.width + 6, height: a.bounds.height + 6):
        found = true
    check found
    clearOverlays()

  test "inside a container, the container gets the softer outer ring":
    let (app, toolbar, a, _, _) = build()
    app.focusManager.setFocus(a)                  # the toolbar is a focus group
    app.keyboardMode = true
    app.syncFocusRings()
    check ringsOf().len == 2
    var outer: Rect
    for r in ringsOf():
      if r.group: outer = r.bounds
    check outer.width > toolbar.bounds.width      # wider than the container itself
    check outer.x < toolbar.bounds.x
    clearOverlays()

  test "the ring follows focus":
    let (app, _, a, b, _) = build()
    app.keyboardMode = true
    app.focusManager.setFocus(a)
    app.syncFocusRings()
    let before = app.widgetRing.bounds
    app.focusManager.setFocus(b)
    app.syncFocusRings()
    check app.widgetRing.bounds != before
    check app.widgetRing.bounds.x < b.bounds.x
    clearOverlays()

  test "leaving the group drops the container's ring and keeps the widget's":
    let (app, _, a, _, field) = build()
    app.keyboardMode = true
    app.focusManager.setFocus(a)
    app.syncFocusRings()
    check ringsOf().len == 2
    app.focusManager.setFocus(field)              # outside any group
    app.syncFocusRings()
    check ringsOf().len == 1
    clearOverlays()

  test "a mouse press takes the rings away; a key brings them back":
    let (app, _, a, _, _) = build()
    app.focusManager.setFocus(a)
    discard app.handleHelp(GuiEvent(kind: evKeyDown, key: chord("Tab").key))
    app.keyboardMode = true                       # what handleEvent does for any key
    app.syncFocusRings()
    check ringsOf().len > 0
    app.keyboardMode = false                      # ...and for a mouse press
    app.syncFocusRings()
    check ringsOf().len == 0

  test "no rings while the help overlay is up":
    let (app, _, a, _, _) = build()
    app.focusManager.setFocus(a)
    app.keyboardMode = true
    app.showHelp()
    app.syncFocusRings()
    check ringsOf().len == 0
    app.hideHelp()
    app.syncFocusRings()
    check ringsOf().len > 0
    clearOverlays()
