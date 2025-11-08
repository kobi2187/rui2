# Hit-Testing System Design Decisions

## Core Question: Rebuild vs Incremental Updates?

**TL;DR**: We support both. Use incremental updates when you can, rebuild when you need simplicity.

## The Trade-offs

### Full Rebuild Strategy

```nim
hitTestSystem.rebuildFromWidgets(allWidgets)
```

**Time Complexity**: O(n log n) where n = total widgets

**Pros**:
- ✅ Simple - one line of code
- ✅ No tracking needed
- ✅ Can't get out of sync
- ✅ Actually fast for small UIs (<100 widgets)
- ✅ No extra memory per widget

**Cons**:
- ❌ Wasteful if only 1 widget moved
- ❌ Scales with total widgets, not changed widgets

**When to use**:
- Small UIs (<100 widgets) - overhead is negligible
- Initial setup
- Major changes (window resize, theme change)
- Simplicity > performance

### Incremental Update Strategy

```nim
# Option A: Manual tracking
let oldBounds = widget.bounds
widget.bounds = newBounds
hitTestSystem.updateWidget(widget, oldBounds)

# Option B: Automatic (convenience API we added)
hitTestSystem.updateWidgetBounds(widget, newBounds)
```

**Time Complexity**: O(k log n) where k = changed widgets

**Pros**:
- ✅ Fast when few widgets change
- ✅ Scales with changes, not total size
- ✅ 100x faster for single widget updates

**Cons**:
- ❌ Need to track old bounds
- ❌ More complex code
- ❌ Can get out of sync if not careful

**When to use**:
- Large UIs (100+ widgets)
- Animations (1-10 widgets moving)
- Scroll (content shifts but most widgets unchanged)
- Performance is critical

## Tracking Previous Bounds

Three approaches, each with trade-offs:

### Approach 1: Store in Widget (RECOMMENDED)

```nim
type Widget = ref object
  bounds: Rect
  previousBounds: Rect  # 16 bytes extra
```

**Cost**: 16 bytes per widget
- 100 widgets = 1.6 KB
- 1000 widgets = 16 KB
- 10000 widgets = 160 KB

**Benefits**:
- Always available when needed
- No extra tracking logic
- Simple to use

**Verdict**: ✅ **RECOMMENDED** - 16 bytes is negligible, simplicity is worth it

### Approach 2: Track in LayoutManager

```nim
type LayoutManager = object
  boundsChanges: Table[WidgetId, tuple[old, new: Rect]]
```

**Cost**: 32+ bytes per *changed* widget (only during layout)

**Benefits**:
- No memory cost when not in use
- Only allocate for dirty widgets
- Clean separation of concerns

**Verdict**: ⚠️ Good for minimal memory, but more complex

### Approach 3: No Tracking (Always Rebuild)

**Cost**: Zero extra memory

**Benefits**:
- Simplest possible
- Can't get out of sync

**Verdict**: ✅ Best for prototyping and small UIs

## Hybrid Strategy (RECOMMENDED)

Choose strategy based on percentage changed:

```nim
proc updateHitTesting(lm: var LayoutManager) =
  if dirtyCount > totalWidgets div 4:
    # >25% changed? Rebuild is actually faster
    hitTestSystem.rebuildFromWidgets(allWidgets)
  else:
    # Few changes? Incremental wins
    for widget in dirtyWidgets:
      hitTestSystem.updateWidget(widget, widget.previousBounds)
```

**Why 25% threshold?**

Performance analysis with 1000 widgets:

```
Rebuild:      O(n log n) = 1000 * 10 = ~10,000 operations
Incremental:  O(k log n) = k * 10

Break-even:   k * 10 = 10,000  →  k = 1000 (100%)
But incremental has overhead, so real break-even ~25%
```

## Why Dual Interval Trees? (Not QuadTree/R-Tree)

### Considered Alternatives

**QuadTree**:
- Recursively subdivides 2D space into quadrants
- Good for evenly distributed objects
- Complex to implement correctly
- Path-dependent performance (bad for clustered widgets)

**R-Tree**:
- Hierarchical bounding boxes
- Industry standard for GIS
- Complex insert/delete with rebalancing
- Overkill for UI use case

**K-D Tree**:
- Alternates splitting dimensions
- Doesn't maintain bounding info
- Poor for rectangle queries

### Why We Chose Dual Interval Trees

**Simplicity**:
- Two 1D problems easier than one 2D problem
- Well-understood AVL tree algorithm
- Each dimension independently balanced

**Performance**:
- O(log n) guaranteed by AVL balancing
- Set intersection is O(k) with HashSet
- Fast enough for UI (widgets rarely heavily overlap)

**Practicality**:
- UI widgets typically arranged in rows/columns
- Dual trees exploit this structure naturally
- Easy to debug and reason about

### Performance Comparison

Theoretical query complexity:

| Structure | Query | Insert | Remove | Balance |
|-----------|-------|--------|--------|---------|
| Dual Interval Trees | O(log n + k) | O(log n) | O(log n) | Automatic (AVL) |
| QuadTree | O(n) worst, O(log n) avg | O(log n) | O(log n) | Must rebuild |
| R-Tree | O(log n + k) | O(log n) | O(log n) | Complex |
| Naive Array | O(n) | O(1) | O(n) | N/A |

For UI with 1000 widgets:
- Dual trees: ~10 comparisons + k results
- Naive array: 1000 comparisons always

