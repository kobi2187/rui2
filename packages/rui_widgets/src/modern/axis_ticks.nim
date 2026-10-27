## Where the marks go on an axis, and what they say: plain numbers, seconds,
## timecode, samples, or bars and beats. Pure, so every rule can be checked
## against a table; the Ruler draws what this returns.
##
## The axis is in seconds for every format but `tkPlain` (the unit of a
## waveform, a video track, a song): a format only changes the labels and
## which steps are "round" -- frames for timecode, beats for music.

import std/[math, strutils]
import ../view_range
import plot_scale

type
  TickKind* = enum
    tkPlain       ## numbers: 0, 50, 100
    tkSeconds     ## 0:05, 1:30, 1:02:00, and 0:01.250 when close
    tkTimecode    ## hh:mm:ss:ff, steps of whole frames
    tkSamples     ## sample numbers at `rate`
    tkBeats       ## bar.beat at `bpm`, steps of beats and bars

  TickFormat* = object
    kind*: TickKind
    fps*: float           ## timecode frames a second
    rate*: float          ## samples a second
    bpm*: float           ## beats a minute
    beatsPerBar*: int

  Tick* = object
    at*: float            ## data
    x*: float32           ## screen
    major*: bool          ## labelled and long
    label*: string

proc plainTicks*(): TickFormat = TickFormat(kind: tkPlain)
proc secondTicks*(): TickFormat = TickFormat(kind: tkSeconds)
proc timecodeTicks*(fps = 30.0): TickFormat = TickFormat(kind: tkTimecode, fps: fps)
proc sampleTicks*(rate = 44100.0): TickFormat = TickFormat(kind: tkSamples, rate: rate)
proc beatTicks*(bpm = 120.0, beatsPerBar = 4): TickFormat =
  TickFormat(kind: tkBeats, bpm: bpm, beatsPerBar: beatsPerBar)

const TimeSteps = [1.0, 2, 5, 10, 15, 30, 60, 120, 300, 600, 900, 1800,
                   3600, 7200, 3 * 3600, 6 * 3600, 12 * 3600, 86400]
  ## Round steps of time, from a second up to a day.

proc roundUp(want: float): float =
  ## The smallest 1, 2 or 5 times a power of ten that is at least `want`.
  result = niceStep(want, 1)
  while result < want * (1 - 1e-12): result = niceStep(result * 2.01, 1)

proc pickStep*(f: TickFormat, want: float): float =
  ## The smallest round step for this format of at least `want` data units.
  if want <= 0: return 1
  case f.kind
  of tkPlain: roundUp(want)
  of tkSamples: max(1.0, roundUp(want * f.rate)) / f.rate
  of tkSeconds, tkTimecode:
    let frame = if f.kind == tkTimecode: 1 / max(1.0, f.fps) else: 0.0
    if want < 1:
      if frame > 0:                  # whole frames: 1, 2, 5, 10 ... of them
        for n in [1.0, 2, 5, 10, 15]:
          if n * frame >= want: return n * frame
        return 1.0
      return min(roundUp(want), 1.0)
    for s in TimeSteps:
      if s >= want: return s
    ceil(want / 86400) * 86400
  of tkBeats:
    let beat = 60 / max(1.0, f.bpm)
    let bar = beat * float(max(1, f.beatsPerBar))
    for s in [beat / 4, beat / 2, beat, bar, 2 * bar, 4 * bar, 8 * bar, 16 * bar, 32 * bar]:
      if s >= want: return s
    ceil(want / (64 * bar)) * 64 * bar

proc clock(seconds: float, decimals: int): string =
  ## m:ss, h:mm:ss, with `decimals` after the seconds.
  let neg = seconds < 0
  let total = abs(seconds)
  let whole = int64(floor(total + 1e-9))
  let h = whole div 3600
  let m = (whole div 60) mod 60
  let sec = whole mod 60
  result = if neg: "-" else: ""
  result.add(if h > 0: $h & ":" & align($m, 2, '0') else: $m)
  result.add ":" & align($sec, 2, '0')
  if decimals > 0:
    let frac = total - float(whole)
    result.add "." & align($int64(round(frac * pow(10.0, float(decimals)))), decimals, '0')

proc tickLabel*(f: TickFormat, at, step: float): string =
  ## What the mark at `at` says, with the detail the step needs.
  case f.kind
  of tkPlain: formatTick(at, step)
  of tkSamples: $int64(round(at * f.rate))
  of tkSeconds:
    var decimals = 0                 # as many as the step needs to be exact: .25, .5
    while decimals < 3 and abs(step * pow(10.0, float(decimals)) -
                               round(step * pow(10.0, float(decimals)))) > 1e-6:
      inc decimals
    clock(at, decimals)
  of tkTimecode:
    let fps = max(1.0, f.fps)
    let frames = int64(round(abs(at) * fps))
    let perSecond = int64(round(fps))
    let secs = frames div perSecond
    (if at < 0: "-" else: "") &
      align($(secs div 3600), 2, '0') & ":" & align($((secs div 60) mod 60), 2, '0') & ":" &
      align($(secs mod 60), 2, '0') & ":" & align($(frames mod perSecond), 2, '0')
  of tkBeats:
    let beat = 60 / max(1.0, f.bpm)
    let beats = int64(floor(at / beat + 1e-6))
    let per = max(1, f.beatsPerBar)
    let bar = beats div per + 1
    let inBar = beats mod per + 1
    if step >= beat * float(per): $bar else: $bar & "." & $inBar

proc axisTicks*(f: TickFormat, v: AxisView, left, width: float32,
                labelPx = 80'f32): seq[Tick] =
  ## The marks across a view `width` pixels wide at `left`: a labelled one
  ## about every `labelPx` pixels, on a round step, and unlabelled ones between.
  let v = v.clampedTo(width)
  if width <= 0 or v.perPixel <= 0: return
  let step = f.pickStep(float(labelPx) * v.perPixel)
  # Minor marks: a fifth of the step (a beat, a frame where that is rounder).
  var minor = step / 5
  if f.kind == tkBeats:
    let beat = 60 / max(1.0, f.bpm)
    minor = if step > beat: beat else: step / 2
  elif f.kind in {tkSeconds, tkTimecode} and step >= 60:
    minor = step / (if step mod 300 == 0: 5 else: 6)
  if minor * 1 / v.perPixel < 6: minor = step     # too dense to see: majors only
  let a = v.start
  let b = v.stop(width)
  var k = floor(a / minor)
  while k * minor <= b + minor * 1e-6:
    let at = k * minor
    if at >= a - minor * 1e-6:
      let major = abs(at / step - round(at / step)) < 1e-6
      result.add Tick(at: at, x: v.toPixel(at, left), major: major,
                      label: if major: f.tickLabel(at, step) else: "")
    k += 1
