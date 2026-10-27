# Editors: waves, timelines, tracks

Audio editors, video editors, DAWs, data loggers and Gantt charts are built
from the same few pieces. Each piece is its own module with one job, and they
connect in one way: **they share an axis**.

```
          Link[AxisView]  (seconds, samples, x ...)
        /       |        |          \           \
    Ruler   Waveform  AxisMarks    Lanes      Plot(xView)   Timeline(view)
            (samples)  (playhead,   (clips)
                        selection,
                        markers)
```

| Piece | Module | What it does |
|---|---|---|
| `AxisView`, `ViewInput` | `view_range.nim` | One zoomable axis: the data at the left edge and the data per pixel. Held in a `Link`, so everything on it moves together. Also the gestures every piece shares. |
| `Ruler` | `modern/ruler.nim`, `axis_ticks.nim` | The scale: numbers, seconds, timecode, samples, bars and beats. A press seeks. |
| `SampleSource` | `sources/samples.nim` | Samples in memory, or a WAV file mapped from disk (never loaded). Summarised on the background thread. |
| `Waveform` | `modern/waveform.nim`, `wave_draw.nim` | Samples at any zoom: an envelope, a line, then a dot on each sample. One lane per channel. |
| `AxisMarks` | `modern/axis_marks.nim`, `axis_snap.nim` | The playhead, the selection and the markers, laid over anything on a view. Snapping. |
| `Lanes` | `modern/lanes.nim` | Rows of clips to move, trim and snap. Headers are real widgets. A clip can show its samples. |
| `Plot` with `xView`, `waveSeries` | `modern/plot.nim` | A chart that zooms on x, and draws samples as one of its series. |
| `Timeline` with `view` | `modern/timeline.nim` | Dated events, on the same kind of axis. |

## Putting them together

```nim
let song = openWav("take.wav")
let time = newLink(wholeView(0.0, song.seconds))   # all of it, to start
let playhead = newLink(0.0)
let selection = newLink(noSpan())

ui:
  Column:
    Ruler(view = time, ticks = secondTicks(),
          onSeek = proc(at: float) = playhead.value = at)
    Stack(fit = StackFit.expand):                  # marks over the wave
      Waveform(source = song, view = time)
      AxisMarks(view = time, playhead = playhead, selection = selection)
```

- **One Link per axis.** Whichever piece zooms or pans, the others redraw. Your
  own code changes the view the same way, for example
  `time.value = time.value.showing(a, b, width)` for "zoom to selection".
- **The same gestures everywhere** (`ViewInput`, `viewWheel`, `viewKey`):
  - a drag pans;
  - the wheel pans, and Ctrl+wheel zooms about the pointer;
  - two fingers pinch;
  - Left/Right, Home/End and +/- work when focused.

  AxisMarks and Lanes use the drag for their own work (selecting, moving
  clips), and still zoom and pan with the wheel.
- **Per pixel, not per width.** A wider window shows more of the data rather
  than the same data stretched, as editors do. `wholeView` fits everything
  until the first zoom.
- **The playhead and the selection are Links.** A transport, a menu or a
  keyboard shortcut sets them the same way the pieces do.
- **Snapping is shared** (`axis_snap.nim`). A selection edge and a clip edge
  catch on the same things the same way, and Alt turns it off.
- **Big data stays where it is.** Samples are mapped, never loaded, and
  summarised off the UI thread. A long text uses a `TextPager` in the same
  spirit ([sources](sources.md)).

## Examples

- `examples/widgets/audio_editor.nim` is a ruler, a stereo waveform, marks, a
  playhead that plays, and zoom to selection.
- `examples/widgets/video_editor.nim` has panes with movable dividers
  (`SplitView`), a preview, a bin, and a timecode ruler over lanes of clips. It
  supports split and delete, and its audio clip shows its wave.

## Writing another piece

A new piece on an axis takes `view: Link[AxisView]`:
- In `layout` it calls `widget.followView(view)` and, when it draws,
  `view.resolved(width)`.
- It maps data to pixels with `toPixel` and back with `toData`.
- It feeds its events to `ViewInput` for the shared gestures.

That is all it takes to move with the rest.
