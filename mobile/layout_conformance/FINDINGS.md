# Layout conformance: what RUI does differently from Flutter

## Status

The first run (below, kept for the record) gave 78 match, 52 mismatch,
34 inexpressible and 2 silent. Since then RUI's constraint model has been
moved to Flutter's (docs/layout.md): the parent wins, constraints can be
loose, and what wants to fill fills. The constraint boxes have been added
(UnconstrainedBox, OverflowBox, LimitedBox, AspectRatio, FractionallySizedBox,
IntrinsicWidth/Height, Offstage, Visibility), along with Align/Center factors,
`Container.constraints`, `Stack.fit.passthrough`, `FractionColumnWidth`,
`TableCellVerticalAlignment.fill` and SizedBox's NaN / 0 / Inf. Now:

**142 match, 7 mismatch, 15 inexpressible, 2 silent.**

Still open:

- **ScrollView's scroll-bar gutter** (5 mismatches). The content is 12 px
  narrower even when nothing overflows; Flutter overlays its scroll bars.
- **Text metrics** (1). The same text is 470 px wide in Flutter and 465 px in
  RUI: Pango rounds each glyph's advance to whole pixels.
- **`Table` with every cell `fill`** (1). Flutter gives the row 0 height. RUI's
  old "0 = size yourself" arrange protocol cannot assign a 0, so the cells
  keep their own heights. It is a degenerate case.
- **Inexpressible:**
  - text direction (RTL) on Row, Column, Stack and Wrap; `verticalDirection`
    (7 cases);
  - Wrap's `direction` and `runAlignment` (5);
  - horizontal scrolling (2);
  - `GridView.extent` and `ListView.itemExtent`.
- **Silent:** an Expanded in an unbounded Column, and an Expanded outside a
  Flex. Flutter reports both as errors; RUI accepts them without a word.

Where RUI deliberately differs:

- `VStack` / `HStack` stretch the CSS way: a child's own width wins.
- A stretching Flex with an unbounded cross axis stretches its children to
  the widest one; Flutter reports an error there.
- Visibility's `visible` is named `shown`, because every widget already has a
  `visible` field.

---

# First run


166 cases, every Flutter layout container. Each case was built from the same
JSON by both toolkits and compared node by node: **78 match, 52 mismatch,
34 inexpressible, 2 silent** (first run; `known.json` is the baseline).

```bash
mobile/layout_conformance/run.sh
```

That writes `/tmp/rui_layout_conformance/report.md`, with a table of rects and
a Flutter | RUI picture for every mismatch, in about 30 seconds (no window, no
device). Add a case to `cases.py` and it runs on both sides. If RUI cannot say
it, the runner names the missing widget or prop instead of guessing.

Almost every mismatch comes from two decisions in RUI's constraint model.
They are listed first because fixing them fixes most of the rest. After them
come the smaller differences, then what RUI cannot express at all.

---

## A. A requested size beats the parent's constraints (21 cases)

