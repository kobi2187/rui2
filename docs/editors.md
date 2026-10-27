# Editors: waves, timelines, tracks

Audio editors, video editors, DAWs, data loggers and Gantt charts are built
from the same few pieces. Each piece is its own module with one job, and they
connect in one way: **they share an axis**.

```
            Link[AxisView]  (seconds, samples, x ...)
        /        |           |            \              \
    Ruler    Waveform      Lanes       Plot(xView)    Timeline(view)
           (samples)      (clips)
                 \         /
                   Marks          (playhead, selection, markers: one value,
                                   given to whichever widgets show them)
```

| Piece | Module | What it does |
|---|---|---|
| `AxisView`, `ZoomPan` | `view_range.nim` | One zoomable axis: the data at the left edge and the data per pixel. Held in a `Link`, so everything on it moves together. `ZoomPan.handle` is the one call that gives a widget the shared gestures. |
| `Ruler` | `modern/ruler.nim`, `axis_ticks.nim` | The scale: numbers, seconds, timecode, samples, bars and beats. A press seeks. |
| `SampleSource` | `sources/samples.nim` | Samples in memory, or a WAV file mapped from disk (never loaded). Summarised on the background thread. |
| `Waveform` | `modern/waveform.nim`, `wave_draw.nim` | Samples at any zoom: an envelope, a line, then a dot on each sample. One lane per channel. |
| `Marks` | `modern/axis_marks.nim`, `axis_snap.nim` | Not a widget: the playhead, the selection and the markers, as one value you give to a `Waveform` or `Lanes` (`marks = ...`). Snapping. |
| `Lanes` | `modern/lanes.nim` | Rows of clips to move, trim and snap. A lane's header is its name or a widget you give it. A clip can show its samples. |
| `Plot` with `xView`, `waveSeries` | `modern/plot.nim` | A chart that zooms on x, and draws samples as one of its series. |
| `Timeline` with `view` | `modern/timeline.nim` | Dated events, on the same kind of axis. |

## Putting them together

```nim
let song = openWav("take.wav")
let time = newLink(wholeView(0.0, song.seconds))   # all of it, to start
let marks = newMarks(playhead = newLink(0.0), selection = newLink(noSpan()))

ui:
  Column:
    Ruler(view = time, ticks = secondTicks(),
          onSeek = proc(at: float) = marks.playhead.value = at)
    Waveform(source = song, view = time, marks = marks)
```

- **One Link per axis.** Whichever piece zooms or pans, the others redraw. Your
  own code changes the view the same way, for example
  `time.value = time.value.showing(a, b, width)` for "zoom to selection".
- **The same gestures everywhere**, from one call (`ZoomPan.handle`):
  - a drag pans;
  - the wheel pans, and Ctrl+wheel zooms about the pointer;
  - two fingers pinch;
  - Left/Right, Home/End and +/- work when focused.

  With `marks`, a drag selects and a click seeks instead; Lanes' drag moves
  clips. The wheel still zooms and pans.
- **Per pixel, not per width.** A wider window shows more of the data rather
  than the same data stretched, as editors do. `wholeView` fits everything
  until the first zoom.
- **The playhead, the selection and the markers are Links** (inside
  `Marks`). A transport, a menu or a keyboard shortcut sets them the same way
  the pieces do, and every widget showing them redraws. Give the same `Marks`
  to a Waveform and Lanes and they share a playhead.
- **Nothing runs behind your back.** Library code (`handle` on `ZoomPan` or
  `Marks`) changes the state you gave it and returns what it did. It never
  calls your code. A widget's handler reads the answer and decides what
  follows, so a debugger walks straight through it.
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

A new piece on an axis is an ordinary `definePrimitive` that takes
`view: Link[AxisView]`:

```nim
state:
  zoom: ZoomPan
events:
  on_event:
    return widget.zoom.handle(widget, widget.view, event, widget.bounds)
layout:
  widget.followView(widget.view)            # redraw when anyone moves it
render:
  let v = widget.view.resolved(widget.bounds.width)
  # draw with v.toPixel(x, widget.bounds.x); back with v.toData(px, ...)
```

`on_event:` gets every event kind the widget has no handler of its own for.
A handler that does something first (selects a clip, seeks) and otherwise
wants the zooming calls `widget.zoom.handle(...)` itself, at its end. With
marks, call `marks.handle(...)` first: it returns what it did (`MarksDone`),
and `mdNothing` means "not mine", so you then call the zoom. `marks.draw(v,
area)` draws them.
