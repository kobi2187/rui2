## What the screen actually showed, and how fast it got there.
##
## The `read` verb answers "what does the widget say?"; this answers "did the
## pane really repaint, and how long did that take?". It is for tests of
## rendering behaviour -- a value that updates but never reaches the screen, a
## text field that lags behind typing -- and, like `inspect`, belongs to a build
## with `-d:ruiInspect`.
##
## The probe keeps the last frame the app *presented* (read back from the
## framebuffer just before the swap, so it is exactly what a user could see) and
## answers from it:
##
##   visual clock                 ms since start, presented frame count
##   visual frames                step / present timings over the last frames
##   visual perf [reset]          per-phase timers (-d:ruiPerf builds only)
##   visual hash [fresh]          hash and mean colour of the selector's rectangle
##   visual shot [file] [fresh]   that rectangle as a PNG
##   visual arm                   remember the rectangle's pixels now
##   visual change [timeoutMs]    wait until they differ; report how long it took
##   visual stable [quietMs [timeoutMs]]  wait until they stop changing
##
## `*` or `window` selects the whole window. `fresh` waits for the next
## presented frame instead of using the last one.
##
## Timing is measured inside the app, from the monotonic clock, so file-polling
## jitter on the client's side is not in the numbers: `arm`, `write x`, `change`
## in one command file runs back to back within a frame, and `change` reports the
## time from the arm to the moment the changed frame was read back.

import std/[monotimes, times, options, strutils, os, algorithm, tables]
import raylib
import script_manager
import rui_core

type
  FrameStat = object
    stepUs, presentUs: int
    painted: bool

  Shot* = object
    width*, height*: int
    pixels*: seq[byte]         # RGBA, top row first

  Arm = object
    hash: uint64
    at: MonoTime
    framesAtArm: int
    changedAt: Option[MonoTime]
    changedFrame: int
    changedHash: uint64

  Watcher = object
    hash: uint64
    lastChange: MonoTime

  RectOf* = proc(selector: string): Option[tuple[x, y, w, h: int]] {.closure.}

  VisualProbe* = ref object
    start: MonoTime
    enabled*: bool             ## capture every presented frame (set by the first visual command)
    wantPresent*: bool         ## ask the app for a frame so there is something to read
    frames: seq[FrameStat]
    presented*: int
    shot: Shot
    haveShot: bool
    shotNumber: int
    arms: Table[string, Arm]
    watchers: Table[string, Watcher]
    shotDir: string
    rectOf*: RectOf
    resizeTo*: proc(width, height: int) {.closure.}

const frameWindow = 600

proc newVisualProbe*(shotDir: string): VisualProbe =
  VisualProbe(start: getMonoTime(), shotDir: shotDir)

proc ms(probe: VisualProbe, at: MonoTime): float =
  float((at - probe.start).inMicroseconds) / 1000.0

proc ms3(x: float): string = formatFloat(x, ffDecimal, 3)

# ---------------------------------------------------------------------------
# pixels

func fnv(h: uint64, b: byte): uint64 = (h xor b.uint64) * 1099511628211'u64

proc regionStats*(s: Shot, x, y, w, h: int): tuple[hash: uint64, mean: array[4, int]] =
  ## FNV-1a over the rectangle's RGBA bytes (clamped to the shot), and the mean
  ## of each channel.
  var hash = 14695981039346656037'u64
  var sum: array[4, int]
  let x0 = max(0, x)
  let y0 = max(0, y)
  let x1 = min(s.width, x + w)
  let y1 = min(s.height, y + h)
  for row in y0 ..< y1:
    var i = (row * s.width + x0) * 4
    for col in x0 ..< x1:
      for c in 0 ..< 4:
        let b = s.pixels[i + c]
        hash = fnv(hash, b)
        sum[c] += b.int
      i += 4
  let n = max(1, (x1 - x0) * (y1 - y0))
  (hash, [sum[0] div n, sum[1] div n, sum[2] div n, sum[3] div n])

proc hex*(h: uint64): string = toHex(h.BiggestUInt, 16).toLowerAscii

