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
import std/[monotimes, unicode, options, tables]
import touch_source

import raylib

type
  EventSource* = ref object of RootObj
    ## Everything a frame needs to know about the outside world.

  RaylibEventSource* = ref object of EventSource
    ## The live window.
    fingers: Table[int, rui_core.Point]
      ## The fingers after the first, as of the last poll (see touch_source.nim).

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
                      timestamp: getMonoTime(), mousePos: at,
                      # The user's scroll speed, applied once here so every
                      # scrolling widget agrees.
                      wheelDelta: wheelMove * prefs.scrollSpeed))

# Mouse buttons, from GLFW's own callback.
#
# raylib answers `isMouseButtonPressed` by comparing the button's state now with
# its state at the last poll. A press and a release that both land between two
# polls -- a trackpad tap is a few milliseconds long; so is any click that arrives
# while the app is busy painting -- leave the two states equal, and the click
# never happened. The callback sees every transition, in order, with the pointer
# where it was at that moment.
type
  ButtonEvent = tuple[down: bool, at: Point, stamp: MonoTime]
  GlfwMouseCb = proc (window: pointer, button, action, mods: cint) {.cdecl.}

proc glfwSetMouseButtonCallback(window: pointer, cb: GlfwMouseCb): GlfwMouseCb
  {.importc: "glfwSetMouseButtonCallback", cdecl.}
proc glfwGetCurrentContext(): pointer {.importc: "glfwGetCurrentContext", cdecl.}
proc glfwGetCursorPos(window: pointer, x, y: ptr cdouble)
  {.importc: "glfwGetCursorPos", cdecl.}

var
  buttonQueue: seq[ButtonEvent]
  raylibMouseCb: GlfwMouseCb
  buttonHooked: bool

proc onMouseButton(window: pointer, button, action, mods: cint) {.cdecl.} =
  if raylibMouseCb != nil:
    raylibMouseCb(window, button, action, mods)      # raylib keeps its own state
  if button == 0 and action in [0.cint, 1.cint]:      # GLFW_MOUSE_BUTTON_LEFT; release / press
    var x, y: cdouble
    glfwGetCursorPos(window, addr x, addr y)
    buttonQueue.add (action == 1, Point(x: x.float32, y: y.float32), getMonoTime())

proc hookMouseButtons() =
  if buttonHooked: return
  let window = glfwGetCurrentContext()     # the GLFWwindow (raylib's own handle is the X11 one)
  if window == nil: return
  raylibMouseCb = glfwSetMouseButtonCallback(window, onMouseButton)
  buttonHooked = true

proc buttonEvents(dest: var seq[GuiEvent], at: Point) =
  ## epHigh because their order matters and they must not be coalesced away --
  ## a press and a release in the same frame is a click.
  hookMouseButtons()
  if not buttonHooked:                       # no window to hook: raylib's polling
    if isMouseButtonPressed(MouseButton.Left):
      dest.add(GuiEvent(kind: evMouseDown, priority: epHigh,
                        timestamp: getMonoTime(), mousePos: at))
    if isMouseButtonReleased(MouseButton.Left):
      dest.add(GuiEvent(kind: evMouseUp, priority: epHigh,
                        timestamp: getMonoTime(), mousePos: at))
    return
  for b in buttonQueue:
    dest.add(GuiEvent(kind: (if b.down: evMouseDown else: evMouseUp), priority: epHigh,
                      timestamp: b.stamp, mousePos: b.at))
  buttonQueue.setLen(0)

proc dropEvents(dest: var seq[GuiEvent], at: Point) =
  ## Files dropped on the window from the OS. One event for the whole drop,
  ## carrying every path and the pointer position, so it reaches the widget the
  ## files were dropped on rather than whichever one happened to be polling.
  ## epHigh: a drop must not be coalesced away.
  if isFileDropped():
    dest.add(GuiEvent(kind: evFileDrop, priority: epHigh,
                      timestamp: getMonoTime(), mousePos: at,
                      paths: getDroppedFiles()))

proc pointerEvents(dest: var seq[GuiEvent]) =
  let mousePos = getMousePosition()
  let at = Point(x: mousePos.x, y: mousePos.y)
  motionEvents(dest, at)
  buttonEvents(dest, at)
  dropEvents(dest, at)

proc keyboardEvents(dest: var seq[GuiEvent]) =
  ## epHigh and never coalesced: dropping or reordering a keystroke loses text.
  ##
  ## Both are queues, drained to empty. Reading one of each per frame -- as
  ## this used to -- dropped keystrokes whenever two landed in the same frame,
  ## which fast typing and input methods both do.
  var key = getKeyPressed()
  while key != KeyboardKey(0):
    dest.add(GuiEvent(kind: evKeyDown, priority: epHigh,
                      timestamp: getMonoTime(), key: key))
    key = getKeyPressed()

  # A codepoint, not a byte: `char(charPressed)` used to truncate anything
  # past Latin-1 into a different character entirely.
  var charPressed = getCharPressed().int32
  while charPressed > 0:
    dest.add(GuiEvent(kind: evChar, priority: epHigh,
                      timestamp: getMonoTime(),
                      rune: Rune(charPressed),
                      char: (if charPressed < 128: char(charPressed) else: '\0')))
    charPressed = getCharPressed().int32

proc windowEvents(dest: var seq[GuiEvent]) =
  if isWindowResized():
    dest.add(GuiEvent(kind: evWindowResize, priority: epNormal,
                      timestamp: getMonoTime(),
                      windowSize: Size(width: float32(getScreenWidth()),
                                       height: float32(getScreenHeight()))))

proc heldMods(): set[KeyMod] =
  ## The modifiers down right now, read once per poll.
  for key in [LeftShift, RightShift, LeftControl, RightControl,
              LeftAlt, RightAlt, LeftSuper, RightSuper]:
    if isKeyDown(key):
      result.incl modOf(key).get

proc touchEvents(dest: var seq[GuiEvent], known: var Table[int, rui_core.Point]) =
  ## Fingers beyond the first. raylib folds the first into the mouse; the rest
  ## become pointers 2 and up. Nothing is read when there is no touch.
  let n = getTouchPointCount()
  if n >= 2: noteMultiTouch()
  if n <= 1 and known.len == 0: return
  var frame: TouchFrame
  for i in 0 ..< n:
    let p = getTouchPosition(i.int32)
    frame.add (id: getTouchPointId(i.int32).int, at: rui_core.Point(x: p.x, y: p.y))
  dest.add touchDiff(known, frame)

method poll*(source: RaylibEventSource): seq[GuiEvent] =
  pointerEvents(result)
  touchEvents(result, source.fingers)
  keyboardEvents(result)
  windowEvents(result)
  # Stamped here, once, rather than by each producer: every event in a poll
  # happened under the same modifiers, and a widget then asks the event.
  let mods = heldMods()
  for e in result.mitems:
    e.mods = mods
