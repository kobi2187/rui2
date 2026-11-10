# Sizing and placing

How big a widget is, and where it goes, follows Flutter's rule:
**constraints go down, sizes go up, the parent wins.** This page is the
practical side: what to write for the layouts people want, in the short form
and in Flutter's long names. [layout.md](layout.md) has the rules themselves;
[ui_dsl.md](ui_dsl.md) the tree syntax.

Every recipe has two spellings:

- **Modifiers** wrap the widget they follow and return the wrapper (as
  `.margin` does): `Button(text = "OK").center`. Use them when the box wraps a
  single widget, which is most of the time.
- **Short constructors** (`Ratio`, `SameHeight`, `Gap` ...) are for the block
  form, when the box holds a subtree: `SameHeight(): Row(...)`.

Both are plain procs in `rui_widgets/layout/shortcuts.nim`, so they work in
`ui:`, in ordinary code (`newButton(text = "OK").center`), and on a widget you
`Embed`. The long Flutter names (`UnconstrainedBox(): ...`) work too and mean
the same.

## The model in four lines

- A parent tells each child how big it may be: exactly N (*tight*), anything
  up to N (*loose*), or anything at all (*unbounded*).
- The child picks its size within that, and the parent places it.
- `.frame(width = 80)` and `SizedBox(width = 80)` are a *wish* inside those
  limits. In a stretched Column, an `Expanded`, or a 50-pixel slot, the parent
  wins.
- Things that want to fill fill what they are allowed: a `Row`, an empty
  `Container`, `Center`, `Align`. Text wraps at the width it is given.

Tight comes from a stretched cross axis, an `Expanded` share, a table cell, a
`Positioned` with both edges, or the window. Loose comes from inside `Center`,
`Align`, a `Stack`, across a `Row` or `Column`, and in a `Wrap`. Unbounded is
along a `Row` or `Column`, and inside a `ScrollView`.

## Recipes

### Keep a widget's own size where the parent would decide it

A stretched Column makes every child as wide as itself. To keep one button at
its natural width:

```nim
Column(crossAxisAlignment = CrossAxisAlignment.stretch):
  TextInput(placeholder = "Email")             # full width
  Button(text = "Sign in").ownSize             # its own width, centred
  Button(text = "Help").align(Alignment.centerLeft)   # its own width, at the left
```

- **`.ownSize`** is `UnconstrainedBox`: the widget at its natural size whatever
  the parent says. If it is bigger than the parent, it overflows.
- **`.align` / `.center`** place the widget at its size within the room, up to
  the room's size. This is usually what you want.

`VStack` and `HStack`, RUI's own names, stretch the CSS way: a child that set
its own width (`.frame(width = ...)`) keeps it without any wrapper.

### A fixed shape: 16:9, a square, half the width

```nim
ImageWidget(imagePath = "cover.png").aspect(16 / 9)   # AspectRatio: as wide as allowed
Container(color = accent).aspect(1)            # a square
Panel().fraction(width = 0.5)                  # FractionallySizedBox: half the width
Panel().fraction(width = 0.8, height = 0.5)    # 80% wide, half as tall
```

`aspect` takes all the width it may and derives the height. If the height
limit is smaller, it works from the height instead.

### Equal heights, equal widths

```nim
Row(crossAxisAlignment = CrossAxisAlignment.stretch, spacing = 8.0).sameHeight:
  Card(): Label(text = "short")
  Separator(vertical = true)                   # as tall as the tallest card
  Card(): Label(text = "a much longer text that wraps onto lines", wrap = true)

Column(crossAxisAlignment = CrossAxisAlignment.stretch).sameWidth:
  Button(text = "Open")                        # every button as wide as the widest
  Button(text = "Save as...")
```

- **`.sameHeight`** is `IntrinsicHeight`.
- **`.sameWidth`** is `IntrinsicWidth`.

Use them around a stretched Row or Column whose height or width would
otherwise be unbounded.

### Place things over each other: badges, overlays, corners

```nim
Stack():
  ImageWidget(imagePath = "map.png").cover                # Positioned.fill: the whole stack
  Badge(text = "3").at(right = 8, top = 8)     # Positioned in the top-right corner
  Label(text = "Paris").at(left = 12, bottom = 12)
  ProgressBar(initialValue = 40).at(left = 0, right = 0, bottom = 0)   # full width, at the bottom
```

`.at(...)` is `Positioned`. If both edges of an axis are pinned (`left` and
`right`), the widget spans between them. Otherwise it keeps its own size,
or the `width` / `height` you give.

### Gaps

```nim
Column():
  Label(text = "Title")
  Gap(12)                                      # SizedBox(height: 12)
  Label(text = "Body")
```

`Gap(n)` works in a Row or a Column. `spacing = ...` on the Row or Column is
shorter still, when every gap is the same.

### Share the room: fill, or at most

```nim
Row(spacing = 8.0):
  TextInput(placeholder = "Search").flex       # Expanded: all the rest
  Button(text = "Go")

Row():
  Label(text = longName).flexible              # Flexible: up to the rest, less if shorter
  Badge(text = "new")
```

- **`.flex(n)`** is `Expanded`: exactly n shares.
- **`.flexible(n)`** is `Flexible`: at most n shares.

Put them last in a chain, after any wrapper: in `Button(...).center.flex`, the
Center takes the share.

### Cap a size, but only where there is no limit

```nim
ScrollView():
  Column():
    Container(color = tint).limit(height = 200)   # LimitedBox: 200 high here,
                                                  # where the scroll view sets no limit
```

`.limit` does nothing where the parent already sets a limit. To cap a size
everywhere, use `.frame(maxHeight = 200)`.

