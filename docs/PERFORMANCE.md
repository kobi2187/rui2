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
| render, everything repainted | 13 | 840 |
| render, one label changed | 0.13 | 0.7 |
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

**Fixed: a depth buffer on every widget.** raylib's `loadRenderTexture`
gives each framebuffer a 32-bit depth renderbuffer, which a 2D widget never
reads: as much GPU memory again, for nothing, plus the cost of creating it.
Widget textures are now colour-only: a full repaint of 1,000 widgets went
from 22 to 13 ms, repainting one label from 0.35 to 0.13 ms.

**Open (see TODO #8):**

- *Memory per widget.* Every widget still owns a render texture: 10,000
  widgets hold 341 MB of colour. Cache only containers and expensive leaves,
  drawing cheap ones into their parent.
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

## Check: the themes round (effect reach, finishes, Fizz)

`bench --theme=NAME` runs the benchmark in any registered theme. Against `main`,
at 1,000 widgets, it found two regressions, both fixed:

- **Every widget owns a texture, so an idle child costs one.** The Fizz added
  to every button (a soda theme's bubbles) took a full repaint from 7.2 to
  12.6 ms. Fizz is now hidden except while it rises: back to 7-8 ms, the same
  as `main`.
- **Effect room kept on every control costs memory.** Reserving the focus
  glow's room on every button whether focused or not took a neon theme
  (cyberpunk) from 38 to 65 MB of textures. The room is now taken only by the
  focused control: 38 MB.

What is left is what the effects draw. Aqua's soft shadows are on every
button, so it carries 14% more texture memory (43.8 MB against 38.4), with
render times within noise. At 10,000 widgets, layout, idle frame and a
one-label repaint match `main` (medians of five runs: repaint 1.1 ms against
1.6; the software renderer here varies by a factor of two from run to run).

## Experiment: should shapes and shadows be cached across widgets?

The classic trick is to render a shadow or a rounded box once and reuse the
bitmap until the size changes. RUI already does this per widget: every widget
paints into its own cached texture, so its SDF box, shadow and glow are shaded
once and reused until that widget repaints. The open question was whether a
cache *shared* between widgets, keyed by size, radius and finish, would pay:
300 identical buttons would then shade their shadow once instead of 300 times.

Measured by switching the box and shadow shaders off (the plain fallback still
draws the shapes), a full repaint of 1,000 widgets took the same time, within
noise: 9 to 16 ms either way, in daylight and in Aqua (soft shadows on every
button). The shapes are a small slice of a repaint; allocating textures,
setting text and compositing are the rest. **Decision: no shared shape cache.**
It would add code and a cache to invalidate for no measurable gain.

## Experiment: would a texture atlas help?

`tools/atlas_bench.nim` compares our way, one texture per text run, with a
game engine's way, everything packed into one atlas. It uses N text-sized
bitmaps (40-200 x 16-24 px), and every timing ends with `glFinish`. These
results are from the Xvfb software renderer (llvmpipe); run it on a real GPU
before deciding anything.

| N | upload, one each | upload, atlas (+ CPU packing) | draw N quads, one texture each | draw N quads, atlas |
|---:|---:|---:|---:|---:|
| 100 | 2.0 ms | 0.7 ms (+ 1.5) | 4.2 ms | 1.4 ms |
| 500 | 3.2 ms | 3.1 ms (+ 7.0) | 8.5 ms | 4.2 ms |
| 2,000 | 11.6 ms | 12.6 ms (+ 30) | 26.9 ms | 13.7 ms |

- **Uploading: no.** The cost follows the bytes, not how many textures carry
  them, and packing adds a CPU copy. In rui an upload also happens only once
  per distinct string, so after the first frame there is almost nothing to
  upload.
- **Drawing: yes, two to three times faster.** raylib ends a batch, with one
  draw call, at every texture change, while quads from one atlas go out
  together. This only pays where many textures are drawn in one frame: a
  repaint of everything, and text-heavy widgets. An idle frame or a one-label
  change is already well under a millisecond.
- **Where it would go:**
  - **A glyph-run atlas in `pango_text.nim`:** contained in one module, it
    speeds every text-heavy repaint and means fewer GPU objects.
  - **An atlas for widget textures:** pieces of a few large render targets
    instead of one each. It is a bigger change (a widget that resizes needs a
    new place in the atlas), and it overlaps the open "memory per widget"
    item above.


**Decision: no atlas for now.** The packing time is not the obstacle: a real
atlas would give each new text run a free slot as it is made and upload just
that rectangle, which costs about what a separate upload costs. The gain is.
The benchmark drew quads from textures back to back, the best case for an
atlas. rui draws a box, its text, then a box again, and the boxes, shadows
and lines are shaders (`drawSdfBox` and the rest), and every shader change
ends raylib's batch just as a texture change does. So an atlas would merge
little, while it brings lasting complexity into the module every widget uses:
holes as text is evicted, page eviction against the cache's memory budget,
full pages, and sampling kept inside each slot. Keep the benchmark, and
measure a real app on a real GPU before revisiting it. The cheaper way to
fewer textures per frame is the open "memory per widget" item: draw cheap
leaves into their parent.
