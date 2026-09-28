## The frame pipeline, driven without a window
##
## This suite is the point of the event-source seam. Before it, `app.run` read
## raylib directly, so the only way to exercise collect -> route -> layout ->
## render was to open a real window — which is why the pipeline had no tests at
## all while every piece under it had plenty.
##
## `app.stepHeadless()` is one frame minus the composite to screen. A ListEventSource
## hands it whatever events the test wants.

import std/unittest
import std/[options, monotimes, os, times]
import rui
# rui_core does not re-export KeyboardKey -- its Menu/Down/Up fields collide
# with the Menu widget and with rui_drawing's ArrowDirection.
from raylib import KeyboardKey, Tab

proc headlessApp(root: Widget): tuple[app: App, source: ListEventSource] =
  let app = newApp(title = "test", width = 400, height = 300)
  let source = newListEventSource()
  app.eventSource = source
  app.setRootWidget(root)
  (app, source)

proc at(kind: EventKind, x, y: float32): GuiEvent =
  GuiEvent(kind: kind, priority: epHigh, timestamp: getMonoTime(),
           mousePos: Point(x: x, y: y))

suite "a frame with nothing in it":

  test "an app with no events runs a frame and stays put":
    let root = newVStack()
    let (app, _) = headlessApp(root)
    app.stepHeadless()
    app.stepHeadless()
    check app.tree.root == root

  test "the per-frame hook runs once per frame":
    let (app, _) = headlessApp(newVStack())
    var ticks = 0
    app.onFrame = proc() = inc ticks
    app.stepHeadless()
    app.stepHeadless()
    app.stepHeadless()
    check ticks == 3

suite "events reach widgets":

  setup:
    let button = newButton(text = "Go")
    button.bounds = Rect(x: 0, y: 0, width: 100, height: 40)
    let root = newVStack(padding = 0.0, spacing = 0.0)
    root.bounds = Rect(x: 0, y: 0, width: 400, height: 300)
    root.addChild(button)
    let (app, source) = headlessApp(root)
    app.stepHeadless()                      # lay out, so the hit-test tree exists

  test "a press and release fires the handler":
    var fired = 0
    button.onClick = proc() = inc fired

    source.push(at(evMouseDown, 20.0, 10.0))
    source.push(at(evMouseUp, 20.0, 10.0))
    app.stepHeadless()

    check fired == 1

  test "a press outside the widget does not":
    var fired = 0
    button.onClick = proc() = inc fired

    source.push(at(evMouseDown, 380.0, 280.0))
    source.push(at(evMouseUp, 380.0, 280.0))
    app.stepHeadless()

    check fired == 0

  test "a press focuses the nearest focusable ancestor, not the hit primitive":
    # Hit-testing lands on the Button's inner Rectangle, which is not focusable
    # and not in the focus chain. Focusing it directly left the focus manager
    # holding a widget Tab had never heard of, so the next Tab restarted from
    # the beginning of the form.
    check app.currentFocusedWidget() == nil
    source.push(at(evMouseDown, 20.0, 10.0))
    app.stepHeadless()
    check app.currentFocusedWidget() == Widget(button)

  test "a move sets the hover, and leaving clears it":
    # The bug this guards: nothing ever cleared `hovered`, so every widget the
    # pointer had touched stayed lit and a Tooltip could never hide.
    source.push(at(evMouseMove, 20.0, 10.0))
    app.stepHeadless()
    let overButton = app.hoverTracker.hovered
    check overButton != nil
    check overButton.isWithin(Widget(button))

    source.push(at(evMouseMove, 380.0, 280.0))
    app.stepHeadless()
    check app.hoverTracker.hovered != overButton

  test "the source is drained, so an event is delivered once":
    var fired = 0
    button.onClick = proc() = inc fired
    source.push(at(evMouseDown, 20.0, 10.0))
    source.push(at(evMouseUp, 20.0, 10.0))
    app.stepHeadless()
    app.stepHeadless()
    app.stepHeadless()
    check fired == 1

suite "keyboard reaches the focus manager":

  test "Tab moves focus between controls":
    let a = newButton(text = "a")
    let b = newButton(text = "b")
    let root = newVStack()
    root.bounds = Rect(x: 0, y: 0, width: 400, height: 300)
    root.addChild(a)
    root.addChild(b)
    let (app, source) = headlessApp(root)
    app.stepHeadless()

    source.push(GuiEvent(kind: evKeyDown, priority: epHigh,
                         timestamp: getMonoTime(), key: Tab))
    app.stepHeadless()
    check app.currentFocusedWidget() == Widget(a)

    source.push(GuiEvent(kind: evKeyDown, priority: epHigh,
                         timestamp: getMonoTime(), key: Tab))
    app.stepHeadless()
    check app.currentFocusedWidget() == Widget(b)

  test "a character reaches the focused text input":
    let input = newTextInput(initialText = "")
    let root = newVStack()
    root.bounds = Rect(x: 0, y: 0, width: 400, height: 300)
    root.addChild(input)
    let (app, source) = headlessApp(root)
    app.stepHeadless()
    app.focusManager.setFocus(input)

    for ch in "hi":
      source.push(GuiEvent(kind: evChar, priority: epHigh,
                           timestamp: getMonoTime(), char: ch))
    app.stepHeadless()

    check input.text == "hi"

