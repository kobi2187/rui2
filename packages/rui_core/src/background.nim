## Slow work off the UI thread: `runInBackground`.
##
## Everything a widget calls back -- an `onClick`, an `onSelect` -- runs on
## the UI thread, between frames. While it runs, nothing is drawn and no input
## is handled: a callback that sleeps for three seconds freezes the window for
## three seconds (the clicks made meanwhile wait, and land all at once after).
## Anything that may take long -- a network request, a big file, a heavy
## computation -- belongs here instead:
##
## ```nim
## Button(text = "Fetch", onClick = proc() =
##   status.text = "fetching..."              # shows at once: the UI keeps running
##   let url = urlBox.text                    # read what the work needs here
##   runInBackground(
##     proc(): string = fetch(url),           # on a worker thread
##     proc(page: string) = view.text = page, # back on the UI thread
##     proc(err: string) = status.text = "failed: " & err))
## ```
##
## `work` runs on its own thread and must not touch widgets (or anything else
## the UI thread is using): give it plain values -- copy what it needs into
## locals first, as `url` above -- and have it return its result. `done` gets
## that result on the UI thread, at the next frame, and may change widgets
## freely; `failed` gets the message if `work` raised. An idle app is woken
## the moment the work is finished.
##
## Started in a loop, each job needs its own copy of the loop's values: Nim's
## closures made in one loop body share its variables, so wrap the body in
## `closureScope:` (or call a proc that starts the job).

import std/[locks]
import pollers

type
  Outcome[T] = object
    ok: bool
    value: T
    error: string

  WorkBox[T] = ref object
    work: proc(): T {.gcsafe.}

  Handoff[T] = object
    work: ptr proc(): T {.gcsafe.}   # borrowed: the UI thread holds the closure
    box: ptr Channel[Outcome[T]]

proc runner[T](h: Handoff[T]) {.thread.} =
  # The worker calls the closure through a plain pointer and never copies it,
  # so its reference counts -- not atomic -- are only ever changed on the UI
  # thread, which keeps it alive (WorkBox) until the result is delivered.
  var outcome: Outcome[T]
  try:
    outcome = Outcome[T](ok: true, value: h.work[]())
  except CatchableError as e:
    outcome = Outcome[T](ok: false, error: e.msg)
  h.box[].send(outcome)
  wakeMain()

var running = 0
  ## Background jobs not yet delivered. For tests and for an app that wants to
  ## wait for them before quitting.

proc backgroundJobs*(): int = running

proc runInBackground*[T](work: proc(): T {.gcsafe.}, done: proc(result: T),
                         failed: proc(error: string) = nil) =
  ## Run `work` on a worker thread; hand its result to `done` on the UI thread
  ## (or the message of what it raised to `failed`). See the module comment.
  let box = createShared(Channel[Outcome[T]])
  box[].open()
  let keep = WorkBox[T](work: work)
  let thread = createShared(Thread[Handoff[T]])
  createThread(thread[], runner[T], Handoff[T](work: addr keep.work, box: box))
  inc running
  var id = 0
  id = addPoller(proc(): bool =
    let (got, outcome) = box[].tryRecv()
    if not got: return false
    joinThread(thread[])
    deallocShared(thread)
    discard keep                  # held until here: the worker borrowed its closure
    box[].close()
    deallocShared(box)
    removePoller(id)
    dec running
    if outcome.ok:
      if done != nil: done(outcome.value)
    elif failed != nil:
      failed(outcome.error)
    else:
      stderr.writeLine "[rui] background work failed: ", outcome.error
    true)

proc runInBackground*(work: proc() {.gcsafe.}, done: proc() = nil,
                      failed: proc(error: string) = nil) =
  ## The same for work that returns nothing: `done` runs when it has finished.
  runInBackground(proc(): bool {.gcsafe.} = (work(); true),
                  proc(_: bool) = (if done != nil: done()), failed)
