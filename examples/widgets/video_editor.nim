## A video editor's layout, from the editor pieces and ordinary widgets:
## panes with movable dividers (SplitView), a preview, a bin of clips, and a
## timeline of lanes under a timecode Ruler, all on one shared view.
##
## - Drag a clip to move it (to another lane too), drag its edges to trim;
##   edges snap to other clips and the playhead (Alt: off).
## - Click the ruler or empty lane space to put the playhead; Ctrl+wheel over
##   the lanes zooms.
## - Split cuts the selected clip at the playhead; Delete removes it.
## - Space plays (the preview shows the clip under the playhead).
##
##   nim c -r -d:useGraphics examples/widgets/video_editor.nim [theme]

import rui
import std/[math, options, strutils, os]
from raylib import KeyboardKey

let app = newApp("RUI2 - Video editor", 1000, 640)
app.setTheme(if paramCount() >= 1: paramStr(1) else: "forest")

const fps = 25.0
const HeaderWidth = 150'f32

# Twenty seconds of a tune, to show an audio clip's wave inside it.
var tune: seq[float32]
for i in 0 ..< 8000 * 20:
  let t = float(i) / 8000
  tune.add float32(sin(t * 196 * 2 * PI) * 0.5 * (0.6 + 0.4 * sin(t * 2 * PI / 4)) *
                   exp(-((t mod 1.0) * 3)))
let music = newSamples(tune, 8000)

let time = newLink(wholeView(0.0, 40.0, minPerPixel = 1 / fps / 20))
let playhead = newLink(3.0)
let marks = newMarks(playhead = playhead)    # clicking empty lane space seeks too
var playing = false

proc tint(r, g, b: int): Option[Color] = some(Color(r: uint8(r), g: uint8(g), b: uint8(b), a: 255))

var lanes: Lanes
var preview: Label
var bin: ListBox
var status: Label

proc header(name, toggle: string, on: bool): Widget =
  ## A lane's header: its name and a switch.
  result = ui:
    Row(spacing = 4.0, crossAxisAlignment = CrossAxisAlignment.center):
      Label(text = name)
      Checkbox(text = toggle, initialChecked = on)

proc clipAt(at: float): int =
  ## The clip shown at `at`: the topmost video lane's, else -1.
  result = -1
  var lane = high(int)
  for i, c in lanes.clips:
    if c.lane <= 1 and at >= c.start and at < c.start + c.length and c.lane < lane:
      result = i
      lane = c.lane

proc refresh() =
  let i = clipAt(playhead.value)
  let tc = timecodeTicks(fps).tickLabel(playhead.value, 1 / fps)
  preview.text = (if i >= 0: lanes.clips[i].label else: "(black)") & "\n" & tc
  var names: seq[string]
  for c in lanes.clips: names.add c.label & "  " & formatFloat(c.length, ffDecimal, 1) & " s"
  bin.items = names
  status.text = (if playing: "playing  " else: "") & tc &
                (if lanes.selected >= 0: "   selected: " & lanes.clips[lanes.selected].label else: "")

proc splitAtPlayhead() =
  let i = lanes.selected
  if i < 0: return
  let c = lanes.clips[i]
  let at = playhead.value
  if at <= c.start or at >= c.start + c.length: return
  var first = c
  first.length = at - c.start
  var second = c
  second.id = c.id & "'"
  second.start = at
  second.length = c.start + c.length - at
  second.waveOffset = c.waveOffset + first.length
  var next = lanes.clips
  next[i] = first
  next.insert(second, i + 1)
  lanes.clips = next                  # the setter redraws
  refresh()

proc deleteClip(i: int) =
  if i < 0 or i >= lanes.clips.len: return
  var next = lanes.clips
  next.delete(i)
  lanes.clips = next
  refresh()

let root = ui:
  Column(spacing = 8.0, crossAxisAlignment = CrossAxisAlignment.stretch,
         padding = EdgeInsets.all(10.0)):
    Row(spacing = 8.0, crossAxisAlignment = CrossAxisAlignment.center):
      Button(text = "Play / Pause", onClick = proc() = (playing = not playing; refresh()))
      Button(text = "Split at playhead", onClick = splitAtPlayhead)
      Button(text = "Delete", onClick = proc() = deleteClip(lanes.selected))
      status = Label(text = "").named("status")
    Expanded():
      SplitView(axis = Axis.vertical, initialRatio = 0.5).named("main"):
        SplitView(initialRatio = 0.68).named("top"):
          Panel(padding = 12.0):
            preview = Label(text = "", fontSize = 24.0, wrap = true,
                            align = TextAlign.Center).named("preview")
          Column(spacing = 4.0, crossAxisAlignment = CrossAxisAlignment.stretch):
            Label(text = "Bin")
            Expanded():
              bin = ListBox(items = @[]).named("bin")
        Column(spacing = 2.0, crossAxisAlignment = CrossAxisAlignment.stretch):
          Row():
            SizedBox(width = HeaderWidth)
            Expanded():
              Ruler(view = time, ticks = timecodeTicks(fps),
                    onSeek = proc(at: float) = (playhead.value = at; refresh())).named("ruler")
          Expanded():
            lanes = Lanes(view = time, marks = marks, headerWidth = HeaderWidth,
                          snapStep = 1 / fps,
                          lanes = @[lane("V2", header = header("V2", "on", true)),
                                    lane("V1", header = header("V1", "on", true)),
                                    lane("Music", 64, header = header("Music", "mute", false))],
                          clips = @[
                            clip("title", 0, 0.0, 4.0, "Title", tint(120, 90, 200)),
                            clip("a", 1, 0.0, 9.5, "Beach", tint(60, 140, 200)),
                            clip("b", 1, 9.5, 7.0, "Harbour", tint(70, 160, 120)),
                            clip("c", 1, 16.5, 11.0, "Sunset", tint(220, 130, 60)),
                            clip("m", 2, 0.0, 20.0, "Tune", tint(150, 150, 160), music)],
                          onClipSelect = proc(i: int) = refresh(),
                          onClipChanged = proc(i: int, c: LaneClip) = refresh(),
                          onSeek = proc(at: float) = refresh(),
                          onClipDelete = deleteClip).named("lanes")

lanes.onTick(proc(dt: float) =
  if not playing: return
  playhead.value = min(playhead.value + dt, 40.0)
  if playhead.value >= 40.0: playing = false
  refresh())
lanes.onKey(proc(k: KeyboardKey): bool =
  if k == KeyboardKey.Space:
    playing = not playing
    refresh()
    return true
  false)

refresh()
app.setRootWidget(root)
app.focusManager.setFocus(lanes)
app.start()