proc capture*(probe: VisualProbe) =
  ## Read the framebuffer; call between drawing and `endDrawing`, so it is the
  ## frame about to be presented. Resolves anything waiting on a change.
  let now = getMonoTime()       # the frame is composited: the read-back below is not latency
  let image = loadImageFromScreen()
  if image.data == nil or image.width <= 0: return
  let n = image.width.int * image.height.int * 4
  probe.shot.width = image.width
  probe.shot.height = image.height
  probe.shot.pixels.setLen(n)
  copyMem(addr probe.shot.pixels[0], image.data, n)
  probe.haveShot = true
  probe.wantPresent = false
  for sel, arm in probe.arms.mpairs:
    if arm.changedAt.isNone:
      let r = probe.rectOf(sel)
      if r.isSome:
        let stats = probe.shot.regionStats(r.get.x, r.get.y, r.get.w, r.get.h)
        if stats.hash != arm.hash:
          arm.changedAt = some(now)
          arm.changedFrame = probe.presented + 1
          arm.changedHash = stats.hash
  for sel, watcher in probe.watchers.mpairs:
    let r = probe.rectOf(sel)
    if r.isSome:
      let stats = probe.shot.regionStats(r.get.x, r.get.y, r.get.w, r.get.h)
      if stats.hash != watcher.hash:
        watcher.hash = stats.hash
        watcher.lastChange = now

proc notePresented*(probe: VisualProbe, stepUs, presentUs: int, painted: bool) =
  inc probe.presented
  probe.frames.add FrameStat(stepUs: stepUs, presentUs: presentUs, painted: painted)
  if probe.frames.len > frameWindow:
    probe.frames.delete(0)

# ---------------------------------------------------------------------------
# answers

proc fail(message: string): VisualReply = VisualReply(ok: false, value: message)
proc ok(value: string): VisualReply = VisualReply(ok: true, value: value)

proc stats(values: seq[int]): string =
  if values.len == 0: return "avg=0 p95=0 max=0"
  var v = values
  v.sort()
  var total = 0
  for x in v: total += x
  "avg=" & $(total div v.len) & " p95=" & $v[min(v.high, v.len * 95 div 100)] &
    " max=" & $v[^1]

proc framesReply(probe: VisualProbe): VisualReply =
  var steps, presents: seq[int]
  var painted = 0
  for f in probe.frames:
    steps.add f.stepUs
    presents.add f.presentUs
    if f.painted: inc painted
  ok("n=" & $probe.frames.len & " painted=" & $painted &
     " stepUs{" & stats(steps) & "} presentUs{" & stats(presents) & "}")

proc rectText(r: tuple[x, y, w, h: int]): string =
  $r.x & "," & $r.y & "," & $r.w & "," & $r.h

proc cropPng(s: Shot, r: tuple[x, y, w, h: int], path: string): bool =
  let x0 = max(0, r.x)
  let y0 = max(0, r.y)
  let w = min(s.width, r.x + r.w) - x0
  let h = min(s.height, r.y + r.h) - y0
  if w <= 0 or h <= 0: return false
  var buf = newSeq[byte](w * h * 4)
  for row in 0 ..< h:
    copyMem(addr buf[row * w * 4], unsafeAddr s.pixels[((y0 + row) * s.width + x0) * 4], w * 4)
  var image = toWeakImage(buf, w.int32, h.int32, PixelFormat.UncompressedR8g8b8a8)
  createDir(parentDir(path))
  exportImage(Image(image), path)

proc pixelsReply(probe: VisualProbe, selector: string, saveTo: string,
                 wantFile: bool): VisualReply =
  let r = probe.rectOf(selector)
  if r.isNone: return fail("Widget not found: " & selector)
  let stats = probe.shot.regionStats(r.get.x, r.get.y, r.get.w, r.get.h)
  var text = "hash=" & hex(stats.hash) & " mean=" & stats.mean.join(",") &
             " rect=" & rectText(r.get) & " frame=" & $probe.presented
  if wantFile:
    var path = saveTo
    if path.len == 0:
      inc probe.shotNumber
      path = "shot" & align($probe.shotNumber, 3, '0') & ".png"
    if not path.isAbsolute: path = probe.shotDir / path
    if not probe.shot.cropPng(r.get, path): return fail("Nothing to save for " & selector)
    text = "file=" & path & " " & text
  ok(text)

