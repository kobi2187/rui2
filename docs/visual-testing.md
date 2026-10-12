# Visual testing: the gallery and the `visual` verb

Scripting (`read`, `write`, `invoke`) is for **data**: what a widget says. This
is for **pixels and time**: did the pane really repaint, and how long did that
take? A value can update in the widget and never reach the screen, or reach it
a few frames late; only the presented frame tells.

## The gallery

`examples/gallery/gallery.nim` puts every widget on screen, in tabs (Basics,
Input, Pickers, Layout, Lists & data, Graphics, Menus, Live).
`tests/test_gallery.nim` fails when a registered widget is missing from it, so a
new widget has to be given a place there.

```
nim c -r -d:useGraphics examples/gallery/gallery.nim [theme] [--tab N] [--only N] [--live]
```

`--only N` builds just one tab (to find which widget misbehaves), `--live`
starts the Live tab's ticker. Widgets carry ids: `tabs`, `<tab>.<name>`
(`basics.save`, `input.text`, `live.echo`).

The **Live** tab exists to be measured: `live.input` echoes into `live.echo`,
`live.bump` increments `live.bumped`, and `live.run` starts a ticker that
updates `live.tick`, a progress bar, a sparkline and a log every 50 ms.

## Driving it

Build with `-d:ruiInspect` (test-only, like `inspect`) and start with
`--script DIR`. Commands go in `DIR/commands.txt`, one per line, answers appear
in `DIR/responses.txt`:

```
1 tabs write activeTab=7          # switch to the Live tab
2 live.echo visual stable 200     # wait until it has stopped changing
3 live.echo visual arm            # remember its pixels now
4 live.input write hello          # a write is an edit: onChange fires, the echo follows
5 live.echo visual change 500     # wait for the pixels to differ
```

answers `5 ms=25.052 frames=1 hash=...`: 25 ms from the arm to the frame that
showed the change, one frame later. If nothing repaints within the timeout the
answer is a failure, `no visual change in 500ms (live.echo)`.

| verb | what it answers |
|---|---|
| `visual clock` | `ms=` since start, `frame=` presented frames so far |
| `visual frames` | step and present timings (avg / p95 / max, microseconds) over the last 600 frames |
| `visual hash [fresh]` | hash and mean colour of the selector's rectangle, as presented |
| `visual shot [file] [fresh]` | that rectangle as a PNG (default `DIR/shots/shotNNN.png`) |
| `visual arm` | remember the rectangle's pixels and the time |
| `visual change [timeoutMs]` | wait until they differ; `ms=` since the arm |
| `visual stable [quietMs [timeoutMs]]` | wait until they stop changing |

The selector is a widget id, or `*` / `window` for the whole window. `fresh`
waits for the next presented frame instead of using the last one. The probe
reads the framebuffer just before the buffer swap, so a shot is exactly what a
user could have seen; commands that wait pause the command file, one poll per
frame, then carry on (`TextBatch` in `script_manager.nim`).

Timing is taken from the app's monotonic clock, so `arm`, `write`, `change` in
one file run back to back inside a frame and the number does not include the
client's file polling.

### Scripts act like a person

`write` on a widget now also calls its change handler (`onChange`, `onToggle`,
`onSelect`...) with the new value, and `toggle` works on a Switch. Before, a
script changed the widget and nothing bound to it noticed.

## The probe

```
tools/gallery_probe.sh          # tables and screenshots of every tab
tools/gallery_probe.sh check    # also exit 1 on a missed threshold (runs in CI: `run_tests.sh ui`)
```

It reports, per tab, the frames presented in 1.5 s of doing nothing (should be
~1) and a PNG; then repaint latency for a click, typed text and the ticker
(min / avg / max over several runs); then confirms an unchanging label really
reports no change. Thresholds: `PROBE_LATENCY_MS` (250), `PROBE_IDLE_FRAMES` (20).

## What it found

The first run showed every tab presenting 60 frames a second while idle: a
hidden tab page's dirty flag was never cleared (nothing paints it), so the
whole window repainted continuously. `anyChildDirty` and `anyChildLayoutDirty`
now skip hidden children.
