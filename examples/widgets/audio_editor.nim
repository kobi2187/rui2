## An audio editor's main view, from the editor pieces: a Ruler, a Waveform
## and AxisMarks on one shared view, a playhead that plays, a selection that
## zooms in.
##
## - Drag to select; click to put the playhead; Shift+click extends the
##   selection; drag the flag to move the marker. Edges snap to marks nearby
##   (Alt: off).
## - Ctrl+wheel zooms about the pointer, the wheel pans; the ruler seeks.
## - Space plays from the playhead (round the selection, if there is one).
##
## The file is mapped, not loaded, and summarised in the background, so an
## hour-long recording opens at once.
##
##   nim c -r -d:useGraphics examples/widgets/audio_editor.nim [theme] [file.wav]
##
## Without a file it writes a 30-second stereo sample to the temp directory.

import rui
import std/[os, math, streams]
from raylib import KeyboardKey

let app = newApp("RUI2 - Audio editor", 900, 520)
app.setTheme(if paramCount() >= 1: paramStr(1) else: "forest")

proc samplePath(): string =
  if paramCount() >= 2: return paramStr(2)
  result = getTempDir() / "rui_audio_editor_sample.wav"
  if fileExists(result): return
  const rate = 22050
  let frames = rate * 30
  let s = newFileStream(result, fmWrite)
  s.write "RIFF"; s.write int32(36 + frames * 4); s.write "WAVE"
  s.write "fmt "; s.write int32(16); s.write int16(1); s.write int16(2)
  s.write int32(rate); s.write int32(rate * 4); s.write int16(4); s.write int16(16)
  s.write "data"; s.write int32(frames * 4)
  for i in 0 ..< frames:
    let t = float(i) / rate
    let beat = exp(-((t mod 0.5) * 9))                 # a pulse twice a second
    let swell = 0.5 + 0.5 * sin(t * 2 * PI / 12)      # rising and falling over 12 s
    let l = (sin(t * 110 * 2 * PI) * beat + 0.3 * sin(t * 440 * 2 * PI)) * swell * 0.6
    let r = (sin(t * 165 * 2 * PI) * beat + 0.3 * sin(t * 330 * 2 * PI)) * (1 - swell) * 0.6
    s.write int16(round(clamp(l, -1.0, 1.0) * 32767))
    s.write int16(round(clamp(r, -1.0, 1.0) * 32767))
  s.close()

let song = openWav(samplePath())
let time = newLink(wholeView(0.0, song.seconds, minPerPixel = 1 / song.rate / 16))
let playhead = newLink(0.0)
let selection = newLink(noSpan())
var playing = false

proc clockOf(t: float): string = secondTicks().tickLabel(t, 0.01)

var status: Label
var marks: AxisMarks
var editor: Stack

proc showStatus() =
  let s = selection.value
  status.text = (if playing: "playing  " else: "") & clockOf(playhead.value) &
    (if s.isEmpty: "" else: "   selection " & clockOf(s.lo) & " - " & clockOf(s.hi) &
                            " (" & clockOf(s.hi - s.lo) & ")")

proc zoomToSelection() =
  let s = selection.value
  if not s.isEmpty: time.value = time.value.showing(s.lo, s.hi, marks.bounds.width)

proc togglePlay() =
  playing = not playing
  showStatus()

let root = ui:
  Column(spacing = 8.0, crossAxisAlignment = CrossAxisAlignment.stretch,
         padding = EdgeInsets.all(12.0)):
    Row(spacing = 8.0, crossAxisAlignment = CrossAxisAlignment.center):
      Button(text = "Play / Pause", onClick = togglePlay)
      Button(text = "Zoom to selection", onClick = zoomToSelection)
      Button(text = "Show all", onClick = proc() =
        time.value = wholeView(0.0, song.seconds, minPerPixel = 1 / song.rate / 16))
      status = Label(text = "").named("status")
    Ruler(view = time, ticks = secondTicks(),
          onSeek = proc(at: float) =
            playhead.value = at
            showStatus()).named("ruler")
    Expanded():
      editor = Stack(fit = StackFit.expand).focusable().named("editor"):
        Waveform(source = song, view = time).named("wave")
        marks = AxisMarks(view = time, playhead = playhead, selection = selection,
                          markers = @[marker(12.0, "swell"), marker(24.0, "out")],
                          onSeek = proc(at: float) = showStatus(),
                          onSelect = proc(lo, hi: float) = showStatus()).named("marks")

# Playback moves the playhead at the speed of time (no sound: this is the view).
marks.onTick(proc(dt: float) =
  if not playing: return
  let s = selection.value
  var at = playhead.value + dt
  if not s.isEmpty and at >= s.hi: at = s.lo                 # round the selection
  if at >= song.seconds: (at = song.seconds; playing = false)
  playhead.value = at
  showStatus())

editor.onKey(proc(k: KeyboardKey): bool =
  if k == KeyboardKey.Space:
    togglePlay()
    return true
  false)

showStatus()
app.setRootWidget(root)
app.focusManager.setFocus(editor)
app.start()
