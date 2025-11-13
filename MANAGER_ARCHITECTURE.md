# Manager Architecture - Functional Style

## Overview

The RUI2 framework uses a functional pipeline approach where each manager receives the widget tree, processes it, and passes it to the next stage. This ensures clear separation of concerns and makes the rendering pipeline easy to understand and optimize.

## Pipeline Stages

```
Widget Tree → Layout Manager → Hit-Test Manager → Render Manager → Display
```

### 1. Layout Manager

**Responsibility:** Calculate positions and sizes for all widgets

**Process:**
- Iterates through the widget tree
- Activates container layouts (VStack, HStack, etc.)
- Updates widget bounds (x, y, width, height)
- Sets `previousBounds` field for cache invalidation tracking
- Sets tree-global `layoutChanged` flag if any widget bounds changed

**Optimizations:**
- Skip layout if widget not dirty (`isDirty = false`)
- Skip if widget's constraints unchanged
- Use `previousBounds` to detect actual changes

**Output:**
- Updated widget tree with calculated bounds
- `layoutChanged` boolean flag

---

### 2. Hit-Test Manager

**Responsibility:** Build interval trees for efficient spatial queries (mouse position → widget lookup)

**Process:**
- Checks global `layoutChanged` flag
- If true: rebuild interval trees from scratch (simple, correct)
- If false: reuse existing trees (optimization)
- Builds separate trees for X and Y axes using interval_tree.nim
- Uses widget bounds to create intervals

**Optimizations:**
- Only rebuild if `layoutChanged = true`
- Could use `previousBounds` for incremental updates (future optimization)
- Currently: simple full rebuild when needed

**Output:**
- Interval trees for spatial queries
- Ready for mouse event routing

---

### 3. Render Manager

**Responsibility:** Draw individual widgets using Raylib

**Process:**
- Iterates through widget tree in draw order
- For each widget:
  - Check if dirty (`isDirty` flag)
  - Check if bounds changed (`bounds != previousBounds`)
  - If clean and bounds unchanged: use cached texture
  - If dirty or moved: redraw widget
  - Call widget's `render()` method
- Raylib composites draw calls to its own buffer

**Optimizations:**
- Texture caching for unchanged widgets
- `isDirty` flag prevents unnecessary redraws
- `previousBounds` check for cache invalidation
- Only redraw what changed

**Output:**
- Rendered frame via Raylib

---

## Dirty Flags and Cache Invalidation

### Widget-Level Flags

```nim
type Widget = ref object of RootObj
  bounds*: Rect
  previousBounds*: Rect  # For cache invalidation
  isDirty*: bool         # Widget state/props changed
  # ...
```

### Tree-Level Flags

```nim
type WidgetTree = object
  root*: Widget
  layoutChanged*: bool   # Any layout changed this frame
```

### Invalidation Rules

1. **Widget becomes dirty when:**
   - Props change (user input)
   - State changes (internal)
   - Parent forces redraw

2. **Cache is invalidated when:**
   - `isDirty = true`, OR
   - `bounds != previousBounds`

3. **Layout runs when:**
   - Any widget is dirty
   - Window resized
   - Tree structure changed

4. **Hit-test rebuilds when:**
   - `layoutChanged = true`

---

## Main Loop Integration

```nim
proc renderFrame(app: App) =
  # 1. Layout pass
  let layoutChanged = app.layoutManager.process(app.tree)
  app.tree.layoutChanged = layoutChanged

  # 2. Hit-test update (if needed)
  if layoutChanged:
    app.hitManager.rebuild(app.tree)

  # 3. Render pass
  app.renderManager.draw(app.tree)

  # 4. Reset flags for next frame
  app.tree.layoutChanged = false
```

---

## Design Principles

### 1. Functional Style
- Each manager is a pure function: `Tree → UpdatedTree`
- Managers don't store tree state (except caches)
- Clear input/output contracts

### 2. Simple Optimizations
- Use basic flags (`isDirty`, `layoutChanged`)
- Compare previous values (`previousBounds`)
- No complex dependency tracking
- Rebuild when unsure (correctness > performance)

### 3. Separation of Concerns
- Layout: spatial arrangement
- Hit-test: visual queries
- Render: drawing

### 4. Explicit Over Implicit
- Clear flag names
- Obvious invalidation rules
- Documented dependencies

---

## Future Optimizations (Optional)

1. **Incremental Hit-Test Updates**
   - Use `previousBounds` to update intervals in-place
   - Only rebuild affected subtrees

2. **Partial Layout**
   - Track which subtrees need layout
   - Skip unchanged branches

3. **Render Layers**
   - Separate static/dynamic content
   - Layer caching for compositing

**Note:** Keep optimizations simple. Correctness first, performance second.

---

## Implementation Status

- ✅ interval_tree.nim verified as best implementation (348 lines, tested)
- ✅ hittest_system.nim uses interval_tree.nim
- ⏳ Layout Manager: needs `layoutChanged` flag and `previousBounds` tracking
- ⏳ Hit-Test Manager: needs integration with layout pass
- ⏳ Render Manager: needs cache invalidation based on flags

---

## Next Steps

1. Add `previousBounds` field to Widget type
2. Add `layoutChanged` field to WidgetTree/App
3. Update layout pass to set flags
4. Integrate hit-test rebuild logic
5. Update render pass to check flags before drawing
