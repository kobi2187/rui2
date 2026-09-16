# packages/rui_widgets/src/containers/column.nim

## Purpose

Vertical layout with **main-axis distribution and cross-axis alignment** —
Flutter's Column. Reach for VStack for the common case (stack things with a
gap); reach for Column when you need the alignment options, which VStack does
not implement.

## Public interface

- `MainAxisAlignment*` — `MainStart`, `MainCenter`, `MainEnd`, `SpaceBetween`,
  `SpaceAround`, `SpaceEvenly`.
- `CrossAxisAlignment*` — `CrossStart`, `CrossCenter`, `CrossEnd`,
  `CrossStretch`.
- `newColumn*(spacing = 0.0, mainAxisAlignment = MainStart,
  crossAxisAlignment = CrossStart, padding: EdgeInsets)`.

## Usage pattern

```nim
let column = newColumn(spacing = 6.0, mainAxisAlignment = MainStart,
                       crossAxisAlignment = CrossCenter)
column.bounds = Rect(x: 0, y: 0, width: 560, height: 90)
column.addChild(newLabel(text = "short", fontSize = 14.0))
```

Distribution needs a known height, so give a Column explicit `bounds` when
using anything other than `MainStart`.

## Circumstances

Restored 2026-09-15 from `a4bcc18`.

**Two layout passes, deliberately.** Distribution needs every child's height
before any child's position can be decided, so pass 1 lets each child measure
itself and pass 2 places them. Children are laid out again in pass 2 because
`layout()` is idempotent and re-running it is what keeps *grand*children from
being left behind at the scratch position — a single top-to-bottom sweep, which
is all VStack does, cannot support centre or end alignment.

**The `{.deprecated.}` module pragma was removed.** The notice pointed at
VStack, but VStack implements neither `MainAxisAlignment` nor
`CrossAxisAlignment`, so the deprecation was pointing at something that could
not replace it. The doc comment now says which to use when instead.
</content>
