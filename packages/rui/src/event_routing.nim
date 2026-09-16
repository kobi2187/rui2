## Where a delivered event goes.
##
## Split out of app.nim's `handleEvent`, which was cc=17 and 71 lines -- mostly
## because evMouseDown, evMouseUp, evMouseMove and evMouseWheel each spelled out
## the same hit-test, bubble, mark-dirty sequence with small variations. They
## are one `routePointer` now.
##
## The other reason to move it: routing takes an `EventRouter` rather than the
## App, so it needs a widget tree and three collaborators and nothing else --
## no window, no raylib, no run loop. That is what makes a frame's routing
## checkable headlessly, which it was not while it was a private proc reaching
## into App's fields.

import rui_core
import rui_events
import rui_hittest

type
  EventRouter* = ref object
    ## The three things routing an event needs to consult.
    hitTest*: HitTestSystem
      ## Which widget is under a point.
    focus*: FocusManager
      ## Where keys go, and what Tab moves.
    hover*: HoverTracker
      ## Which widget the pointer is over, and the transition when that changes.

proc newEventRouter*(hitTest: HitTestSystem, focus: FocusManager,
                     hover: HoverTracker): EventRouter =
  EventRouter(hitTest: hitTest, focus: focus, hover: hover)

proc dispatchBubbling*(widget: Widget, event: GuiEvent): bool =
  ## Offer the event to the hit widget, then to each ancestor in turn until one
  ## handles it.
  ##
  ## Composite widgets build themselves out of primitives -- a Button is a
  ## Rectangle plus a Label -- and hit-testing lands on the innermost of those.
  ## Those primitives declare no event handlers, so without bubbling the click
  ## stopped at the Rectangle and the Button's onClick never fired.
  var w = widget
  while w != nil:
    if w.handleInput(event):
      return true
    w = w.parent
  false

proc focusTargetFor*(widget: Widget): Widget =
  ## Which widget a click on `widget` should focus.
  ##
  ## Hit-testing lands on the innermost primitive -- clicking a Button lands on
  ## its Rectangle -- and those primitives are not focusable and not in the
  ## focus chain. Focusing one directly left the focus manager holding a widget
  ## Tab had never heard of, so the next Tab restarted from the beginning of the
  ## form instead of continuing from where the user had clicked.
  ##
  ## So focus walks outward to the nearest focusable ancestor, the same
  ## direction events bubble. nil when nothing in the chain is focusable, which
  ## clears the focus -- clicking the background should let go of the field you
  ## were in.
  var w = widget
  while w != nil:
    if w.focusable and w.visible and w.enabled:
      return w
    w = w.parent
  nil

proc widgetAt(router: EventRouter, event: GuiEvent): Widget =
  router.hitTest.getWidgetAt(event.mousePos.x, event.mousePos.y)

proc updateHover(router: EventRouter, widget: Widget): bool =
  ## Move the hover to `widget`, repainting both sides of the transition.
  ## Returns whether anything changed.
  ##
  ## The clearing half used to be missing -- routing only ever set
  ## `hovered = true` and nothing anywhere set it back, so every widget the
  ## pointer had touched stayed lit and a Tooltip could never hide. The tracker
  ## owns the transition now and reports whether one happened, so a still
  ## pointer costs nothing.
  let previous = router.hover.hovered
  if not router.hover.setHover(widget):
    return false
  if previous != nil:
    previous.markDirtyToRoot()     # the widget being left has to repaint too
  if widget != nil:
    widget.markDirtyToRoot()
  true

proc routePointer*(router: EventRouter, event: GuiEvent): bool =
  ## Deliver a pointer event to whatever is under it. Returns whether the tree
  ## needs repainting.
  ##
  ## The four pointer kinds differ in exactly two ways -- whether they take
  ## focus, and whether they move the hover -- so those are the only two
  ## conditions here. Everything else was copied four times.
  let widget = router.widgetAt(event)

  var dirty = false
  if event.kind == evMouseMove:
    dirty = router.updateHover(widget)

  if widget == nil:
    return dirty

  if event.kind == evMouseDown:
    router.focus.requestFocus(focusTargetFor(widget))

  discard widget.dispatchBubbling(event)

  # A move that did not change the hover changes nothing to repaint; a press,
  # release or wheel always might -- a press state, a scroll offset.
  if event.kind != evMouseMove:
    widget.markDirtyToRoot()
    dirty = true
  dirty

proc routeKeyboard*(router: EventRouter, root: Widget, event: GuiEvent): bool =
  ## Keys go through the focus manager, which tries the focused widget, then its
  ## focus group, then the global navigation keys. Returns whether it was
  ## handled -- false is normal and means nothing wanted that key.
  if root == nil:
    return false
  router.focus.handleKeyboardEvent(event, root)

proc resizeRoot*(root: Widget, size: Size): bool =
  ## Grow the root to the new window size. Returns whether anything changed.
  if root == nil:
    return false
  root.bounds.width = size.width
  root.bounds.height = size.height
  root.layoutDirty = true
  root.isDirty = true
  true