### Let something be bigger than its slot

```nim
SizedBox(width = 48, height = 48):
  ImageWidget(imagePath = "logo.png").overflow(maxWidth = 96, maxHeight = 96)   # OverflowBox
```

The slot stays 48×48. The image may be up to 96×96 and spills over the slot.

### Hide

```nim
Label(text = "Saved").showIf(saved.value)                     # gone when false
Label(text = "Saved").showIf(saved.value, keepSize = true)    # its room stays
Spinner().offstage                                            # laid out, never shown
```

- **`.showIf`** is `Visibility`; the long form's prop is `shown`, not
  `visible`.
- **`.offstage`** is `Offstage`.

## Reference

### Modifiers and short constructors

| Flutter | modifier | block form |
|---|---|---|
| `Center(child: w)` | `w.center` | `Center():` |
| `Align(alignment: a, child: w)` | `w.align(Alignment.topRight)`, `w.align(1, -1)` | `Align(alignment = ...):` |
| `UnconstrainedBox(child: w)` | `w.ownSize` | `OwnSize():` |
| `OverflowBox(maxWidth: ..)` | `w.overflow(maxWidth = 96)` | `OverflowBox(...):` |
| `LimitedBox(maxHeight: ..)` | `w.limit(height = 200)` | `Limit(height = 200):` |
| `AspectRatio(aspectRatio: r)` | `w.aspect(16 / 9)` | `Ratio(16 / 9):` |
| `FractionallySizedBox(...)` | `w.fraction(width = 0.5)` | `Fraction(width = 0.5):` |
| `IntrinsicHeight` / `IntrinsicWidth` | `w.sameHeight` / `w.sameWidth` | `SameHeight():` / `SameWidth():` |
| `Visibility(visible: b)` | `w.showIf(b, keepSize = false)` | `ShowIf(b):` |
| `Offstage(child: w)` | `w.offstage` | `Offstage():` |
| `Positioned(left: .., top: ..)` | `w.at(left = 8, top = 8)` | `At(left = 8, top = 8):` |
| `Positioned.fill` | `w.cover` | `At(left = 0, top = 0, right = 0, bottom = 0):` |
| `Expanded(flex: n)` / `Flexible` | `w.flex(n)` / `w.flexible(n)` | `Expanded():` / `Flexible():` |
| `SizedBox(height: 12)` as a gap | | `Gap(12)` |
| `SizedBox(width: w, height: h)` | `w.frame(width = w, height = h)` | `SizedBox(width = w, height = h):` |
| `ConstrainedBox(constraints: ..)` | `w.frame(minWidth = .., maxWidth = ..)` | `ConstrainedBox(constraints = ...):` |
| `Padding(padding: ..)` | `w.padding(8)`, `w.padding("8px 16px")` | `Padding(padding = ...):` |

### The boxes, in full

| Widget | Props | What it does |
|---|---|---|
| `SizedBox` | `width`, `height` (NaN: not given, 0: zero, `Inf`: as big as allowed) | that size, within the parent's limits |
| `ConstrainedBox` | `constraints` (a max of 0 is unbounded) | extra limits, within the parent's |
| `Container` | `width`, `height`, `padding`, `margin`, `color`, `decoration`, `alignment`, `constraints` | without a child it fills; with `alignment` it fills and aligns the child; otherwise it is the child plus padding |
| `Align`, `Center` | `alignment`, `widthFactor`, `heightFactor` | fill a bounded axis (or the child × factor), with the child placed in it |
| `UnconstrainedBox` | `alignment`, `constrainedAxis` (0 none, 1 width, 2 height) | the child at its natural size; the box as the parent allows |
| `OverflowBox` | `alignment`, `minWidth`, `maxWidth`, `minHeight`, `maxHeight` (NaN: the parent's) | the child under these limits; the box as big as allowed |
| `LimitedBox` | `maxWidth`, `maxHeight` | a limit only where the parent sets none |
| `AspectRatio` | `aspectRatio` (width / height) | the largest size at that ratio |
| `FractionallySizedBox` | `widthFactor`, `heightFactor` (NaN: the parent's), `alignment` | the child at a share of the room |
| `IntrinsicWidth`, `IntrinsicHeight` | | the child as wide / tall as it wants to be, so its stretched children match |
| `Offstage` | `offstage` | laid out, not shown, no room |
| `Visibility` | `shown`, `maintainSize` | shown, or gone, or an empty space its size |
| `Stack` | `alignment`, `fit` (`loose`, `expand`, `passthrough`), `padding` | layers; as big as the biggest plain child |
| `Positioned` | `left`, `top`, `right`, `bottom`, `width`, `height` | pinned in a Stack |
| `IndexedStack` | `index`, `alignment` | a Stack showing one child |

`Row`, `Column`, `Flex`, `Expanded`, `Flexible`, `Spacer`, `Wrap`, `Table`
and `GridView` are in [layout.md](layout.md) and the README. Every one of
them is checked against Flutter by `mobile/layout_conformance/run.sh`.

## Checking it on phones

`tools/fit_check.sh app.nim` runs the app at the sizes of common phones and
tablets and lists what does not fit on each ([fit_check.md](fit_check.md)).

## When Flutter and RUI differ on purpose

- `VStack` / `HStack` stretch the CSS way: a child's own width or limits win.
  `Row` / `Column` stretch the Flutter way.
- A stretching Column inside a Row (no width limit) stretches its children
  to the widest of them. Flutter reports an error here and wants an
  `IntrinsicWidth`.
- `Visibility`'s `visible` is `shown`.
