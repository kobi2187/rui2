## Slow work off the UI thread (background.nim): the frames keep coming while
## it runs, its result reaches `done` on the UI thread, a failure reaches
## `failed`, and several can run at once.

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
