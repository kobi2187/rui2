# Layout: measure, then arrange

RUI2 lays out the way Flutter does, in two questions per widget:

1. **Measure** -- `measure(widget, constraints): Size`. *How big do you want
   to be, within these constraints?* A container answers by measuring its
   children; it never lays them out to see where they land.
2. **Arrange** -- `arrange(widget, rect)`. *Here is your rect; place your
   children.* Each child is arranged once, after its parent knows every size.

```nim
let natural = child.measure(unbounded())                 # its own size
let share   = child.measure(unbounded().withWidth(120))  # at a fixed width
child.arrange(Rect(x: x, y: y, width: share.width, height: share.height))
```

## Constraints

`Constraints` gives a min and max per axis; `Inf` is "no limit". Build them
with `unbounded()`, `tight(w, h)`, `loose(w, h)`, `c.withWidth(w)`,
`c.withHeight(h)`, and bring a size within them with `c.constrain(size)`.

In this release a container fixes an axis (tight) or leaves it free
(unbounded): tight is a stretched cross axis, a flex share, a cell's column;
free is "your natural size".

A widget's own sizing is applied by `measure`, so a container never has to:
a requested size (`.frame(width = ...)`, `SizedBox`) wins over the
constraints -- an explicit width beats stretch, as in CSS -- and `sizeMin` /
`sizeMax` clamp the answer.

## Measurements are remembered

`measure` keeps the last few answers per widget. A widget that is not
layout-dirty answers from memory, so a container that asks twice (Flex asks
for the natural size, then again at the flex share) or a parent re-arranging
after one sibling changed does not re-measure untouched subtrees. Before each
pass, a dirty widget makes its ancestors dirty (`propagateLayoutDirty`): the
containers above it re-measure and re-place, so a label that grows pushes its
siblings along instead of overflowing.

The contract this asks of code: **a change that can alter a widget's size
marks it `layoutDirty`**. Links and the widgets' own setters do; a direct
field assignment must do it by hand.

Measured on `tools/bench.sh` (median, ms):

| | before | after |
|---|---|---|
| layout, 1k widgets, all dirty | 3.45 | 2.84 |
| layout, 1k widgets, one label changed | 1.16 | 0.05 |
| layout, 10k widgets, all dirty | 35.2 | 28.6 |
| layout, 10k widgets, one label changed | 9.11 | 1.14 |

## Writing a widget

A container overrides `computeSize` (measure) and `layout` (arrange):

```nim
method computeSize*(widget: MyBox, c: Constraints): Size =
  let inner = widget.children[0].measure(c.deflate(widget.padding))
  Size(width: inner.width + widget.padding.horizontal,
       height: inner.height + widget.padding.vertical)
```

and in its `layout:` section gives each child its rect with `arrange`. The
layout widgets (Flex/Row/Column, Padding, SizedBox, ConstrainedBox, Align,
Center, Container, Expanded, Flexible, Stack, Positioned, Wrap, Table,
GridView, Dock, SplitView, ScrollView) all work this way; `rui_core/layout.nim`
has the helpers (`wrapSize`, `wrapChild`, `deflate`, `constraintsOf`).

A widget that does not override `computeSize` is measured the old way: its
free sides are zeroed and its `layout` sizes it to its content. For a leaf --
a Label, a Button -- that is exactly a measurement, so leaves need nothing
more.

## Checking a change

`tools/layout_snapshot.sh` lays every example out without a window and diffs
each widget's rect against `tests/layout_snapshots/`. Run it after a layout
change; `update` records an intended change.

## Effects past the bounds: `effectReach`

A widget can paint outside its bounds -- a glow, a soft shadow -- by setting
`effectReach` (pixels, every side) before it paints. Layout, hit-testing and
focus keep using `bounds`: the widgets beside it sit where they always would,
and the effect lies over them. The render pass gives its texture that margin,
and a parent whose children spill past its own edges gets a margin too
(`inkPad`), so a glowing button inside a frame its own size is not clipped. A
viewport (`childClip`) stops the spill, and the window's root has none. A child
with a margin is composited after its siblings when their bounds do not
overlap, so the effect is on top; where they overlap (a Stack), order wins.

Keep the reach as large as the effect ever gets (a focus glow reserves its
room whether focused or not), so turning the effect on repaints only the
widget. The box finish is the ready-made one: its hard shadow (`drop`), soft
shadow and focus glow all lie past the box, and `keepFinishRoom(widget, props)`
in a widget's `layout` gives it the reach they need. A Button's bounds are its
body; its shadow is outside. A floating panel calls `floatAbove()` for its
soft shadow's room (and the glass behind it). The one thing drawn in screen
space instead is glass, which reads the page under a panel: `drawBehind`.