**Flutter:** constraints always win. `SizedBox(width: 40)` means "40, if my
parent allows it". A stretched cross axis, an `Expanded`, a `Flexible(fit:
tight)`, a Table cell, a `Positioned` with `left` and `right`, `StackFit.expand`,
a `ListView` row, or a tight root all force the child's size. A `Flexible`
caps a too-large child at its share.

**RUI:** an explicit size (`SizedBox`, `.frame`, `ConstrainedBox` on a sized
child) wins over the parent, "as in CSS" (docs/layout.md). The child keeps 40,
and it overflows its parent if it is bigger.

| case | Flutter | RUI |
|---|---|---|
| Row/cross/stretch, Column/cross/stretch | boxes stretched to 200 / 300 | keep 30 / 40 |
| Row/flexible.loose/large-child-capped | 400-wide box capped at its 250 share | 400, overflows |
| Row/flexible.tight | 30-wide box forced to 250 | 30 |
| SizedBox/width-only | child forced to the SizedBox's 80 | child keeps 30 |
| SizedBox/larger-than-parent, Box/in-row-taller-than-row | clamped to the parent | 500 wide, 300 tall: overflows the parent |
| ConstrainedBox/min, ConstrainedBox/max | 20x20 box made 100x60; 200x200 box made 100x60 | unchanged |
| Stack/fit.expand | children 300x200 | 80x60, 40x30 |
| Positioned with left+right, top+bottom, or width | child sized by the Positioned | child keeps 40x30 |
| Table/* (5) | every cell as wide as its column | cells at their own width |
| Wrap/child-wider-than-run | clamped to the run (300) | 400 |
| ListView/children | rows as wide as the list | 100 |
| SizedBox/tight-root-wins | the root is the viewport | 50x50 |

The Flutter idiom for "stretch the row, but not this child" is
`Align(child: …)` inside the stretch. It already works in RUI
(Row/stretch/align-keeps-child-size: the Align part matches). So adopting
Flutter's rule costs no expressiveness: the CSS behaviour is one `Align` (or
an `UnconstrainedBox`, see C) away.

**To enable:** in `measure`, clamp the request to the constraints
(`c.constrain(request)`) instead of letting it win, and pass tight constraints
where Flutter does (stretch, flex shares, cells, two-edged Positioned, fit
expand). This moves existing layouts, so the 59 layout snapshots will need a
deliberate update.

## B. "Loose" constraints are passed as "unbounded" (26 cases)

**Flutter:** `Center`, `Align`, a loose `Stack`, and a Flex's non-stretched
cross axis give their child *loose* constraints: anything from 0 up to the
room there is. A child that wants to be big takes all of it: a `Row` with
`mainAxisSize.max`, an empty `Container`, a `Container` with an alignment, a
`Center`. Text wraps at the room it has.

**RUI:** an axis is either tight or unbounded (docs/layout.md: "a container
fixes an axis (tight) or leaves it free (unbounded)"). "Up to 300" cannot be
said, so whatever would fill shrinks to its natural size, or to nothing.

| case | Flutter | RUI |
|---|---|---|
| Row/Column mainAxisSize.max in Center (6) | the Row is 300 wide (the Column 200 tall), children aligned in it | shrinks to its children; `mainAxisAlignment` has no room to act |
| Text/in-column/wraps | wraps at the column's 300 px, 2 lines | one 465 px line, overflowing |
| Container/empty-in-center, ConstrainedBox/max-with-fill | fills the room (300x200, 100x60) | 0x0 |
| Container/alignment-expands, Center/in-column/takes-all-width | fills the width, aligns the child in it | shrinks to the child |
| Row/expanded/* (4), Column/expanded-in-column-in-row | the `Expanded` child fills the row's height | 0 tall |
| Row/in-column/default-stretches-width | a Row in a start-aligned Column is 300 wide | 40 |
| Positioned/* (9) | a plain `Container` in a Stack fills it | 0x0 |

**To enable:** give `Constraints` a real loose form (min 0, max = room) and
pass it where Flutter does. "Fills the room" then falls out of each widget's
measure (`Container` without a child: `c.biggest`; `Flex` with
`mainAxisSize.max`: `c.maxWidth`), and a Label wraps at `c.maxWidth`. The
unbounded case stays where Flutter has it: inside scroll views and along a
Flex's main axis.

A and B are one change to the model. They meet in `measure` /
`applySizing` (rui_core/types.nim) and in each container's `computeSize`.

## C. Smaller differences

- **ScrollView reserves a scroll-bar gutter (3 cases).** It does this even when
  nothing overflows: the content is 288 wide, not 300 (Align/in-unbounded,
  SingleChildScrollView/*). Phone scroll bars overlay the content and fade
  in while scrolling. RUI's default padding of 8 also differs from Flutter's
  0; the runner passes 0.
- **`SizedBox(width: double.infinity)` gives infinite rects (bug).** In Flutter
  that is `SizedBox.expand`: as big as allowed. In RUI the widget and its child
  end up at x = −inf, width = inf (SizedBox/expand).
- **Text metrics (1 case).** The same 16 px Roboto string is 470 px wide in
  Flutter and 465 px in RUI (Text/in-row/unwrapped-overflows). Pango hints its
  advances to whole pixels; Flutter does not. The runner already converts
  Flutter's pixels to RUI's points (×0.75), which is finding 1 in
  mobile/README.md.

## D. Flutter rejects, RUI is silent (2 cases)

| case | Flutter | RUI |
|---|---|---|
| Column/expanded-in-scroll | error: Expanded in a Column with unbounded height | lays it out with the Expanded 0 tall |
| Expanded/outside-flex | error: incorrect use of ParentDataWidget | treats the Expanded as a plain box |

These are a Flutter developer's most common layout mistakes, and Flutter's
messages are how they learn the model. RUI could warn in debug builds, as it
already does for children built in `layout:`.

## E. What RUI cannot express (34 cases)

### Concepts

- **Text direction (RTL).** Row, Column, Stack, Wrap and Positioned have no
  `textDirection`, and there is no `PositionedDirectional` (`start`/`end`).
  Hebrew and Arabic layouts cannot mirror (6 cases). Pango already knows the
  paragraph direction; layout does not.
- **`verticalDirection: up`** on Row and Column (2).
- **Intrinsic sizing.** There is no `IntrinsicHeight` or `IntrinsicWidth`, the
  "make every child as tall as the tallest" tool (2). The measure protocol
  would need min/max intrinsic queries.
- **Horizontal scrolling.** `SingleChildScrollView` and `ListView` cannot have
  `scrollDirection: horizontal` (3, counting Row/expanded-in-unbounded-row).
- **Saying 0.** RUI's `SizedBox(width = 0)` means "width not given", so a
  zero-width or zero-height box (`SizedBox.shrink`) cannot be written (1).

### Widgets

`AspectRatio` (2), `FractionallySizedBox` (2), `LimitedBox`,
`UnconstrainedBox`, `OverflowBox`, `Offstage`, `Visibility` (gone, and
maintainSize).

### Properties

| widget | missing |
|---|---|
| Align, Center | `widthFactor`, `heightFactor` |
| Container | `constraints` |
| Stack | `fit: passthrough` |
| Wrap | `direction: vertical`, `runAlignment` (4 cases) |
| Table | `FractionColumnWidth`, `TableCellVerticalAlignment.fill` |
| GridView | `GridView.extent` (`maxCrossAxisExtent`) |
| ListView | `itemExtent`; a list of *widgets* at all (RUI's `ListView` lists strings, so the runner uses ScrollView + Column) |
| ScrollView | uneven padding (one float, not EdgeInsets) |

`GridView` also does not scroll in RUI; the cases here fit, so it does not show.

---

## Suggested order

1. **A + B, the constraint model.** This is one design change. It accounts for 47
   of the 52 mismatches and makes RTL and intrinsics possible. Do it before
   adding widgets: most missing widgets (`UnconstrainedBox`, `LimitedBox`,
   `OverflowBox`, `FractionallySizedBox`, `AspectRatio`) are a few lines each
   once constraints can be loose and clamping.
2. The SizedBox-infinity bug and the 0-means-unset convention.
3. Text direction through the flex, stack and wrap layouts.
4. The missing widgets and props in E. Each one turns a row of this file
   green.
5. Debug-build warnings for D.
6. The ScrollView gutter (overlay scroll bars on touch).

After each step, `run.sh` lists the cases that got better.
`run.sh --update` records them. CI (`.github/workflows/mobile.yml`) fails if
a case gets worse.
