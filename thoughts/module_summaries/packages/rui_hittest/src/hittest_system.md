# packages/rui_hittest/src/hittest_system.nim

*Only the part this session touched is described in detail.*

## Purpose

Spatial hit-testing: which widget is at a point, in O(log n), using dual
interval trees — one indexing widgets by their X interval, one by Y. A query
intersects both results.

## Public interface (orientation)

- `HitTestSystem*` — holds `xTree`, `yTree`, `widgetCount`.
- `newRect*(x, y, width, height: float32): Rect`
- `overlaps*(a, b: Rect): bool`
- `findWidgetsAt*`, `getWidgetAt*` — the query entry points; ties are broken by
  z-index, then by depth.
- Insert / remove / rebuild for maintaining the trees as the tree changes.

## Usage pattern

```nim
let widget = app.hitTestSystem.getWidgetAt(event.mousePos.x, event.mousePos.y)
if widget != nil:
  discard widget.dispatchBubbling(event)
```

## Circumstances

**`contains(Rect, x, y)` was removed from here 2026-09-16** and now lives in
`rui_core/types.nim`, next to `Rect`. Four of the restored widgets had declared
their own copy, and importing two of them through the `rui` barrel made every
call ambiguous.

The semantics did **not** change: the version in `rui_core` is inclusive on all
four edges, exactly as this module's was. A half-open version would have been
tidier for adjacent rects but would have silently stopped clicks landing on a
widget's right or bottom edge.

`removeNode` in the sibling `interval_tree.nim` is the second-highest
cyclomatic complexity in the repo at cc=16. That is **essential** complexity —
interval-tree deletion with rebalancing — and the architecture review
deliberately leaves it alone.
</content>