suite "the window resizing":

  test "a resize grows the root and marks it for layout":
    # Resize is debounced by 350ms -- dragging a window edge produces a stream
    # of them and laying out on every one is what makes a resize feel like mud.
    # So the test has to wait the debounce out, which is also the documentation
    # for it.
    let root = newVStack()
    let (app, source) = headlessApp(root)
    app.stepHeadless()

    source.push(GuiEvent(kind: evWindowResize, priority: epNormal,
                         timestamp: getMonoTime(),
                         windowSize: Size(width: 800.0, height: 600.0)))
    app.stepHeadless()
    check root.bounds.width == 400.0        # not yet: still debouncing

    sleep(400)
    app.stepHeadless()

    check root.bounds.width == 800.0
    check root.bounds.height == 600.0
    check app.window.width == 800
    check app.window.height == 600

suite "routing, without an app at all":
  ## EventRouter takes its three collaborators rather than the App, so it can be
  ## assembled directly.

  test "a router built by hand routes a click":
    let button = newButton(text = "Go")
    button.bounds = Rect(x: 0, y: 0, width: 100, height: 40)
    var fired = 0
    button.onClick = proc() = inc fired

    var hitTest = newHitTestSystem()
    hitTest.insertWidget(Widget(button))
    let router = newEventRouter(hitTest, newFocusManager(), newHoverTracker())

    discard router.routePointer(at(evMouseDown, 10.0, 10.0))
    discard router.routePointer(at(evMouseUp, 10.0, 10.0))
    check fired == 1

  test "a pointer event over nothing is not an error":
    let router = newEventRouter(newHitTestSystem(), newFocusManager(),
                                newHoverTracker())
    check not router.routePointer(at(evMouseDown, 10.0, 10.0))

  test "bubbling reaches a composite's own handler":
    # Hit-testing lands on the innermost primitive -- a Button is a Rectangle
    # plus a Label -- so without bubbling the click stops at the Rectangle.
    let button = newButton(text = "Go")
    button.bounds = Rect(x: 0, y: 0, width: 100, height: 40)
    button.layout()
    var fired = 0
    button.onClick = proc() = inc fired

    let inner = button.children[0]
    discard inner.dispatchBubbling(at(evMouseDown, 10.0, 10.0))
    discard inner.dispatchBubbling(at(evMouseUp, 10.0, 10.0))
    check fired == 1

suite "repaint timers":
  ## An idle app paints nothing, so anything that changes with time alone has
  ## to ask for its next frame.

  setup:
    clearRepaints()

  test "a timer marks its widget dirty once it is due, not before":
    let root = newVStack()
    let leaf = newLabel(text = "x")
    root.addChild(leaf)
    root.isDirty = false
    leaf.isDirty = false
    let t0 = getMonoTime()
    leaf.repaintAt(t0 + initDuration(milliseconds = 500))
    check not fireDueRepaints(t0)
    check not leaf.isDirty
    check fireDueRepaints(t0 + initDuration(milliseconds = 500))
    check leaf.isDirty
    check root.isDirty                    # up to the root, so it composites
    check not fireDueRepaints(t0 + initDuration(seconds = 5))   # fired once

  test "asking twice keeps the earlier time":
    let w = newLabel(text = "x")
    let t0 = getMonoTime()
    w.repaintAt(t0 + initDuration(seconds = 2))
    w.repaintAt(t0 + initDuration(seconds = 1))
    w.repaintAt(t0 + initDuration(seconds = 3))
    check nextRepaint().get == t0 + initDuration(seconds = 1)

  test "the caret asks for the next half-second boundary":
    check abs(caretPhaseRemaining(10.0) - 0.5) < 1e-9
    check abs(caretPhaseRemaining(10.2) - 0.3) < 1e-9
    check abs(caretPhaseRemaining(10.7) - 0.3) < 1e-9

suite "tooltips, through the real router":
  ## The old Tooltip could never show: nothing produced the hover event it
  ## waited for, and as a sibling of its target the pointer was never over it.

  setup:
    clearOverlays()
    clearRepaints()
    let target = newButton(text = "Save")
    let tip = newTooltip(text = "Saves the file", delay = 0.5)
    tip.addChild(target)
    let root = newVStack(padding = 0.0, spacing = 0.0)
    root.bounds = Rect(x: 0, y: 0, width: 400, height: 300)
    root.addChild(tip)
    let (app, source) = headlessApp(root)
    app.stepHeadless()
    let inside = (target.bounds.x + 5, target.bounds.y + 5)

  test "resting on the target shows the tip after the delay":
    source.push(at(evMouseMove, inside[0], inside[1]))
    app.stepHeadless()
    check tip.hovering
    check overlays().len == 0                  # not yet
    tip.refreshTip(tip.hoverStart + initDuration(milliseconds = 200))
    check overlays().len == 0                  # still waiting
    tip.refreshTip(tip.hoverStart + initDuration(milliseconds = 500))
    check overlays().len == 1
    check tip.tip.bounds.x == inside[0] + tip.offsetX

  test "the delay is a repaint timer, so it fires in an idle app":
    source.push(at(evMouseMove, inside[0], inside[1]))
    app.stepHeadless()
    check nextRepaint().isSome

  test "leaving the target hides the tip":
    source.push(at(evMouseMove, inside[0], inside[1]))
    app.stepHeadless()
    tip.refreshTip(tip.hoverStart + initDuration(seconds = 1))
    check overlays().len == 1
    source.push(at(evMouseMove, 390.0, 290.0))  # empty space
    app.stepHeadless()
    check tip.isDirty                           # the hover change reached it
    tip.refreshTip(getMonoTime())
    check overlays().len == 0
    check not tip.hovering
