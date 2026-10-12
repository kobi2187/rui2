## Main-thread pollers, and the way a worker thread wakes the loop.
##
## A data source that fetches in the background cannot touch widgets from its
## worker. It queues what it fetched, and the main thread drains the queue: each
## frame the App runs every registered poller, and a poller that found news
## returns true so the frame repaints. `wakeHook` is how a worker that has just
## queued something gets a blocked idle loop to run that frame at all (the App
## points it at `wakeMainLoop`, which is safe from any thread).

import std/[locks]

type Poller* = proc(): bool {.closure.}

var
  pollers: seq[tuple[id: int, call: Poller]]
  nextPollerId = 0
  wakeHook*: proc() {.nimcall, gcsafe.}
    ## Called from any thread when background work has something to show.

proc addPoller*(call: Poller): int =
  inc nextPollerId
  pollers.add (nextPollerId, call)
  nextPollerId

proc removePoller*(id: int) =
  for i in countdown(pollers.high, 0):
    if pollers[i].id == id: pollers.delete(i)

proc pollerCount*(): int = pollers.len

proc runPollers*(): bool =
  ## Run every poller; true when any had something new.
  for poller in pollers:
    if poller.call(): result = true

proc wakeMain*() =
  ## From any thread: ask the loop to run a frame soon.
  let hook = wakeHook
  if hook != nil: hook()
