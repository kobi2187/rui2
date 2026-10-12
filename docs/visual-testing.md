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

## Per-phase timers (`-d:ruiPerf`)

`visual frames` splits a frame into step and present only. Build with
`-d:ruiPerf` (a separate flag; the timers are `when`-ed out of ordinary and
`-d:ruiInspect` builds, so no clock is read) and ask `visual perf`:

```
presented=57 idle=185 sampled=56 phEvents=21/54/73 phScript=14/29/65 phPoll=5/8/25
phLayout=1001/1359/3545 phTexAlloc=2728/4511/5138 phRender=2410/3423/5008
phCompose=5962/7649/9408 phScreen=7307/9051/9525 phReadback=9405/12734/12962
phSwap=1172/1203/7692 pcPainted/frame=8.8 pcTextures/frame=8.8 first{...}
```

Each `phX=avg/p95/max` is microseconds per presented frame. The phases are
disjoint: `events`, `script`, `poll` (theme watch, data sources, repaint timers),
`layout`, `texalloc` (freeing and creating widget render textures), `render`
(what widgets draw), `compose` (blitting child textures into the parent's),
`screen` (root and overlays to the window), `readback` (the probe's framebuffer
read, so you can see its cost and subtract it), `swap` (`endDrawing`: swap, input
poll, frame-rate wait) and `idle` (blocked, in idle frames). Counters:
`pcPainted` widgets repainted and `pcTextures` textures created, per frame.
`first{...}` is the first presented frame alone, which carries the warm-up.
`visual perf reset` starts a new sample. Without the flag the verb says so.

`PROBE_PERF=1 tools/gallery_probe.sh` builds with it and prints the table while
the Live ticker runs. The call sites are `perfTime(phase): body` in `app.nim`
and `main_loop.nim`; `rui_core/perf.nim` is the bookkeeping.

First reading (software GL, ticker running, ~9 widgets repainted per frame):
compose, screen and readback are the big three, then texture alloc and render.
Every repaint frees and recreates the widget's render texture
(`texalloc` ~2.7 ms per frame), which is the first thing to try reusing.

## Scenarios

`tools/perf_scenarios.sh` drives the gallery through kinds of work and prints one
row each (average microseconds per presented frame; `paint` widgets repainted,
`kpix` thousand pixels of texture painted, `blitK` thousand pixels blitted into
parents). `check` fails when a scenario paints far more than it should, and runs
in `run_tests.sh ui`.

```
scenario           frames  paint kpix/fr blitK/fr | layout  texal render compose screen   swap
idle (3 s)              2    0.0       0       0 |     32      0      0      0    425    937
ticker 20/s            77    9.0     595     730 |    841      1   2143   3413   2384    912
echo label             59    7.0     106     132 |    835      0   1083   1735   1502   1379
type in TextArea       59    5.0     348     424 |    587      0   1373   2156   2073   1467
scroll 10k ListView    59    6.0     210     250 |    527      0    794   2119   1601   1335
scroll ScrollView      59    7.1     327     414 |    961      4    473   2612   2034   1385
scroll DataTable       59    6.0     378     454 |    563      0    936   2760   1954   1376
switch tabs (junk)     59    2.9    1246    1860 |    443    108    718   1850   6137   1370
resize window          59    3.0    1906    1770 |    676    853     18   4310   6479   2540
```

What the table says (software GL): the damaged-area repaint works -- a changed
label paints ~100k pixels where the window is 720k -- yet `compose` stays at
1.5-3.4 ms. It does not follow the pixel count; it follows the number of widgets
repainted (5-9 per frame, one framebuffer switch and flush each). Five of those
are containers that draw nothing (the page holder, a Column, a Wrap, the tab
holder, the root): each exists only to re-composite its children into a texture
that is then composited again. Letting render-less containers have no texture,
and their parent composite their descendants directly, is the next step. The
other fixed costs: `screen` (the whole-window blit, 1.5-2.4 ms, 6 ms when
everything changes) and `swap` (~1-1.5 ms). Resizing reallocates every texture
(`texal`). Text is not the problem: 0-3 cache misses per frame.

## What it found

The first run showed every tab presenting 60 frames a second while idle: a
hidden tab page's dirty flag was never cleared (nothing paints it), so the
whole window repainted continuously. `anyChildDirty` and `anyChildLayoutDirty`
now skip hidden children.
