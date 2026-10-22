## Slow work off the UI thread (background.nim): the frames keep coming while
## it runs, its result reaches `done` on the UI thread, a failure reaches
## `failed`, and the jobs queue on one dedicated thread, run in order.

import std/[unittest, os, monotimes, times]
import rui
import ui_harness

proc waitFor(r: Rig, cond: proc(): bool, seconds = 3.0) =
  let until = getMonoTime() + initDuration(milliseconds = int(seconds * 1000))
  while not cond() and getMonoTime() < until:
    r.frame(1)
    sleep(5)

suite "runInBackground":
  test "the UI keeps running while the work does; the result comes back on the UI thread":
    let label = newLabel(text = "idle")
    let r = newRig(stack(label))
    let uiThread = getThreadId()
    var gotOn = -1
    var answer = 0
    runInBackground(proc(): int = (sleep(300); 42),
                    proc(v: int) =
                      answer = v
                      gotOn = getThreadId()
                      label.text = "got " & $v)
    let t0 = getMonoTime()
    r.frame(1)                                     # a frame, at once: not blocked
    check getMonoTime() - t0 < initDuration(milliseconds = 100)
    check answer == 0 and backgroundJobs() == 1
    r.waitFor(proc(): bool = answer != 0)
    check answer == 42
    check gotOn == uiThread
    check label.text == "got 42"
    check backgroundJobs() == 0

  test "what the work raises goes to failed":
    let r = newRig(stack(newLabel(text = "x")))
    var err = ""
    runInBackground(proc(): int = raise newException(IOError, "no network"),
                    proc(v: int) = discard,
                    proc(e: string) = err = e)
    r.waitFor(proc(): bool = err.len > 0)
    check err == "no network"

  test "one dedicated thread: jobs run there one at a time, in the order asked":
    let r = newRig(stack(newLabel(text = "x")))
    var threads: seq[int]
    var order: seq[int]
    let t0 = getMonoTime()
    for i in 1 .. 3:
      closureScope:
        let n = i
        runInBackground(proc(): int = (sleep(100); n),
                        proc(v: int) = order.add v)
        runInBackground(proc(): int = getThreadId(), proc(id: int) = threads.add id)
    check backgroundJobs() == 6
    r.waitFor(proc(): bool = order.len == 3 and threads.len == 3)
    check order == @[1, 2, 3]
    check getMonoTime() - t0 >= initDuration(milliseconds = 300)   # one after another
    check threads[0] == threads[1] and threads[1] == threads[2]     # always the same thread
    check threads[0] != getThreadId()                              # and not the UI's

  test "stopBackground finishes what is queued and delivers it; the next job starts it again":
    var got: seq[int]
    runInBackground(proc(): int = (sleep(50); 7), proc(v: int) = got.add v)
    stopBackground()
    check got == @[7] and backgroundJobs() == 0
    let r = newRig(stack(newLabel(text = "x")))
    runInBackground(proc(): int = 8, proc(v: int) = got.add v)
    r.waitFor(proc(): bool = got.len == 2)
    check got == @[7, 8]

  test "several at once, each delivered once; work with no result":
    let r = newRig(stack(newLabel(text = "x")))
    var got: seq[int]
    var plainDone = false
    for i in 1 .. 4:
      closureScope:                  # each job its own `n` (see background.nim)
        let n = i
        runInBackground(proc(): int = (sleep(50 * n); n * 10), proc(v: int) = got.add v)
    runInBackground(proc() = sleep(20), proc() = plainDone = true)
    r.waitFor(proc(): bool = got.len == 4 and plainDone)
    check got == @[10, 20, 30, 40]
    check plainDone and backgroundJobs() == 0