## Why AVL Trees? (Not Red-Black)

Both are balanced binary trees, but:

**AVL Trees**:
- Stricter balancing: height ≤ 1.44 log n
- Faster queries (fewer levels to traverse)
- Slower inserts (more rotations)
- Simpler to implement correctly

**Red-Black Trees**:
- Looser balancing: height ≤ 2 log n
- Faster inserts (fewer rotations)
- Slower queries (more levels)
- More complex implementation

**For UI Hit-Testing**:
- ✅ Queries happen every frame (60 FPS)
- ✅ Inserts happen during layout (maybe 10 FPS)
- ✅ **Query performance > Insert performance**
- ✅ AVL wins for our use case

## Z-Index Sorting

Results are sorted by z-index (highest first):

```nim
result.sort(proc(a, b: Widget): int =
  result = cmp(b.zIndex, a.zIndex)  # Note: b, a order for descending
)
```

**Why?**
- Mouse events go to topmost widget first
- Event bubbling goes from front to back
- Intuitive for users (top widget is "in front")

**Cost**: O(k log k) where k = number of hits
- Typically k < 5 (few overlapping widgets)
- Sorting 5 items is ~10 comparisons
- Negligible compared to tree query

## API Design: Two Flavors

We provide two update APIs:

### API 1: Manual (More Control)
```nim
let oldBounds = widget.bounds
widget.bounds = newBounds
system.updateWidget(widget, oldBounds)
```

**Use when**: You already have oldBounds in scope

### API 2: Automatic (More Convenient)
```nim
system.updateWidgetBounds(widget, newBounds)
```

**Use when**: You just want it to work

Both exist because different scenarios favor different APIs.

## Memory Usage

Per-widget cost in hit-testing system:

```
IntervalNode (X tree): 40 bytes
  - Interval: 12 bytes (start, fin, data=ptr)
  - maxEnd: 4 bytes
  - height: 4 bytes
  - left, right: 16 bytes (pointers)
  - padding: 4 bytes

IntervalNode (Y tree): 40 bytes (same)

Total: 80 bytes per widget

For 1000 widgets: 80 KB
For 10000 widgets: 800 KB
```

Plus Widget.previousBounds if we add it: +16 bytes per widget

**Conclusion**: Memory is not a concern for UI use case.

## Testing Philosophy

We test three levels:

1. **Unit Tests** (interval_tree.nim)
   - Individual tree operations
   - AVL balancing
   - Edge cases

2. **Integration Tests** (hittest_system.nim)
   - Dual tree interaction
   - Z-index sorting
   - Large-scale stress tests

3. **Visual Tests** (visual_test.nim)
   - Real-time interaction
   - Human verification
   - Performance monitoring

## Future Optimizations (If Needed)

### Query Caching
If consecutive queries are at same point:
```nim
var lastQuery: tuple[x, y: float32, result: seq[Widget]]
if x == lastQuery.x and y == lastQuery.y:
  return lastQuery.result
```
**Benefit**: Free for mouse hover
**Cost**: 24 bytes + result storage

### Batch Updates
If updating many widgets:
```nim
system.beginBatchUpdate()
for widget in dirtyWidgets:
  system.updateWidget(widget, oldBounds)
system.endBatchUpdate()  # Rebalance once at end
```
**Benefit**: Fewer rotations
**Cost**: Temporary tree imbalance

### Lazy Removal
Mark nodes as deleted instead of removing:
```nim
node.deleted = true  # Skip in queries
# Rebuild tree when deleted count > 25%
```
**Benefit**: Faster removes
**Cost**: More memory, more complex

**Verdict**: Not needed yet, premature optimization

## Lessons Learned

1. **Simple beats clever** - Dual trees beat fancier 2D structures
2. **Test before optimizing** - Full rebuild is "fast enough" for many cases
3. **Provide both simple and fast** - Strategy 1 for prototyping, Strategy 2 for production
4. **Memory is cheap** - 80 bytes per widget is negligible
5. **Visual tests catch bugs** - Interactive demo found issues unit tests missed

## Recommendations for RUI

### Phase 1: Initial Implementation
- Use full rebuild (Strategy 1)
- Don't add previousBounds yet
- Profile to see if it's a bottleneck
- **Goal**: Ship working hit-testing

### Phase 2: If Performance Issue
- Add Widget.previousBounds
- Implement hybrid strategy (Strategy 3)
- Use incremental updates during animations
- **Goal**: 60 FPS even with 1000+ widgets

### Phase 3: If Still Not Fast Enough
- Add query caching
- Implement batch updates
- Consider lazy removal
- **Goal**: 60 FPS with 10,000+ widgets

**Most likely**: Phase 1 is sufficient. Modern CPUs rebuild 1000 widgets in <1ms.

## The Real Answer

**Do we rebuild every time?**

**No, but you can if you want to.**

The system supports both:
- Rebuild when you want simplicity
- Incremental when you want performance
- Hybrid when you want both

**Recommended workflow**:

1. **Start simple**: Use rebuild everywhere
2. **Profile**: Find actual bottlenecks (probably not hit-testing!)
3. **Optimize**: Switch to incremental only where needed
4. **Ship**: Most UIs never need incremental updates

The beauty is you can start with Strategy 1 (simple) and add Strategy 2 (fast) later without changing the rest of your code!
