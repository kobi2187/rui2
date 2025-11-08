# Hit-Testing System Usage Guide

## When to Update the Hit-Testing System

The hit-testing system needs to be updated whenever widget bounds change. This happens primarily during:

1. **Layout calculations** - widgets get positioned/resized
2. **Widget creation/destruction** - widgets added/removed from tree
3. **Animations** - widgets moving/transforming

## Three Update Strategies

### Strategy 1: Full Rebuild (Simplest)

Use when many widgets changed or you don't track which widgets are dirty.

```nim
# After layout pass that may have changed any widget
hitTestSystem.rebuildFromWidgets(app.tree.getAllWidgets())
```

**Performance**: O(n log n) where n = total widgets

**When to use**:
- Initial setup
- Major layout changes (window resize, etc.)
- More than ~25% of widgets changed
- Simplicity is more important than performance

### Strategy 2: Incremental Updates (Fastest)

Use when you know exactly which widgets changed.

```nim
# Approach A: Update as you go during layout
for widget in widgetsToLayout:
  let oldBounds = widget.bounds

  # Layout logic sets new bounds
  widget.bounds = calculateNewBounds(widget)

  # Update hit-testing incrementally
  hitTestSystem.updateWidget(widget, oldBounds)
```

```nim
# Approach B: Convenient API that handles old bounds
for widget in widgetsToLayout:
  let newBounds = calculateNewBounds(widget)
  hitTestSystem.updateWidgetBounds(widget, newBounds)
```

**Performance**: O(k log n) where k = number of changed widgets

**When to use**:
- Only a few widgets changed
- You track dirty widgets explicitly
- Maximum performance needed

### Strategy 3: Hybrid (Recommended)

Choose strategy based on how many widgets changed.

```nim
type LayoutManager = object
  hitTestSystem: HitTestSystem
  dirtyWidgets: HashSet[Widget]
  totalWidgets: int

proc updateHitTesting(lm: var LayoutManager) =
  let dirtyCount = lm.dirtyWidgets.len

  if dirtyCount == 0:
    # Nothing to do
    return

  elif dirtyCount > lm.totalWidgets div 4:
    # More than 25% changed? Just rebuild
    # Rebuilding is actually faster at this point
    lm.hitTestSystem.rebuildFromWidgets(getAllWidgets())

  else:
    # Only a few changed - update incrementally
    for widget in lm.dirtyWidgets:
      # Assuming you tracked oldBounds somewhere
      lm.hitTestSystem.updateWidget(widget, widget.previousBounds)

  lm.dirtyWidgets.clear()
```

**When to use**:
- Production code where performance matters
- Variable number of changes per frame
- You want the best of both worlds

## Tracking Previous Bounds

For incremental updates, you need to know the old bounds. Here are your options:

### Option A: Store in Widget

```nim
type Widget = ref object
  bounds*: Rect
  previousBounds*: Rect  # For incremental hit-test updates
  # ... other fields
```

**Usage**:
```nim
# During layout
widget.previousBounds = widget.bounds  # Save before changing
widget.bounds = newBounds              # Calculate new
hitTestSystem.updateWidget(widget, widget.previousBounds)
```

**Pros**: Simple, always available
**Cons**: Extra 16 bytes per widget

### Option B: Track in LayoutManager

```nim
type LayoutManager = object
  hitTestSystem: HitTestSystem
  boundsChanges: Table[WidgetId, tuple[old, new: Rect]]
```

**Usage**:
```nim
# During layout - track changes
proc layoutWidget(lm: var LayoutManager, widget: Widget, newBounds: Rect) =
  lm.boundsChanges[widget.id] = (old: widget.bounds, new: newBounds)
  widget.bounds = newBounds
  # ... layout children

# After layout - apply all changes to hit-testing
proc finishLayout(lm: var LayoutManager) =
  for widgetId, change in lm.boundsChanges:
    let widget = getWidget(widgetId)
    lm.hitTestSystem.updateWidget(widget, change.old)
  lm.boundsChanges.clear()
```

**Pros**: No extra memory in Widget, only allocate when needed
**Cons**: More complex, need to track manually

### Option C: Use layoutDirty Flag + Full Rebuild

```nim
# Mark widgets dirty during changes
widget.layoutDirty = true

# After layout pass
if anyLayoutDirty:
  hitTestSystem.rebuildFromWidgets(allWidgets)
  clearAllLayoutDirtyFlags()
```

**Pros**: Simplest, no tracking needed
**Cons**: Always O(n log n) even if only 1 widget changed

## Complete Example: Layout Integration

Here's how to integrate with a layout system:

```nim
type
  LayoutManager = ref object
    hitTestSystem: HitTestSystem
    dirtyWidgets: seq[Widget]

  App = ref object
    tree: WidgetTree
    layoutManager: LayoutManager

proc layoutAndUpdateHitTesting(app: App) =
  let lm = app.layoutManager

  # Phase 1: Layout pass - calculate new bounds
  lm.dirtyWidgets.setLen(0)
  for widget in app.tree.root.walkTree():
    if widget.layoutDirty:
      lm.dirtyWidgets.add(widget)

      # Save old bounds
      let oldBounds = widget.bounds

      # Calculate new bounds (layout logic here)
      let newBounds = calculateLayout(widget)

      # Update widget
      widget.bounds = newBounds
      widget.layoutDirty = false

      # Update hit-testing immediately
      lm.hitTestSystem.updateWidget(widget, oldBounds)

# Or simpler version:
proc simpleLayoutAndUpdate(app: App) =
  # Do all layout calculations
  performLayoutPass(app.tree)

  # Then rebuild hit-testing
  # (Simple but slower if only a few widgets changed)
  app.layoutManager.hitTestSystem.rebuildFromWidgets(
    app.tree.getAllWidgets()
  )
```

