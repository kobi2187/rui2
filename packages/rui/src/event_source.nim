## Where a frame's input comes from.
##
## `app.collectRaylibEvents` read the keyboard and mouse directly, so a frame
## could only be exercised by opening a real window. That is the whole reason
## the frame pipeline had no headless tests: not that the layout or the routing
## needed a GPU, but that nothing could hand them an event.
##
## An EventSource is asked for the events that happened since it was last asked.
## Two adapters, which is what justifies the seam at all:
##
## - `RaylibEventSource` reads the live window. What the app uses.
## - `ListEventSource` hands back a list you give it. What a test uses, and what
##   the scripting protocol could drive if key and pointer injection ever became
##   part of it -- today they are gated behind `-d:ruiTestKeys`, deliberately,
##   because a scripter should query and operate controls rather than pretend to
##   be a mouse.

import rui_core
import rui_events
import std/monotimes

import raylib

type
  EventSource* = ref object of RootObj
    ## Everything a frame needs to know about the outside world.

  RaylibEventSource* = ref object of EventSource
    ## The live window.

  ListEventSource* = ref object of EventSource
    ## A queue you fill. `poll` drains it, so an event is delivered once.
    pending*: seq[GuiEvent]

method poll*(source: EventSource): seq[GuiEvent] {.base.} =
  ## Events since the last call. The base returns nothing, so an app with no
  ## source configured runs with a still window rather than crashing.
  @[]

proc newRaylibEventSource*(): RaylibEventSource = RaylibEventSource()

proc newListEventSource*(events: seq[GuiEvent] = @[]): ListEventSource =
  ListEventSource(pending: events)

proc push*(source: ListEventSource, event: GuiEvent) =
  source.pending.add(event)

method poll*(source: ListEventSource): seq[GuiEvent] =
  result = source.pending
  source.pending = @[]

# ---------------------------------------------------------------------------
# The raylib adapter
#
# One proc per input kind, so each is a couple of lines and says which raylib
# call it wraps. This was one 72-line routine at cc=9.
# ---------------------------------------------------------------------------

proc motionEvents(dest: var seq[GuiEvent], at: Point) =
  ## Movement and wheel are epNormal because the event manager coalesces them:
  ## a drag produces one event per frame however many the OS delivered.
  let delta = getMouseDelta()
  if delta.x != 0 or delta.y != 0:
    dest.add(GuiEvent(kind: evMouseMove, priority: epNormal,
                      timestamp: getMonoTime(), mousePos: at))

  let wheelMove = getMouseWheelMove()
  if wheelMove != 0:
    dest.add(GuiEvent(kind: evMouseWheel, priority: epNormal,
                      timestamp: getMonoTime(), wheelDelta: wheelMove))

proc buttonEvents(dest: var seq[GuiEvent], at: Point) =
  ## epHigh because their order matters and they must not be coalesced away --
  ## a press and a release in the same frame is a click.
  if isMouseButtonPressed(MouseButton.Left):
    dest.add(GuiEvent(kind: evMouseDown, priority: epHigh,
                      timestamp: getMonoTime(), mousePos: at))
  if isMouseButtonReleased(MouseButton.Left):
    dest.add(GuiEvent(kind: evMouseUp, priority: epHigh,
                      timestamp: getMonoTime(), mousePos: at))

proc pointerEvents(dest: var seq[GuiEvent]) =
  let mousePos = getMousePosition()
  let at = Point(x: mousePos.x, y: mousePos.y)
  motionEvents(dest, at)
  buttonEvents(dest, at)

proc keyboardEvents(dest: var seq[GuiEvent]) =
  ## epHigh and never coalesced: dropping or reordering a keystroke loses text.
  let key = getKeyPressed()
  if key != KeyboardKey(0):
    dest.add(GuiEvent(kind: evKeyDown, priority: epHigh,
                      timestamp: getMonoTime(), key: key))

  let charPressed = getCharPressed()
  if charPressed.int32 > 0:
    dest.add(GuiEvent(kind: evChar, priority: epHigh,
                      timestamp: getMonoTime(), char: char(charPressed)))

proc windowEvents(dest: var seq[GuiEvent]) =
  if isWindowResized():
    dest.add(GuiEvent(kind: evWindowResize, priority: epNormal,
                      timestamp: getMonoTime(),
                      windowSize: Size(width: float32(getScreenWidth()),
                                       height: float32(getScreenHeight()))))

method poll*(source: RaylibEventSource): seq[GuiEvent] =
  pointerEvents(result)
  keyboardEvents(result)
  windowEvents(result)
