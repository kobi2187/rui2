# Layout Module

Flutter-style two-pass layout system with composable calculation helpers.

## Public API

```nim
import modules/layout/api
```

### Core Types
- `Alignment` — Leading, Center, Trailing, Top, Bottom, Left, Right, Stretch, Baseline
- `Justify` — Start, Center, End, SpaceBetween, SpaceAround, SpaceEvenly
- `Direction` — Horizontal, Vertical
- `Container` — Base container with padding/spacing
- `HStack`, `VStack` — Simple stacks
- `FlexContainer` — Flexible direction/align/justify/wrap
- `Grid` — Grid layout with columns/rows
- `DockContainer` — Dock layout (Left, Top, Right, Bottom, Fill)

### Key Functions

| Function | Description |
|---|---|
| `newHStack(spacing, align)` | Create horizontal stack |
| `newVStack(spacing, align)` | Create vertical stack |
| `contentArea(bounds, padding)` | Calculate inner content area |
| `calculateDistributedSpacing(justify, ...)` | Spacing distribution |
| `calculateAlignmentOffset(align, ...)` | Cross-axis alignment |
| `applyPadding(bounds, padding)` | Shrink rect by padding |
| `totalChildrenSize(children, isHorizontal)` | Sum child sizes |

### Testing Without Graphics

All layout calculations are pure math — no GPU needed:

```nim
let bounds = Rect(x: 0, y: 0, width: 800, height: 600)
let padding = EdgeInsets(top: 10, right: 10, bottom: 10, left: 10)
let inner = applyPadding(bounds, padding)
assert inner.width == 780
```

### Dependencies
- `core/types` (Widget, Rect, EdgeInsets, Constraints, Size)
