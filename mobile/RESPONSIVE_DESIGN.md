## Responsive Design Guide

How to make your RUI app look good and work well across all screen sizes, from phones to tablets to desktop.

---

## The Problem

Simply scaling widgets proportionally causes real-world issues:

❌ **Text too small to read** on mobile
❌ **Buttons too small to tap** reliably
❌ **Wasted space** on tablets
❌ **Cramped layout** on phones
❌ **Poor readability** due to wrong line lengths
❌ **Inconsistent spacing** across devices

## The Solution

RUI's responsive sizing system provides:

✅ **DPI-aware sizing** - Accounts for screen density
✅ **Breakpoint-based adaptation** - Different sizes for phone/tablet/desktop
✅ **Touch target enforcement** - Guarantees minimum tap sizes
✅ **Text scale factors** - Readable text on all screens
✅ **Content width constraints** - Optimal reading experience
✅ **Adaptive spacing** - Comfortable layouts everywhere

---

## Quick Start

```nim
import mobile
import mobile/responsive

let display = initDisplayManager()

# Get responsive font size
let bodyFont = display.fontSize(fsBody)
let headingFont = display.fontSize(fsHeading)

# Get responsive spacing
let padding = display.sp(SpacingSizes.medium)
let margin = display.sp(SpacingSizes.large)

# Ensure touch target
let buttonHeight = display.ensureTouchTarget(40.0)

# Build responsive widget
Button:
  width: display.getConstrainedWidth(cwNarrow)
  height: buttonHeight
  fontSize: bodyFont
  padding: padding
```

---

## Core Concepts

### 1. Screen Size Categories

```nim
type ScreenSize* = enum
  ssCompact      # < 600dp (phone portrait)
  ssMedium       # 600-839dp (phone landscape, small tablet)
  ssExpanded     # >= 840dp (tablet, desktop)
```

**What to do:**
- **Compact**: Maximize content, minimal spacing, single column
- **Medium**: Add breathing room, 2-column layouts possible
- **Expanded**: Multi-column, generous spacing, constrain content width

### 2. DPI Scaling

Physical screens have different pixel densities:

- **1x**: Standard desktop monitors (~96 DPI)
- **2x**: Retina displays, most modern phones (~192 DPI)
- **3x**: High-end phones (~288 DPI)

**Always use logical sizes (dp), not pixels:**

```nim
# ✓ CORRECT - Logical pixels (dp)
let padding = display.dp(16.0)  # Converts to physical pixels

# ✗ WRONG - Hard-coded physical pixels
let padding = 16.0  # Will look tiny on retina displays!
```

### 3. Responsive Sizes

Define sizes that adapt to screen size:

```nim
type ResponsiveSize* = object
  compact*: float32      # Phone portrait
  medium*: float32       # Phone landscape / tablet
  expanded*: float32     # Desktop

# Example: Spacing that grows on larger screens
let spacing = ResponsiveSize(
  compact: 12.0,   # Tight spacing on phone
  medium: 16.0,    # More room on tablet
  expanded: 24.0   # Generous on desktop
)

# Get value for current screen
let actualSpacing = display.sp(spacing)
```

---

## Predefined Size Scales

Use these instead of hard-coding sizes:

### Spacing

```nim
# Use predefined spacing scale
let tiny = display.sp(SpacingSizes.tiny)      # 4dp all screens
let small = display.sp(SpacingSizes.small)    # 8-16dp adaptive
let medium = display.sp(SpacingSizes.medium)  # 16-24dp adaptive
let large = display.sp(SpacingSizes.large)    # 24-40dp adaptive
let xlarge = display.sp(SpacingSizes.xlarge)  # 32-64dp adaptive
```

### Font Sizes

```nim
# Use font size presets
let caption = display.fontSize(fsCaption)       # 12pt
let body = display.fontSize(fsBody)             # 14pt
let subheading = display.fontSize(fsSubheading) # 16pt
let heading = display.fontSize(fsHeading)       # 20pt
let title = display.fontSize(fsTitle)           # 24pt
let display = display.fontSize(fsDisplay)       # 34pt

# These automatically scale for:
# - Screen DPI
# - Screen size category
# - Text scale preference
```

### Button Heights

```nim
let buttonHeight = display.sp(ButtonHeights.medium)
# Compact: 48dp (perfect for thumbs)
# Medium: 52dp
# Expanded: 40dp (mouse is precise, can be smaller)
```

### Icon Sizes

```nim
let iconSize = display.sp(IconSizes.medium)
# Always properly sized for the screen
```

---

## Touch Targets

**Critical:** Touch targets must be large enough for fingers!

### Minimum Sizes

