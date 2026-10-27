## Samples -- a long run of numbers to draw as a wave: audio, a sensor, a
## trace. Kept where it already is (in memory, or a WAV file mapped from disk,
## never loaded), and summarised in the background so a view of all of it
## draws at once.
##
## ```nim
## let song = openWav("take3.wav")              # mapped: costs no memory to open
## let probe = newSamples(readings, rate = 1000) # or numbers you have
## ```
##
## - **Frames and channels.** A frame is one sample per channel, at `rate`
##   frames a second; `seconds` is the length. Every widget on a view of a
##   source uses seconds.
## - **Summaries.** Drawing all of a three-hour recording cannot visit every
##   sample each frame. `summarise` (started by the first widget that draws the
##   source) builds, on the background thread, the smallest and largest value
##   of every 256 frames, of every 512, and so on up. A view picks the level
##   that matches its zoom; until the summaries are in it draws from a sample
##   of the samples.
## - The samples must not change while they are summarised (they are read from
##   the background thread).

import std/[memfiles, math, json]
import rui_core

type
  SampleFormat* = enum sfFloat32, sfInt16, sfInt32

  MinMax* = tuple[lo, hi: float32]

  Peaks* = seq[seq[MinMax]]
    ## Per level: level 0 summarises `BaseBucket` frames a value, each level up
    ## twice as many.

  SampleSource* = ref object
    rate*: float                 ## frames a second
    channels*: int
    frames*: int                 ## samples per channel
    format: SampleFormat
    data: pointer                ## interleaved samples
    kept: seq[float32]           ## the samples, when given in memory
    file: MemFile
    mapped: bool
    peaks*: seq[Peaks]           ## per channel, once summarised
    summarising: bool
    listeners: seq[proc() {.closure.}]
    waiting: seq[Widget]         ## to redraw when the summaries are in

const BaseBucket* = 256

proc seconds*(s: SampleSource): float =
  if s.rate > 0: float(s.frames) / s.rate else: 0

proc summarised*(s: SampleSource): bool = s.peaks.len == s.channels and s.channels > 0

proc read(data: pointer, format: SampleFormat, channels, ch, i: int): float32 {.inline.} =
  ## Sample `i` of channel `ch`, as -1 .. 1. Plain values only: safe on any thread.
  let k = i * channels + ch
  case format
  of sfFloat32: cast[ptr UncheckedArray[float32]](data)[k]
  of sfInt16: float32(cast[ptr UncheckedArray[int16]](data)[k]) / 32768
  of sfInt32: float32(float(cast[ptr UncheckedArray[int32]](data)[k]) / 2147483648.0)

proc `%`*(s: SampleSource): JsonNode =
  ## What scripting and the inspector see of a source: its shape, not its samples.
  if s == nil: newJNull()
  else: %*{"rate": s.rate, "channels": s.channels, "frames": s.frames}

proc sample*(s: SampleSource, ch, i: int): float32 =
  ## Sample `i` of channel `ch` (0 past either end).
  if i < 0 or i >= s.frames or ch < 0 or ch >= s.channels: return 0
  read(s.data, s.format, s.channels, ch, i)

proc newSamples*(samples: seq[float32], rate: float, channels = 1): SampleSource =
  ## Samples you have, interleaved by channel (L R L R ... for stereo).
  result = SampleSource(rate: rate, channels: max(1, channels), format: sfFloat32,
                        kept: samples)
  result.frames = samples.len div result.channels
  if samples.len > 0: result.data = addr result.kept[0]

proc le16(p: ptr UncheckedArray[uint8], at: int): int =
  int(p[at]) or (int(p[at + 1]) shl 8)

proc le32(p: ptr UncheckedArray[uint8], at: int): int =
  le16(p, at) or (le16(p, at + 2) shl 16)