## Performance Comparison

Assuming 1000 widgets on screen:

| Scenario | Rebuild | Incremental | Speedup |
|----------|---------|-------------|---------|
| 1 widget changed | 1.0ms | 0.01ms | 100x faster |
| 10 widgets changed | 1.0ms | 0.1ms | 10x faster |
| 100 widgets changed | 1.0ms | 0.8ms | ~1.2x faster |
| 500 widgets changed | 1.0ms | 1.5ms | Rebuild wins |

**Rule of thumb**: Incremental is faster when < 25% of widgets change.

## Widget Creation/Destruction

```nim
# Creating new widget
let widget = createWidget(bounds)
hitTestSystem.insertWidget(widget)

# Destroying widget
hitTestSystem.removeWidget(widget)
# Then remove from widget tree
```

## Common Patterns

### Pattern 1: Immediate Mode UI (Rebuild Every Frame)

```nim
# Simple and works fine for small UIs
proc render(app: App) =
  # Build/update widget tree
  buildWidgetTree(app)

  # Rebuild hit-testing (fast enough for <100 widgets)
  app.hitTestSystem.rebuildFromWidgets(app.tree.getAllWidgets())

  # Query for mouse hits
  let hits = app.hitTestSystem.findWidgetsAt(mouseX, mouseY)
```

### Pattern 2: Retained Mode UI (Incremental Updates)

```nim
# Efficient for large UIs with few changes per frame
proc update(app: App) =
  # Only update widgets that changed
  for widget in app.dirtyWidgets:
    let oldBounds = widget.bounds
    updateWidget(widget)
    app.hitTestSystem.updateWidget(widget, oldBounds)

  app.dirtyWidgets.clear()
```

### Pattern 3: Animation

```nim
# Animating a single widget
proc animateWidget(app: App, widget: Widget, dt: float) =
  let oldBounds = widget.bounds

  # Update animation
  widget.bounds.x += velocity * dt

  # Update hit-testing
  app.hitTestSystem.updateWidget(widget, oldBounds)
```

## Recommendations

### For RUI Framework:

1. **Store `previousBounds` in Widget** (Option A)
   - Simple, always available
   - 16 extra bytes per widget is negligible
   - Makes incremental updates trivial

2. **Use Hybrid Strategy** (Strategy 3)
   - Rebuild if >25% changed
   - Incremental otherwise
   - Best performance in all cases

3. **Layout Manager Workflow**:
   ```nim
   # During layout pass
   for widget in dirtyWidgets:
     widget.previousBounds = widget.bounds
     widget.bounds = calculateNewBounds(widget)

   # After layout pass
   updateHitTesting(layoutManager)  # Uses hybrid strategy
   ```

4. **Keep it Simple Initially**:
   - Start with full rebuild (Strategy 1)
   - Profile to see if it's a bottleneck
   - Add incremental updates only if needed
   - For most UIs, rebuild is fast enough!

## API Reference

```nim
# Creation
var system = newHitTestSystem()

# Widget management
system.insertWidget(widget)                        # Add widget
system.removeWidget(widget)                        # Remove widget
system.updateWidget(widget, oldBounds)             # Update (manual old bounds)
system.updateWidgetBounds(widget, newBounds)       # Update (automatic)
system.rebuildFromWidgets(widgets)                 # Rebuild entire system
system.clear()                                     # Remove all widgets

# Queries
let hits = system.findWidgetsAt(x, y)              # All widgets at point (sorted by z)
let overlaps = system.findWidgetsInRect(rect)      # All overlapping widgets
let top = system.findTopWidgetAt(x, y)             # Just the topmost widget

# Utilities
let count = system.len()                           # Number of widgets
let empty = system.isEmpty()                       # Check if empty
let valid = system.verifyIntegrity()               # Verify structure
let stats = system.getStats()                      # Performance stats
```

## Debugging Tips

```nim
# Verify hit-testing is working correctly
if not hitTestSystem.verifyIntegrity():
  echo "ERROR: Hit-testing system corrupted!"
  echo hitTestSystem.getStats()

# Check tree balance
echo hitTestSystem.getStats()
# Should show "X-tree balanced: true" and "Y-tree balanced: true"

# Test specific queries
let hits = hitTestSystem.findWidgetsAt(100, 100)
for widget in hits:
  echo &"Hit widget {widget.id} at z={widget.zIndex}"
```

## Summary

- **For simple UIs (<100 widgets)**: Use full rebuild, it's fast enough
- **For complex UIs (100-1000s widgets)**: Use hybrid strategy with incremental updates
- **Store previousBounds in Widget**: Simplest and most practical
- **Always verify integrity** during development to catch bugs early

The hit-testing system is designed to be flexible - start simple and optimize as needed!