- **iOS HIG**: 44x44 points minimum
- **Android**: 48x48 dp minimum
- **RUI**: Uses 44dp as safe minimum

### Automatic Enforcement

```nim
# Ensure button meets minimum touch target
let buttonWidth = display.ensureTouchTarget(35.0)
# Returns: min(35, 44) = 44dp scaled for DPI

# For both dimensions
let (w, h) = display.ensureTouchTarget(width = 30, height = 32)
# Returns: (44, 44) - both enforced
```

### Adding Touch Padding

```nim
# Icon is 24dp, but need 44dp touch area
let iconSize = 24.0
let padding = display.touchTargetPadding(iconSize)
# Returns: (44 - 24) / 2 = 10dp of padding

IconButton:
  iconSize: iconSize
  padding: padding  # Now total touch area is 44dp
```

---

## Text Scaling

### Text Scale Factors

Adjust font sizes based on screen size:

```nim
# Default scale (balanced)
let scale = DefaultTextScale
# Compact: 1.0x (base size)
# Medium: 1.1x (10% larger)
# Expanded: 1.0x (base size)

# Mobile-first scale (more content on desktop)
let scale = MobileFirstTextScale
# Compact: 1.0x
# Medium: 0.95x
# Expanded: 0.9x (fit more text)

# Use custom scale
let customScale = TextScale(
  compact: 1.0,
  medium: 1.05,
  expanded: 0.95
)

# Apply to font size
let fontSize = display.getResponsiveFontSize(fsBody, customScale)
```

### Font Size Presets

```nim
type FontSizePreset* = enum
  fsCaption       # 12pt - Small secondary text
  fsBody          # 14pt - Regular body text
  fsSubheading    # 16pt - Section subheadings
  fsHeading       # 20pt - Section headings
  fsTitle         # 24pt - Page/screen titles
  fsDisplay       # 34pt - Large display text

# Usage
Label:
  text: "Section Heading"
  fontSize: display.fontSize(fsHeading)
  # Automatically adapts to:
  # - Screen DPI (2x, 3x)
  # - Screen size (phone vs tablet)
  # - Text scale preference
```

---

## Content Width Constraints

Long text lines are hard to read. Constrain content width:

```nim
type ContentWidth* = enum
  cwNarrow     # 600dp - Optimal for reading text
  cwMedium     # 900dp - Standard content
  cwWide       # 1200dp - Full width on large screens

# Get constrained width
let contentWidth = display.getConstrainedWidth(cwNarrow)
# On phone (400dp wide): Returns 400dp (full width)
# On tablet (800dp wide): Returns 600dp (constrained)
# On desktop (1400dp wide): Returns 600dp (constrained)

# Usage
VStack:
  width: display.getConstrainedWidth(cwNarrow)
  children:
    - Article text goes here...
    # Never too wide to read comfortably!
```

---

## Adaptive Layout Density

Control spacing based on screen size:

```nim
type LayoutDensity* = enum
  ldCompact      # Minimal spacing (phone)
  ldComfortable  # Balanced spacing (default)
  ldSpacious     # Extra spacing (tablet/desktop)

# Get recommended density for current screen
let density = display.getRecommendedDensity()
# Compact screen → ldCompact
# Medium screen → ldComfortable
# Expanded screen → ldSpacious

# Apply to spacing
let baseSpacing = 16.0
let adaptedSpacing = display.adaptSpacing(baseSpacing, density)
# Compact: 16 * 0.75 = 12dp
# Comfortable: 16 * 1.0 = 16dp
# Spacious: 16 * 1.5 = 24dp
```

---

## Responsive Patterns

### Pattern 1: Adaptive Font Sizes

```nim
# ✓ CORRECT - Adaptive
Label:
  text: "Hello World"
  fontSize: display.fontSize(fsBody)

# ✗ WRONG - Fixed
Label:
  text: "Hello World"
  fontSize: 14.0  # Too small on retina displays!
```

### Pattern 2: Adaptive Spacing

```nim
# ✓ CORRECT - Adaptive
VStack:
  spacing: display.sp(SpacingSizes.medium)
  padding: display.sp(SpacingSizes.large)

# ✗ WRONG - Fixed
VStack:
  spacing: 16.0  # Same on all screens
  padding: 24.0
```

### Pattern 3: Touch Target Enforcement

```nim
# ✓ CORRECT - Enforced
Button:
  height: display.ensureTouchTarget(36.0)  # Becomes 44dp
  # Comfortable to tap!

# ✗ WRONG - Too small
Button:
  height: 32.0  # Hard to tap on mobile!
```

### Pattern 4: Breakpoint-Based Layouts