proc openWav*(path: string): SampleSource =
  ## A WAV file (16- or 32-bit PCM, or 32-bit float), mapped from disk: only
  ## the parts drawn are ever read. Raises IOError for anything else.
  var f = memfiles.open(path)
  let p = cast[ptr UncheckedArray[uint8]](f.mem)
  proc tag(at: int): string =
    result = newString(4)
    for i in 0 ..< 4: result[i] = char(p[at + i])
  if f.size < 12 or tag(0) != "RIFF" or tag(8) != "WAVE":
    f.close()
    raise newException(IOError, path & ": not a WAV file")
  var at = 12
  var fmt, channels, rate, bits = 0
  var dataAt, dataSize = -1
  while at + 8 <= f.size:
    let id = tag(at)
    let size = le32(p, at + 4)
    if id == "fmt ":
      fmt = le16(p, at + 8)
      channels = le16(p, at + 10)
      rate = le32(p, at + 12)
      bits = le16(p, at + 22)
      if fmt == 0xFFFE and size >= 40: fmt = le16(p, at + 32)   # extensible: the real format
    elif id == "data":
      dataAt = at + 8
      dataSize = min(size, f.size - dataAt)
      break
    at += 8 + size + (size and 1)
  var format: SampleFormat
  if fmt == 3 and bits == 32: format = sfFloat32
  elif fmt == 1 and bits == 16: format = sfInt16
  elif fmt == 1 and bits == 32: format = sfInt32
  else:
    f.close()
    raise newException(IOError, path & ": unsupported WAV format")
  if dataAt < 0 or channels <= 0:
    f.close()
    raise newException(IOError, path & ": no samples")
  let bytes = if format == sfInt16: 2 else: 4
  result = SampleSource(rate: float(rate), channels: channels, format: format,
                        file: f, mapped: true,
                        data: cast[pointer](cast[int](f.mem) + dataAt))
  result.frames = dataSize div (bytes * channels)

proc close*(s: SampleSource) =
  ## Unmap a file. Nothing may draw the source after this.
  if s.mapped:
    s.file.close()
    s.mapped = false
    s.data = nil
    s.frames = 0

proc buildPeaks(data: pointer, format: SampleFormat, channels, frames, ch: int): Peaks =
  ## Level 0 from the samples, each level above from the one below it.
  var level: seq[MinMax]
  var i = 0
  while i < frames:
    var lo = Inf.float32
    var hi = -Inf.float32
    for k in i ..< min(frames, i + BaseBucket):
      let v = read(data, format, channels, ch, k)
      lo = min(lo, v)
      hi = max(hi, v)
    level.add (lo, hi)
    i += BaseBucket
  result.add level
  while result[^1].len > 1:
    let below = result[^1]
    var up = newSeq[MinMax]((below.len + 1) div 2)
    for j in 0 ..< up.len:
      let a = below[2 * j]
      let b = if 2 * j + 1 < below.len: below[2 * j + 1] else: a
      up[j] = (min(a.lo, b.lo), max(a.hi, b.hi))
    result.add up

proc onSummarised*(s: SampleSource, call: proc() {.closure.}) =
  ## `call` once the summaries are in (at once, if they are).
  if s.summarised: call() else: s.listeners.add call

proc summarise*(s: SampleSource) =
  ## Start building the summaries on the background thread (once).
  if s.summarised or s.summarising or s.frames == 0: return
  s.summarising = true
  let (data, format, channels, frames) = (s.data, s.format, s.channels, s.frames)
  let work = proc(): seq[Peaks] {.gcsafe.} =
    for ch in 0 ..< channels: result.add buildPeaks(data, format, channels, frames, ch)
  let done = proc(peaks: seq[Peaks]) =
    s.peaks = peaks
    s.summarising = false
    for call in s.listeners: call()
    s.listeners.setLen(0)
    for w in s.waiting:
      w.isDirty = true
      w.markDirtyToRoot()
    s.waiting.setLen(0)
  runInBackground(work, done)

proc drawnBy*(s: SampleSource, w: Widget) =
  ## `w` draws `s`: summarise it if that has not begun, and redraw `w` when
  ## the summaries are in. Cheap to call on every draw.
  if s == nil or s.summarised: return
  if w notin s.waiting: s.waiting.add w
  s.summarise()

proc span*(s: SampleSource, ch, first, last: int): MinMax =
  ## The smallest and largest sample of channel `ch` in frames `first ..< last`:
  ## from the summaries when the stretch is long, from the samples when it is
  ## short, and from a sample of them while the summaries are being built.
  let a = max(0, first)
  let b = min(s.frames, last)
  if b <= a: return (0'f32, 0'f32)
  let n = b - a
  if n >= 2 * BaseBucket and s.summarised:
    let peaks = s.peaks[ch]
    var level = 0
    while level + 1 < peaks.len and BaseBucket shl (level + 1) <= n div 2: inc level
    let size = BaseBucket shl level
    result = (Inf.float32, -Inf.float32)
    for j in (a div size) .. min(peaks[level].high, (b - 1) div size):
      result.lo = min(result.lo, peaks[level][j].lo)
      result.hi = max(result.hi, peaks[level][j].hi)
    return
  let stride = if n > 4 * BaseBucket and not s.summarised: n div (2 * BaseBucket) else: 1
  result = (Inf.float32, -Inf.float32)
  var i = a
  while i < b:
    let v = read(s.data, s.format, s.channels, ch, i)
    result.lo = min(result.lo, v)
    result.hi = max(result.hi, v)
    i += stride
