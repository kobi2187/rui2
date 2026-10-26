## Messages from other threads: `Mailbox[T]`.
##
## UI state -- Links, widgets, stores -- belongs to the UI thread. Another
## thread (a socket reader, a file watcher, a worker pool of your own) never
## changes it. It *sends* a message to a mailbox, and the UI thread, between
## frames, hands each message to the receiver the mailbox was made with, which
## changes whatever it likes:
##
## ```nim
## let progress = newLink(0.0)
## let box = newMailbox(proc(done: float) = progress.value = done)   # UI thread
##
## proc download(box: Mailbox[float]) {.thread.} =
##   for part in 1 .. 10:
##     fetchPart(part)
##     box.send(part / 10)                 # any thread: a copy goes in the queue
## createThread(t, download, box)
## ```
##
## - **Only values cross.** `send` copies the message into the queue (strings,
##   seqs and objects deeply), so the sender keeps nothing the UI thread uses.
##   A message holds plain data, not refs to UI objects.
## - **In order, on the UI thread, between frames.** Each frame the queue is
##   drained and the receiver called once per message, in the order they were
##   sent. An idle app is woken the moment a message arrives.
## - **Latest only:** `newMailbox(receive, latest = true)` delivers only the
##   newest message of each frame -- for progress and positions, where a
##   backlog of stale values is no use.
## - A `Mailbox` is a small value: copy it into as many threads as you like.
## - `close` it on the UI thread when done. Messages sent after that are
##   dropped; the queue is freed when the last copy of the mailbox is gone, on
##   whichever thread that is.
##
## `runInBackground` (background.nim) is the shortcut for the commonest case: one
## job, one result. A mailbox is for threads you run yourself, and for many
## messages over time.

import std/atomics
import pollers

type
  Shared[T] = object
    queue: Channel[T]
    copies: Atomic[int]          # Mailbox values alive, on every thread
    closed: Atomic[bool]
    poller: int                  # UI thread only

  Mailbox*[T] = object
    ## A handle on the queue. Copies count, across threads: the queue is freed
    ## when the last one goes, so a thread that sends late can never write
    ## into freed memory -- its message is just dropped.
    box: ptr Shared[T]

proc `=destroy`*[T](m: Mailbox[T]) =
  if m.box != nil and m.box.copies.fetchSub(1) == 1:
    m.box.queue.close()
    deallocShared(m.box)

proc `=copy`*[T](dst: var Mailbox[T], src: Mailbox[T]) =
  if dst.box == src.box: return
  `=destroy`(dst)
  wasMoved(dst)
  if src.box != nil: discard src.box.copies.fetchAdd(1)
  dst.box = src.box

proc newMailbox*[T](receive: proc(message: T) {.closure.}, latest = false): Mailbox[T] =
  ## A mailbox whose messages go to `receive`, on the UI thread. Make it on
  ## the UI thread.
  let box = cast[ptr Shared[T]](allocShared0(sizeof(Shared[T])))
  box.queue.open()
  box.copies.store(1)
  result = Mailbox[T](box: box)
  var own = result                   # the receiving side's copy, until close
  box.poller = addPoller(proc(): bool =
    var last: T
    var got = false
    while not own.box.closed.load:
      let (have, msg) = own.box.queue.tryRecv()
      if not have: break
      got = true
      if latest: last = msg
      else: receive(msg)
    if got and latest: receive(last)
    got)

proc send*[T](m: Mailbox[T], message: T) =
  ## From any thread: queue a copy of `message` for the UI thread, and wake
  ## it. Dropped once the mailbox is closed.
  if m.box == nil or m.box.closed.load: return
  m.box.queue.send(message)
  wakeMain()

proc pending*[T](m: Mailbox[T]): int =
  ## Messages sent and not yet delivered.
  if m.box == nil or m.box.closed.load: 0 else: m.box.queue.peek()

proc isOpen*[T](m: Mailbox[T]): bool =
  m.box != nil and not m.box.closed.load

proc close*[T](m: Mailbox[T]) =
  ## On the UI thread: stop delivering. Messages still queued, and any sent
  ## later, are dropped; the queue itself goes with the last copy.
  if m.box == nil or m.box.closed.exchange(true): return
  removePoller(m.box.poller)         # and with it the receiver's copy
