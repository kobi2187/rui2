# Focus Theme System - Usage Guide

## Overview

The theme system now supports focused state styling with dedicated visual properties:
- **focusRingColor**: Color of the focus ring/outline
- **focusRingWidth**: Width of the focus ring (pixels)
- **focusGlowRadius**: Optional glow/shadow radius
- **focusGlowColor**: Optional glow/shadow color

## Theme Configuration

### Built-in Themes

**Light Theme:**
```nim
result.states[Default][Focused] = makeThemeProps(
  borderColor = makeColor(66, 133, 244),      # Blue border when focused
  borderWidth = 2.0,
  focusRingColor = makeColor(66, 133, 244, 128),  # Semi-transparent blue ring
  focusRingWidth = 3.0
)
```

**Dark Theme:**
```nim
result.states[Default][Focused] = makeThemeProps(
  borderColor = makeColor(100, 181, 246),     # Lighter blue for dark backgrounds
  borderWidth = 2.0,
  focusRingColor = makeColor(100, 181, 246, 128),
  focusRingWidth = 3.0
)
```

## Widget Implementation

Widgets should query theme properties based on their focus state:

```nim
# In widget render/layout:
let state = if widget.focused: Focused else: Normal
let props = theme.getThemeProps(Default, state)

# Draw with focus styling
when defined(useGraphics):
  if widget.focused and props.focusRingColor.isSome:
    # Draw focus ring
    let ringColor = props.focusRingColor.get()
    let ringWidth = props.focusRingWidth.get(2.0)
    drawFocusRing(widget.bounds, ringColor, ringWidth)

  # Draw border (will use focused borderColor if set)
  if props.borderColor.isSome:
    drawBorder(widget.bounds, props.borderColor.get(), props.borderWidth.get(1.0))
```

## FocusManager Integration

The FocusManager automatically:
1. Sets `widget.focused = true` when widget gains focus
2. Sets `widget.focused = false` when widget loses focus
3. Triggers `onFocus`/`onBlur` callbacks for custom effects

Example using callbacks for theme-based effects:

```nim
var myInput = newTextInput()
myInput.onFocus = some(proc() {.closure.} =
  # Widget is now focused - theme will show focus ring
  myInput.isDirty = true  # Trigger re-render
)

myInput.onBlur = some(proc() {.closure.} =
  # Widget lost focus - theme will remove focus ring
  myInput.isDirty = true
)
```

## Custom Focus Effects

You can override the default focus appearance per widget:

```nim
# Custom focus ring for important inputs
let importantProps = makeThemeProps(
  focusRingColor = makeColor(255, 0, 0, 200),  # Red focus ring
  focusRingWidth = 4.0,
  focusGlowRadius = 8.0,
  focusGlowColor = makeColor(255, 0, 0, 100)   # Red glow
)

theme.states[Default][Focused] = importantProps
```

## Best Practices

1. **Always check widget.focused** when rendering/layouting
2. **Use theme queries** instead of hardcoded colors
3. **Mark widget dirty** in onFocus/onBlur to trigger re-render
4. **Test keyboard navigation** with Tab/Shift+Tab
5. **Ensure focus ring is visible** against all backgrounds

## Accessibility

Focus indicators are critical for keyboard navigation:
- Minimum 2px focus ring width recommended
- High contrast between focus ring and background
- Consider both light and dark theme variants
- Test with keyboard-only navigation
