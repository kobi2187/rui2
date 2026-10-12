## Which window is on top, and which one the keyboard belongs to.
##
## Module-level, like the overlay layer it drives: the overlay layer's order
## *is* the z-order, so raising a window is hide + show, and `stack` mirrors it
## for the windows this module manages. Importing `rui_windows` installs the
## press hook (`onPointerPress`); an app that never imports it pays nothing.
##
## The active window is the topmost one that was last clicked or opened. While
## one is active, Tab stays inside it (`focusScope`); a press on the page
## behind, or on anything that is not a window, deactivates it.

import rui_core
import focus_manager

var
  stack: seq[Widget]        # bottom .. top
  active: Widget

proc openWindows*(): seq[Widget] = stack
proc activeWindow*(): Widget = active
proc isManaged*(w: Widget): bool = w in stack

proc windowOf*(widget: Widget): Widget =
  ## The managed window `widget` is inside (or is); nil when it is on the page.
  var w = widget
  while w != nil:
    if w in stack: return w
    w = w.parent
  nil

proc repaint(w: Widget) =
  if w != nil:
    w.isDirty = true
    w.markDirtyToRoot()

proc setActive(w: Widget) =
  if active == w: return
  let previous = active
  active = w
  focusScope = w
  previous.repaint()       # its title bar goes back to the quiet colour
  w.repaint()

proc deactivate*() =
  setActive(nil)

proc raiseWindow*(w: Widget) =
  ## Bring a managed window above every other overlay and make it active.
  if w == nil or w notin stack: return
  if stack[^1] != w:
    stack.delete(stack.find(w))
    stack.add w
    hideOverlay(w)
  showOverlay(w, interactive = true)
  setActive(w)

proc addWindow*(w: Widget) =
  ## Start managing `w` (already a child of its host) and show it on top.
  if w notin stack: stack.add w
  raiseWindow(w)

proc removeWindow*(w: Widget) =
  ## Stop managing `w`: off the overlay layer and the stack; the next window
  ## down becomes active. Does not touch the tree -- `closeWindow` does that.
  let i = stack.find(w)
  if i < 0: return
  stack.delete(i)
  hideOverlay(w)
  if pointerCapture() != nil and pointerCapture().isWithin(w): releasePointer()
  if active == w:
    active = nil
    focusScope = nil
    if stack.len > 0: setActive(stack[^1])

proc resetWindows*() =
  ## Forget every window (the tree is going away); for tests and shutdown.
  stack.setLen(0)
  active = nil
  focusScope = nil

onPointerPress = proc (target: Widget) =
  ## A press anywhere inside a window raises it first -- even on a child that
  ## then consumes the click, which a handler on the window itself never sees.
  ## A press on anything else puts the windows to sleep.
  let w = windowOf(target)
  if w != nil: raiseWindow(w)
  elif active != nil: deactivate()
