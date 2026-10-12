## Per-phase frame timers, for finding where a frame's time goes.
##
## Compiled in only with `-d:ruiPerf`. Without it `perfTime` is just its body and
## `perfCount` is nothing, so an ordinary build carries no timers and pays no
## clock reads. The bookkeeping procs below always compile (and are unit-tested);
## it is the *call sites* in the frame loop that the flag switches on:
##
## ```nim
## perfTime(phLayout):
##   app.refreshLayout()
## ```
##
## A frame is one trip round the main loop. Its phases are disjoint, so they add
## up to (nearly) the loop's whole time:
##
##   events   collecting, coalescing and routing input
##   script   the scripting poll (and the work a command does)
##   poll     theme watch, data-source pollers, due repaint timers
##   layout   layout pass, hit-test rebuild, selector registry
##   texalloc freeing and creating widget render textures
##   render   widgets' own `render` (what they draw)
##   compose  blitting child textures into the parent's
##   screen   the root and overlays to the window, scripting indicator
##   readback the visual probe's framebuffer read (only while probing)
##   swap     endDrawing: buffer swap, input poll, and the frame-rate wait
##   idle     blocked waiting for input or a timer (an idle frame)
##
## plus counters: widgets repainted, textures created.
##
## `perfReport` summarises the recent presented frames as one line (`visual
## perf` in the scripting protocol), the very first presented frame separately,
## because it carries the warm-up (glyph atlas, first textures) that would skew
## every average.

import std/[monotimes, times, algorithm, strutils]

type
  PerfPhase* = enum
    phEvents, phScript, phPoll, phLayout, phTexAlloc, phRender, phCompose,
    phScreen, phReadback, phSwap, phIdle

  PerfCounter* = enum
    pcPainted, pcTextures

  PerfFrame* = object
    ns*: array[PerfPhase, int64]
    count*: array[PerfCounter, int]
    presented*: bool

const
  perfOn* = defined(ruiPerf)
  perfWindow = 600

var
  current: PerfFrame
  recent: seq[PerfFrame]       # presented frames after the first, newest last
  firstFrame: PerfFrame
  haveFirst: bool
  presentedTotal, idleTotal: int

template perfTime*(phase: PerfPhase, body: untyped) =
  ## Run `body`, charging its time to `phase` (when compiled with -d:ruiPerf).
  when perfOn:
    let perfStart = getMonoTime()
    body
    current.ns[phase] += (getMonoTime() - perfStart).inNanoseconds
  else:
    body

template perfCount*(counter: PerfCounter, n = 1) =
  when perfOn:
    current.count[counter] += n

proc perfAdd*(phase: PerfPhase, ns: int64) =
  current.ns[phase] += ns

proc perfEndFrame*(presented: bool) =
  ## Close the current frame's books. Idle frames only count; presented ones are
  ## kept for the report.
  if presented:
    inc presentedTotal
    var f = current
    f.presented = true
    if not haveFirst:
      firstFrame = f
      haveFirst = true
    else:
      recent.add f
      if recent.len > perfWindow: recent.delete(0)
  else:
    inc idleTotal
  current = PerfFrame()

proc perfReset*() =
  current = PerfFrame()
  recent.setLen(0)
  haveFirst = false
  presentedTotal = 0
  idleTotal = 0

proc perfFrames*(): seq[PerfFrame] = recent

func us(ns: int64): int = int(ns div 1000)

proc stats(values: seq[int64]): string =
  ## avg/p95/max, microseconds.
  if values.len == 0: return "0/0/0"
  var v = values
  v.sort()
  var total = 0'i64
  for x in v: total += x
  $us(total div v.len) & "/" & $us(v[min(v.high, v.len * 95 div 100)]) & "/" & $us(v[^1])

proc perfReport*(): string =
  ## One line: counts, then `phase=avg/p95/max` in microseconds over the recent
  ## presented frames, then the counters' average per presented frame, then the
  ## first presented frame's phases on their own.
  if not perfOn:
    return "perf timers are not compiled in: build with -d:ruiPerf"
  var parts = @["presented=" & $presentedTotal, "idle=" & $idleTotal,
                "sampled=" & $recent.len]
  for ph in PerfPhase:
    if ph == phIdle: continue          # idle frames are not in `recent`
    var values: seq[int64]
    for f in recent: values.add f.ns[ph]
    parts.add $ph & "=" & stats(values)
  for c in PerfCounter:
    var total = 0
    for f in recent: total += f.count[c]
    parts.add $c & "/frame=" & (if recent.len > 0: formatFloat(total / recent.len, ffDecimal, 1) else: "0")
  if haveFirst:
    var first: seq[string]
    for ph in PerfPhase:
      if ph != phIdle and firstFrame.ns[ph] > 0: first.add $ph & "=" & $us(firstFrame.ns[ph])
    for c in PerfCounter: first.add $c & "=" & $firstFrame.count[c]
    parts.add "first{" & first.join(" ") & "}"
  parts.join(" ")
