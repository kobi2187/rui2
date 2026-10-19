## Fingers beyond the first, as pointer events.
##
## raylib already folds the first finger into the mouse (position, button), so
## the mouse path carries pointer 0 and every widget works on a touch screen
## unchanged. What it does not give is a second pointer: `touchDiff` compares the
## touch points of this frame with the last and says which went down, moved or
## came up, as ordinary mouse events with a `pointerId` (1 and up). The router
## shows them only to widgets that set `multiPointer` (event_routing.nim).
##
## Pure on purpose -- the raylib calls are in event_source.nim -- so it is tested
## by handing it frames of points.

import std/[tables, monotimes, algorithm]
import rui_core

type TouchFrame* = seq[tuple[id: int, at: Point]]
  ## The touch points raylib reports this frame, first finger first.

proc touchDiff*(known: var Table[int, Point], frame: TouchFrame,
                stamp = getMonoTime()): seq[GuiEvent] =
  ## Events for what changed since `known` (the last frame's extra fingers, which
  ## this updates). The first point in `frame` is the mouse's finger and is
  ## skipped. A finger's pointer id is its touch id + 1, so it can never be 0.
  var now = initTable[int, Point]()
  for i, t in frame:
    if i > 0: now[t.id + 1] = t.at

  var gone: seq[int]
  for id in known.keys:
    if id notin now: gone.add id
  gone.sort()
  for id in gone:
    result.add GuiEvent(kind: evMouseUp, priority: epHigh, timestamp: stamp,
                        mousePos: known[id], pointerId: id)
    known.del id

  var ids: seq[int]
  for id in now.keys: ids.add id
  ids.sort()
  for id in ids:
    let at = now[id]
    if id notin known:
      result.add GuiEvent(kind: evMouseMove, priority: epNormal, timestamp: stamp,
                          mousePos: at, pointerId: id)
      result.add GuiEvent(kind: evMouseDown, priority: epHigh, timestamp: stamp,
                          mousePos: at, pointerId: id)
      known[id] = at
    elif known[id] != at:
      result.add GuiEvent(kind: evMouseMove, priority: epNormal, timestamp: stamp,
                          mousePos: at, pointerId: id)
      known[id] = at
