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
##     proc(): string = fetch(url),           # on the background thread
##     proc(page: string) = view.text = page, # back on the UI thread
##     proc(err: string) = status.text = "failed: " & err))
## ```
##
## **One dedicated thread, one queue.** The jobs go to a single background
## thread, started the first time one is asked for, and run there one at a
## time, in the order they were asked for; their `done`s come back in that
## order too. So two saves never interleave, and a later job sees what an
## earlier one did. The price: a long job holds up the ones behind it
## (`backgroundJobs()` says how many are waiting). The App stops the thread
## when it closes (`stopBackground`).
##
## `work` runs on that thread and must not touch widgets (or anything else
## the UI thread is using): give it plain values -- copy what it needs into
## locals first, as `url` above -- and have it return its result. `done` gets
## that result on the UI thread, at the next frame, and may change widgets
## freely; `failed` gets the message if `work` raised. An idle app is woken
## the moment a job is finished.
##
## Started in a loop, each job needs its own copy of the loop's values: Nim's
## closures made in one loop body share its variables, so wrap the body in
## `closureScope:` (or call a proc that starts the job).

import std/[locks]
import pollers

type
  JobBase {.inheritable.} = object
    run: proc(job: pointer) {.nimcall, gcsafe.}      # on the background thread
    deliver: proc(job: pointer) {.nimcall.}          # then on the UI thread

  JobObj[T] = object of JobBase
    work: proc(): T {.gcsafe.}
    done: proc(result: T)
    failed: proc(error: string)
    ok: bool
    value: T
    error: string

  Job[T] = ref JobObj[T]

# The UI thread owns every job (`queued`) from the moment it is asked for until
# its result is delivered. The background thread is handed a plain pointer and
# never copies the job or its closure, so their reference counts -- which are
# not atomic -- only ever change on the UI thread.
var
  queued: seq[ref JobBase]                 # asked for, not yet delivered: kept alive
  todo: ptr Channel[pointer]               # UI -> background; nil stops the thread
  finished: ptr Channel[pointer]           # background -> UI
  worker: ptr Thread[void]
  pollerId = 0

proc backgroundLoop() {.thread.} =
  while true:
    let job = todo[].recv()
    if job == nil: break
    cast[ptr JobBase](job).run(job)
    finished[].send(job)
    wakeMain()

proc runJob[T](job: pointer) {.nimcall, gcsafe.} =
  let j = cast[ptr JobObj[T]](job)
  try:
    j.value = j.work()
    j.ok = true
  except CatchableError as e:
    j.error = e.msg

proc deliverJob[T](job: pointer) {.nimcall.} =
  let j = cast[ptr JobObj[T]](job)
  if j.ok:
    if j.done != nil: j.done(j.value)
  elif j.failed != nil:
    j.failed(j.error)
  else:
    stderr.writeLine "[rui] background work failed: ", j.error

proc deliverFinished(): bool =
  ## UI thread, each frame: hand every finished job its result, in order.
  while true:
    let (got, job) = finished[].tryRecv()
    if not got: break
    var keep: ref JobBase
    for i in 0 .. queued.high:
      if cast[pointer](queued[i]) == job:
        keep = queued[i]
        queued.delete(i)
        break
    keep.deliver(job)          # `keep` holds it until its done has run
    result = true

proc startBackground() =
  if worker != nil: return
  todo = createShared(Channel[pointer])
  todo[].open()
  finished = createShared(Channel[pointer])
  finished[].open()
  worker = createShared(Thread[void])
  createThread(worker[], backgroundLoop)
  pollerId = addPoller(deliverFinished)

proc stopBackground*() =
  ## Let the jobs already queued finish, deliver them, and stop the
  ## background thread. The App does this when it closes; the next
  ## `runInBackground` starts it again.
  if worker == nil: return
  todo[].send(nil)
  joinThread(worker[])
  discard deliverFinished()
  removePoller(pollerId)
  todo[].close()
  finished[].close()
  deallocShared(worker)
  deallocShared(todo)
  deallocShared(finished)
  worker = nil

proc backgroundJobs*(): int =
  ## Jobs asked for whose results have not been delivered yet.
  queued.len

proc runInBackground*[T](work: proc(): T {.gcsafe.}, done: proc(result: T),
                         failed: proc(error: string) = nil) =
  ## Queue `work` for the background thread; hand its result to `done` on the
  ## UI thread (or the message of what it raised to `failed`). See the module
  ## comment.
  startBackground()
  let job = Job[T](run: runJob[T], deliver: deliverJob[T],
                   work: work, done: done, failed: failed)
  queued.add job
  todo[].send(cast[pointer](job))

proc runInBackground*(work: proc() {.gcsafe.}, done: proc() = nil,
                      failed: proc(error: string) = nil) =
  ## The same for work that returns nothing: `done` runs when it has finished.
  runInBackground(proc(): bool {.gcsafe.} = (work(); true),
                  proc(_: bool) = (if done != nil: done()), failed)