proc waitForShot(probe: VisualProbe, fresh: bool, then: proc(): VisualReply {.closure.}): VisualReply =
  ## Run `then` once a frame has been read back: now if there is one (and
  ## `fresh` was not asked for), else after the next presented frame.
  probe.enabled = true
  var target = probe.presented + (if fresh or not probe.haveShot: 1 else: 0)
  if probe.haveShot and not fresh: return then()
  probe.wantPresent = true
  VisualReply(wait: proc(): Option[VisualReply] =
    if probe.presented >= target and probe.haveShot: some(then())
    else:
      probe.wantPresent = true
      none(VisualReply))

proc intArg(parts: seq[string], i: int, default: int): int =
  if i < parts.len:
    try: return parseInt(parts[i]) except ValueError: discard
  default

proc answer*(probe: VisualProbe, selector, what: string): VisualReply =
  ## One `visual` command. `selector` is a widget id, or `*` / `window`.
  let parts = what.splitWhitespace()
  if parts.len == 0: return fail("visual: what?")
  let sel = if selector == "window": "*" else: selector
  let fresh = "fresh" in parts
  case parts[0]
  of "clock":
    ok("ms=" & ms3(probe.ms(getMonoTime())) & " frame=" & $probe.presented)
  of "frames":
    probe.framesReply()
  of "resize":
    if parts.len < 3 or probe.resizeTo == nil: return fail("visual resize W H")
    probe.resizeTo(intArg(parts, 1, 800), intArg(parts, 2, 600))
    probe.wantPresent = true
    ok("resized")
  of "perf":
    # Per-phase timers; only present in a build with -d:ruiPerf.
    if parts.len > 1 and parts[1] == "reset":
      perfReset()
      ok("perf reset")
    else:
      let report = perfReport()
      if perfOn: ok(report) else: fail(report)
  of "hash":
    waitForShot(probe, fresh, proc(): VisualReply = probe.pixelsReply(sel, "", false))
  of "shot":
    let file = if parts.len > 1 and parts[1] != "fresh": parts[1] else: ""
    waitForShot(probe, fresh, proc(): VisualReply = probe.pixelsReply(sel, file, true))
  of "arm":
    waitForShot(probe, false, proc(): VisualReply =
      let r = probe.rectOf(sel)
      if r.isNone: return fail("Widget not found: " & selector)
      let stats = probe.shot.regionStats(r.get.x, r.get.y, r.get.w, r.get.h)
      probe.arms[sel] = Arm(hash: stats.hash, at: getMonoTime(), framesAtArm: probe.presented)
      ok("armed hash=" & hex(stats.hash) & " frame=" & $probe.presented))
  of "change":
    if sel notin probe.arms: return fail("visual change: arm " & selector & " first")
    let timeout = intArg(parts, 1, 1000)
    let deadline = getMonoTime() + initDuration(milliseconds = timeout)
    probe.wantPresent = false
    VisualReply(wait: proc(): Option[VisualReply] =
      let arm = probe.arms.getOrDefault(sel)
      if arm.changedAt.isSome:
        some(ok("ms=" & ms3(float((arm.changedAt.get - arm.at).inMicroseconds) / 1000.0) &
                " frames=" & $(arm.changedFrame - arm.framesAtArm) &
                " hash=" & hex(arm.changedHash)))
      elif getMonoTime() > deadline:
        some(fail("no visual change in " & $timeout & "ms (" & selector & ")"))
      else: none(VisualReply))
  of "stable":
    let quiet = intArg(parts, 1, 200)
    let timeout = intArg(parts, 2, 2000)
    waitForShot(probe, false, proc(): VisualReply =
      let r = probe.rectOf(sel)
      if r.isNone: return fail("Widget not found: " & selector)
      let stats = probe.shot.regionStats(r.get.x, r.get.y, r.get.w, r.get.h)
      let began = getMonoTime()
      probe.watchers[sel] = Watcher(hash: stats.hash, lastChange: began)
      let deadline = began + initDuration(milliseconds = timeout)
      VisualReply(wait: proc(): Option[VisualReply] =
        let w = probe.watchers[sel]
        let now = getMonoTime()
        if now - w.lastChange >= initDuration(milliseconds = quiet):
          probe.watchers.del(sel)
          some(ok("stable ms=" & ms3(float((now - began).inMicroseconds) / 1000.0) &
                  " hash=" & hex(w.hash)))
        elif now > deadline:
          probe.watchers.del(sel)
          some(fail("still changing after " & $timeout & "ms (" & selector & ")"))
        else: none(VisualReply)))
  else:
    fail("visual: unknown '" & parts[0] & "'")
