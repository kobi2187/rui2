## Per-phase timers: the bookkeeping (always compiled) and the flag.

import std/[unittest, strutils]
import rui

suite "perf timers":

  setup:
    perfReset()

  test "idle frames only count; presented ones are kept after the first":
    perfEndFrame(false)
    perfAdd(phLayout, 100_000)
    perfEndFrame(true)                  # the first presented frame is held apart
    check perfFrames().len == 0
    perfAdd(phLayout, 2_000_000)
    perfAdd(phRender, 500_000)
    perfEndFrame(true)
    check perfFrames().len == 1
    check perfFrames()[0].ns[phLayout] == 2_000_000
    check perfFrames()[0].ns[phRender] == 500_000

  test "a frame starts empty":
    perfAdd(phEvents, 7)
    perfEndFrame(true)
    perfEndFrame(true)
    check perfFrames()[0].ns[phEvents] == 0

  test "the window keeps the newest frames":
    for i in 0 ..< 700:
      perfAdd(phSwap, int64(i))
      perfEndFrame(true)
    check perfFrames().len == 600
    check perfFrames()[^1].ns[phSwap] == 699

  test "the report matches the build":
    perfAdd(phLayout, 1_000_000); perfEndFrame(true)
    perfAdd(phLayout, 3_000_000); perfEndFrame(true)
    perfAdd(phLayout, 5_000_000); perfEndFrame(true)
    let report = perfReport()
    when perfOn:
      check "presented=3" in report
      check "phLayout=4000/5000/5000" in report     # avg/p95/max of the last two, in us
      check "first{phLayout=1000" in report
    else:
      check "-d:ruiPerf" in report

  test "perfTime is only its body when the flag is off":
    var ran = 0
    perfTime(phRender):
      inc ran
    check ran == 1
    perfEndFrame(true)
    perfEndFrame(true)
    when not perfOn:
      check perfFrames()[0].ns[phRender] == 0
