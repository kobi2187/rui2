## Files dropped on the window reach the widget under the pointer, as an event.

import std/[unittest, os, strutils]
import rui
import rui_hittest

proc routerFor(root: Widget): EventRouter =
  var hit = newHitTestSystem()
  proc insertAll(w: Widget) =
    hit.insertWidget(w)
    for c in w.children: insertAll(c)
  insertAll(root)
  newEventRouter(hit, newFocusManager(), newHoverTracker())

suite "evFileDrop":

  let dir = getTempDir() / "rui_filedrop_test"
  setup:
    createDir(dir)
    writeFile(dir / "notes.txt", "hello")
    writeFile(dir / "photo.png", "x")
  teardown:
    removeDir(dir)

  test "the drop lands on the widget under the pointer, not on its neighbour":
    let left = newDragDropArea(acceptedExtensions = @[".txt"])
    let right = newDragDropArea(acceptedExtensions = @[".txt"])
    let row = newHStack(spacing = 0.0)
    row.addChild left
    row.addChild right
    row.bounds = Rect(x: 0, y: 0, width: 600, height: 150)
    row.layout()
    var droppedLeft, droppedRight: seq[string]
    left.onFilesDropped = proc(files: seq[DroppedItem]) =
      for f in files: droppedLeft.add extractFilename(f.path)
    right.onFilesDropped = proc(files: seq[DroppedItem]) =
      for f in files: droppedRight.add extractFilename(f.path)
    let router = routerFor(row)

    discard router.routePointer(GuiEvent(kind: evFileDrop, mousePos: Point(x: 450, y: 50),
                                         paths: @[dir / "notes.txt"]))
    check droppedLeft.len == 0
    check droppedRight == @["notes.txt"]

  test "files the widget does not accept are rejected with a reason":
    let area = newDragDropArea(acceptedExtensions = @[".txt"])
    area.bounds = Rect(x: 0, y: 0, width: 300, height: 150)
    var accepted, rejected: seq[string]
    var reason = ""
    area.onFilesDropped = proc(files: seq[DroppedItem]) =
      for f in files: accepted.add extractFilename(f.path)
    area.onFilesRejected = proc(files: seq[string], why: string) =
      for f in files: rejected.add extractFilename(f)
      reason = why
    let router = routerFor(area)
    discard router.routePointer(GuiEvent(kind: evFileDrop, mousePos: Point(x: 10, y: 10),
                                         paths: @[dir / "notes.txt", dir / "photo.png"]))
    check accepted == @["notes.txt"]
    check rejected == @["photo.png"]
    check reason.len > 0
    check area.errorMessage == reason

  test "a drop that lands on nothing is ignored":
    let area = newDragDropArea()
    area.bounds = Rect(x: 0, y: 0, width: 300, height: 150)
    var fired = false
    area.onFilesDropped = proc(files: seq[DroppedItem]) = fired = true
    let router = routerFor(area)
    discard router.routePointer(GuiEvent(kind: evFileDrop, mousePos: Point(x: 900, y: 900),
                                         paths: @[dir / "notes.txt"]))
    check not fired

  test "any widget can take drops with on_file_drop, and the event bubbles":
    # A Panel around the area: the area handles it, so the drop does not need
    # to be handled by (or even known to) the container.
    let area = newDragDropArea()
    let panel = newPanel()
    panel.addChild area
    panel.bounds = Rect(x: 0, y: 0, width: 300, height: 150)
    panel.layout()
    var n = 0
    area.onFilesDropped = proc(files: seq[DroppedItem]) = n = files.len
    let router = routerFor(panel)
    let spot = Point(x: area.bounds.x + 5, y: area.bounds.y + 5)
    discard router.routePointer(GuiEvent(kind: evFileDrop, mousePos: spot,
                                         paths: @[dir / "notes.txt", dir / "photo.png"]))
    check n == 2
