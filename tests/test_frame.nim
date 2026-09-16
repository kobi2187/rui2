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
import std/[options, monotimes, os]
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
