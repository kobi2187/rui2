# Pango Rendering Stress Test

Comprehensive test for Pango rendering performance, flicker detection, and cache efficiency.

## Test File

`examples/pango_stress_test.nim` - 150 labels with dynamic updates across 4 test phases

## What It Tests

### 1. Performance Metrics
- **FPS**: Should maintain 60 FPS throughout
- **Frame Time**: Average, min, max measurements
- **Render Time**: Time spent in text rendering
- **Dropped Frames**: Frames that exceed 16.67ms (< 60 FPS)

### 2. Flicker Detection
- **Texture ID Tracking**: Monitors if texture ID changes between frames
- **Flicker Events**: Counts unexpected texture reallocations
- **Visual Indicators**: Red warning when flicker detected

### 3. Cache Performance
- **Cache Hits**: Text rendered from existing texture
- **Cache Misses**: Text that needed re-rendering
- **Hit Ratio**: Efficiency of caching system

### 4. Memory Stability
- **Texture Allocation**: Monitors texture creation/destruction
- **Memory Leaks**: Verifies proper cleanup

## Test Phases

The test progresses through 4 phases (5 seconds each):

### Phase 0: Static Rendering
- **Updates**: None
- **Purpose**: Baseline performance
- **Expected**: Perfect 60 FPS, no flickering

### Phase 1: Occasional Updates
- **Updates**: 5 labels/second
- **Purpose**: Light dynamic content
- **Expected**: 60 FPS, minimal cache misses

### Phase 2: Frequent Updates
- **Updates**: 20 labels per 100ms (200/sec)
- **Purpose**: Moderate stress
- **Expected**: 60 FPS, acceptable cache misses

### Phase 3: Continuous Updates
- **Updates**: 50 labels every frame (3000/sec)
- **Purpose**: Maximum stress
- **Expected**: Should stay above 45 FPS, some cache misses expected

## Visual Feedback

### Performance Panel (Top Right)
```
Test Phase:     3/3
Labels:         150
FPS:            60.0 (GREEN if >= 58)
Frame Time:     14ms (GREEN if <= 16)
Min Frame:      12ms
Max Frame:      18ms
Render Time:    3ms
Dropped Frames: 0 (GREEN if 0)
Flicker Events: 0 (GREEN if 0)
Cache Hits:     1250
Cache Misses:   45
```

### Phase Progress Bar
Green progress bar showing current phase advancement (0-5 seconds)

### Flicker Warning
Red banner at bottom when flicker detected in current frame

## Success Criteria

### Perfect Score
- ✓ 0 flicker events
- ✓ 0 dropped frames
- ✓ Average FPS >= 58
- ✓ Max frame time <= 18ms

### Good Score
- ✓ 0 flicker events
- ✓ < 10 dropped frames
- ✓ Average FPS >= 55

### Acceptable Score
- ✓ < 5 flicker events
- ✓ < 20 dropped frames
- ✓ Average FPS >= 50

### Failure
- ✗ Frequent flickering (> 5 events)
- ✗ Many dropped frames (> 20)
- ✗ Low FPS (< 50)

## Running the Test

```bash
# Compile with Pango support
nim c -d:useGraphics examples/pango_stress_test.nim

# Run the test
./examples/pango_stress_test

# Watch the console for phase transitions and final report
```

## Expected Output (Console)

```
=== Initializing 150 Labels ===
✓ Created 150 labels in 245ms

=== Starting Stress Test ===
Phase 0: Static rendering (no updates)
Phase 1: Occasional updates (1/sec)
Phase 2: Frequent updates (10/sec)
Phase 3: Continuous updates (every frame)

→ Phase 1: Occasional updates

→ Phase 2: Frequent updates

→ Phase 3: Continuous updates

=== FINAL PERFORMANCE REPORT ===
Total Frames: 1200
Average FPS: 59.8
Average Frame Time: 14ms
Min Frame Time: 12ms
Max Frame Time: 18ms
Dropped Frames: 2
Flicker Events: 0
Cache Hits: 2450
Cache Misses: 150

✓✓✓ PERFECT: No flickering, smooth 60 FPS!
```

## What to Look For

### Good Signs
1. **Smooth animation** - No stuttering or freezing
2. **No visual artifacts** - Text appears crisp and stable
3. **Consistent FPS** - Stays near 60 throughout
4. **Green metrics** - All performance indicators green

### Bad Signs
1. **Text flickering** - Visible flashing or redrawing
2. **Frame drops** - Stuttery animation
3. **Texture thrashing** - High cache misses with no updates
4. **Red warnings** - Performance panel shows red values

## Troubleshooting

### High Flicker Count
- **Cause**: Texture being recreated unnecessarily
- **Fix**: Improve cache invalidation logic
- **Check**: `shouldUpdateCache()` conditions

### Low FPS
- **Cause**: Too much time in rendering
- **Fix**: Optimize Pango→Cairo→Texture pipeline
- **Check**: Render time vs frame time

### Memory Issues
- **Cause**: Textures not being freed
- **Fix**: Verify `freeTextLayout()` calls
- **Check**: System memory during test

## Integration with RUI2

This test validates that Pango can be used for:
- **Label widgets** with dynamic text
- **TextInput widgets** with cursor updates
- **Rich text editors** with frequent changes
- **Real-time applications** requiring 60 FPS

## Next Steps

After passing stress test:
1. Integrate with Label widget
2. Add Pango option to TextInput
3. Create RichTextEditor widget
4. Benchmark vs Raylib text rendering
5. Add font caching system
