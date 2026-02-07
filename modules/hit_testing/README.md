# Hit Testing Module

Efficient spatial queries for finding widgets at screen coordinates using dual AVL-balanced interval trees.

## Public API

```nim
import modules/hit_testing/api
```

### Core Types
- `HitTestSystem` — Dual interval tree system indexing widgets by X and Y bounds
- `IntervalTree[T]` — Generic AVL-balanced interval tree

### Key Functions

| Function | Description | Complexity |
|---|---|---|
| `newHitTestSystem()` | Create empty hit-test system | O(1) |
| `insertWidget(system, widget)` | Index a widget by its bounds | O(log n) |
| `removeWidget(system, widget)` | Remove a widget | O(log n) |
| `updateWidget(system, widget, oldBounds)` | Update after move | O(log n) |
| `findWidgetsAt(system, x, y)` | All widgets at point | O(log n + k) |
| `getWidgetAt(system, x, y)` | Topmost widget at point | O(log n + k) |
| `findWidgetsInRect(system, rect)` | All widgets in rectangle | O(log n + k) |
| `rebuildFromWidgets(system, widgets)` | Full rebuild | O(n log n) |

### Testing Without Graphics

All operations work in headless mode. Create widgets in memory with bounds set manually:

```nim
var w = Widget(bounds: Rect(x: 10, y: 10, width: 100, height: 50))
var system = newHitTestSystem()
system.insertWidget(w)
assert system.getWidgetAt(50, 30) == w
assert system.getWidgetAt(200, 200) == nil
```

### Dependencies
- `core/types` (Widget, Rect, WidgetId)
