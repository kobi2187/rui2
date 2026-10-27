## Samples drawn as a wave (sources/samples.nim, modern/wave_draw.nim,
## modern/waveform.nim, Plot's wave series): summaries that agree with the
## samples, WAV files read in place, summarising off the UI thread, and the
## widgets on a shared view.

import std/[unittest, math, os, streams, monotimes, times]
import rui
import ui_harness

proc sine(n: int, rate = 8000.0): seq[float32] =
  for i in 0 ..< n: result.add float32(sin(float(i) * 440 * 2 * PI / rate) * (float(i mod 10000) / 10000))

proc writeWav(path: string, channels, bits, fmt: int, frames: seq[seq[float]], rate = 8000) =
  let s = newFileStream(path, fmWrite)
  let bytes = bits div 8
  let data = frames.len * channels * bytes
  s.write "RIFF"; s.write int32(36 + data); s.write "WAVE"
  s.write "fmt "; s.write int32(16); s.write int16(fmt); s.write int16(channels)
  s.write int32(rate); s.write int32(rate * channels * bytes); s.write int16(channels * bytes)
  s.write int16(bits)
  s.write "data"; s.write int32(data)
  for f in frames:
    for c in 0 ..< channels:
      if bits == 16: s.write int16(round(f[c] * 32767))
      else: s.write float32(f[c])
  s.close()

proc settle(r: Rig, done: proc(): bool) =
  let until = getMonoTime() + initDuration(seconds = 5)
  while not done() and getMonoTime() < until:
    r.frame(1)
    sleep(5)

suite "samples and their summaries":
  test "the summaries agree with the samples, at every level":
    let data = sine(300_000)
    let s = newSamples(data, 8000)
    s.summarise()
    let r = newRig(stack(newLabel(text = "")))
    r.settle(proc(): bool = s.summarised)
    check s.summarised
    for (a, b) in [(0, 4096), (25_600, 76_800), (1024, 299_008)]:
      var lo = Inf.float32
      var hi = -Inf.float32
      for i in a ..< b:
        lo = min(lo, data[i]); hi = max(hi, data[i])
      let got = s.span(0, a, b)
      check got.lo == lo and got.hi == hi
    disposeTree(r.root)

  test "a short stretch is read from the samples themselves":
    let s = newSamples(@[0.1'f32, -0.5, 0.7, 0.2], 1000)
    check s.span(0, 1, 3) == (-0.5'f32, 0.7'f32)
    check s.seconds == 0.004
    check s.sample(0, 2) == 0.7'f32 and s.sample(0, 9) == 0

  test "WAV files are read in place: 16-bit stereo, 32-bit float; others refused":
    let dir = getTempDir()
    writeWav(dir / "st.wav", 2, 16, 1, @[@[0.5, -0.25], @[-1.0, 1.0], @[0.0, 0.125]])
    let st = openWav(dir / "st.wav")
    check st.channels == 2 and st.frames == 3 and st.rate == 8000
    check abs(st.sample(0, 0) - 0.5) < 1e-3 and abs(st.sample(1, 0) + 0.25) < 1e-3
    check abs(st.sample(1, 2) - 0.125) < 1e-3
    st.close()
    writeWav(dir / "fl.wav", 1, 32, 3, @[@[0.75], @[-0.5]])
    let fl = openWav(dir / "fl.wav")
    check fl.frames == 2 and fl.sample(0, 0) == 0.75'f32
    fl.close()
    writeFile(dir / "no.wav", "not a wave at all")
    expect IOError: discard openWav(dir / "no.wav")

suite "the Waveform and Plot's wave series":
  test "a Waveform summarises its source off the UI thread and redraws when it is done":
    let s = newSamples(sine(200_000), 8000)
    let w = newWaveform(source = s)
    let r = newRig(stack(w.frame(width = 400, height = 100)), 400, 120)
    check w.view != nil and w.view.value.hi == s.seconds
    r.settle(proc(): bool = s.summarised)
    check s.summarised
    let before = w.view.value
    check w.handleInput(GuiEvent(kind: evMouseWheel, wheelDelta: 1, mods: {kmCtrl},
                                 mousePos: Point(x: w.bounds.x + 100, y: w.bounds.y + 50)))
    check w.view.value.clampedTo(400).perPixel < before.clampedTo(400).perPixel
    disposeTree(r.root)

  test "Plot draws samples as a series; x is seconds and zooms with xView":
    let s = newSamples(sine(80_000), 8000)
    let series = @[waveSeries("take", s)]
    let view = newLink(xViewOf(series))
    let p = newPlot(series = series, xView = view)
    p.bounds = Rect(x: 0, y: 0, width: 400, height: 200)
    check p.plotFrame.l.xLo == 0 and abs(p.plotFrame.l.xHi - 10) < 1e-9
    check p.plotFrame.l.yLo <= -1 and p.plotFrame.l.yHi >= 1
    view.value = view.value.showing(2, 2.01, p.plotFrame.area.width)
    check abs(p.plotFrame.l.xHi - p.plotFrame.l.xLo - 0.01) < 1e-9