```nim
# Different layouts for different screen sizes
proc buildLayout(display: DisplayManager): Widget =
  case display.getScreenSize()
  of ssCompact:
    # Phone: Single column, compact spacing
    VStack:
      spacing: display.sp(SpacingSizes.small)
      children:
        - Header
        - Content
        - Footer

  of ssMedium:
    # Tablet: Two columns
    HStack:
      spacing: display.sp(SpacingSizes.medium)
      children:
        - VStack:
            children: [Sidebar]
        - VStack:
            children: [Content]

  of ssExpanded:
    # Desktop: Three columns, constrained width
    HStack:
      spacing: display.sp(SpacingSizes.large)
      maxWidth: display.getConstrainedWidth(cwWide)
      children:
        - Sidebar
        - Content
        - ActionPanel
```

### Pattern 5: Aspect Ratio Handling

```nim
# Adjust layout for portrait vs landscape
if display.isPortrait():
  # Vertical layout
  VStack:
    children: [Image, Text, Buttons]
else:
  # Horizontal layout
  HStack:
    children:
      - Image
      - VStack: [Text, Buttons]
```

---

## Complete Example

```nim
import mobile
import mobile/responsive

proc buildResponsiveScreen(display: DisplayManager): Widget =
  let density = display.getRecommendedDensity()

  VStack:
    # Constrain width for readability
    width: display.getConstrainedWidth(cwMedium)

    # Adaptive spacing
    spacing: display.adaptSpacing(16.0, density)
    padding: display.sp(SpacingSizes.large)

    children:
      # Title
      - Label:
          text: "Welcome"
          fontSize: display.fontSize(fsTitle)

      # Body text
      - Label:
          text: "Your adaptive content here..."
          fontSize: display.fontSize(fsBody)
          lineHeight: 1.5

      # Button with touch target
      - Button:
          text: "Get Started"
          height: display.ensureTouchTarget(
            display.sp(ButtonHeights.medium)
          )
          fontSize: display.fontSize(fsBody)

      # Icon button with padding for touch
      - IconButton:
          icon: "settings"
          iconSize: display.sp(IconSizes.medium)
          padding: display.touchTargetPadding(
            display.sp(IconSizes.medium)
          )
```

---

## Debugging

### Print Responsive Info

```nim
display.printResponsiveInfo()
```

Output:
```
Responsive Sizing Info
======================
Screen size: ssCompact
DPI scale: 2.0x
Orientation: orPortrait
Aspect ratio: 0.56

Text scale factor: 1.0
Recommended density: ldCompact

Example sizes (logical → physical):
  44dp touch target → 88px
  16dp spacing → 32px
  14pt body text → 28px
  24pt heading → 48px
```

---

## Best Practices

### ✅ DO

1. **Use responsive size presets** instead of hard-coded values
2. **Enforce touch targets** for all interactive elements
3. **Constrain content width** on large screens for readability
4. **Scale fonts** based on screen size and DPI
5. **Test on all screen sizes** (compact, medium, expanded)
6. **Use logical sizes (dp)** not physical pixels

### ❌ DON'T

1. **Don't hard-code pixel sizes** - they won't adapt
2. **Don't assume screen size** - always check
3. **Don't make tiny touch targets** - minimum 44dp
4. **Don't use full width** for text on tablets
5. **Don't skip DPI scaling** - retina displays need it
6. **Don't use same layout** for all screens

---

## Checklist

Before shipping:

- [ ] All interactive elements ≥ 44dp touch target
- [ ] Font sizes use `display.fontSize()` or `display.sp()`
- [ ] Spacing uses `display.sp()` with responsive sizes
- [ ] Text content constrained to readable width (600-900dp)
- [ ] Tested on compact, medium, and expanded screens
- [ ] Tested with different DPI scales (1x, 2x, 3x)
- [ ] Portrait and landscape orientations work well
- [ ] No hard-coded pixel values (use dp instead)

---

## Migration from Fixed Sizes

**Before (Fixed):**
```nim
Label:
  fontSize: 14
  padding: 16

Button:
  height: 40
  fontSize: 14
```

**After (Responsive):**
```nim
Label:
  fontSize: display.fontSize(fsBody)
  padding: display.sp(SpacingSizes.medium)

Button:
  height: display.ensureTouchTarget(
    display.sp(ButtonHeights.medium)
  )
  fontSize: display.fontSize(fsBody)
```

---

## Summary

**Key insight**: Don't just resize containers - adapt the content!

- **Fonts** scale with screen size and DPI
- **Spacing** adapts to available space
- **Touch targets** meet minimum sizes
- **Content width** stays readable
- **Layouts** change structure for different screens

Use the responsive utilities, and your app will look great everywhere!
