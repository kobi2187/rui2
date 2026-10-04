# Performance

`tools/bench.sh` builds and runs `benchmarks/bench.nim`: a Column of Rows of
mixed controls (Label, Button, Checkbox), timed at 1,000 and 10,000 widgets.
Medians, in milliseconds, on the Xvfb software renderer (a real GPU is faster
at the render rows, not slower). `--gate` fails when a row is over budget;
`--json` prints one line for recording.

| | 1,000 widgets | 10,000 widgets |
|---|---:|---:|
| build the tree | 0.8 | 7.7 |
| layout, everything dirty | 2.7 | 21 |
| layout, one label changed | 0.9 | 7.7 |
| hit-test system rebuilt | 0.7 | 11 |
| hit-test, one pointer lookup | 0.004 | 0.04 |
| render, everything repainted | 22 | 1000 |
| render, one label changed | 0.35 | 1.0 |
| idle frame (nothing changed) | 0.007 | 0.3 |

A frame at 60 fps is 16.7 ms. At 1,000 widgets every interactive path is a
small fraction of that, and an idle UI costs microseconds. At 10,000 widgets
a change still fits in a frame (7.7 ms of layout + 1 ms of render), and only
a repaint of *everything* does not.

## What the benchmark found

**Fixed: the text-measure cache.** Every widget measures its text on every
layout. The cache was capped at 4,000 strings and wiped entirely when full,
so a UI with more distinct strings than that missed on every lookup, every
pass. 10,000 widgets took 164 ms to lay out (the 4,000-widget run took 9 ms,
the 8,000 run 121). It is now two generations of 32,768 entries, and a hot
set survives churn: 10,000 widgets lay out in 21 ms, a one-label change in
7.7 ms (was 73).

**Open (see TODO #8):**

- *Memory per widget.* Every widget owns a render texture, and raylib gives
  each one a 32-bit depth renderbuffer it never uses: roughly twice the GPU
  memory it needs. 10,000 widgets hold 341 MB of colour alone. Fixes: build
  the framebuffers without depth, and cache only containers and expensive
  leaves, drawing cheap ones into their parent.
- *Tall content.* A widget taller than the GPU's texture limit (16,384 px
  here) cannot be cached: the framebuffer is incomplete. A very long
  non-virtualised column inside a ScrollView hits this; ListView, TreeView
  and the tables virtualise and are fine.
- *Changes relayout the whole tree.* A container's layout re-lays out every
  child, so one changed label costs O(widgets) of layout. Fast enough here,
  but it is what the measure/arrange redesign (TODO #1) would remove.
- *Full repaint is slow at scale.* 1 s for 10,000 widgets: texture creation
  plus first-time text rasterisation. Culling widgets outside the viewport
  before layout and render (TODO #8) is the fix.
