# RUI2 Theme YAML Specification

**Version**: 1.0
**Last Updated**: 2025-11-10

## Overview

RUI2 themes are defined in YAML files that specify visual properties for widgets. The theme system uses **intent-based styling** (Default, Info, Success, Warning, Danger) with **state overrides** (Normal, Disabled, Hovered, Pressed, etc.).

---

## File Structure

```yaml
name: theme-name
description: Optional theme description

base:
  default:
    # ThemeProps for Default intent, all states
  info:
    # ThemeProps for Info intent, all states
  success:
    # ThemeProps for Success intent, all states
  warning:
    # ThemeProps for Warning intent, all states
  danger:
    # ThemeProps for Danger intent, all states

states:
  default:
    normal:      # Base state
    disabled:    # Widget is disabled
    hovered:     # Mouse over widget
    pressed:     # Mouse button down on widget
    focused:     # Widget has keyboard focus
    selected:    # Widget is selected
    dragOver:    # Drag operation over widget
  info:
    # ... same states as default
  success:
    # ... same states as default
  warning:
    # ... same states as default
  danger:
    # ... same states as default
```

---

## Intent Types

Themes define properties for five intent levels:

| Intent | Purpose | Typical Usage |
|--------|---------|---------------|
| `default` | Normal UI elements | Standard buttons, panels, inputs |
| `info` | Informational elements | Info messages, hints, documentation |
| `success` | Positive feedback | Success messages, confirmations |
| `warning` | Caution/attention | Warnings, important notices |
| `danger` | Errors/destructive actions | Error messages, delete buttons |

---

## State Types

Each intent can have state-specific overrides:

| State | Triggered When | Example |
|-------|---------------|---------|
| `normal` | Default state | Button at rest |
| `disabled` | Widget is inactive | Disabled button |
| `hovered` | Mouse over widget | Button with cursor over it |
| `pressed` | Mouse button down | Button being clicked |
| `focused` | Keyboard focus | Text input being edited |
| `selected` | Item is selected | Selected list item |
| `dragOver` | Drag operation over widget | Drop target highlighted |

**Note**: States override base properties. If a state doesn't specify a property, it inherits from the base intent.

---

## ThemeProps Fields

All fields are **optional**. Unspecified fields inherit from parent theme or use widget defaults.

### Colors

#### `backgroundColor`
Background fill color for the widget.

**Formats**:
- Hex: `#RRGGBB` or `#RRGGBBAA`
- RGB: `rgb(r, g, b)` or `rgba(r, g, b, a)`

**Example**:
```yaml
backgroundColor: "#2E3440"
backgroundColor: "#2E3440FF"
backgroundColor: "rgb(46, 52, 64)"
backgroundColor: "rgba(46, 52, 64, 255)"
```

#### `foregroundColor`
Foreground/text color for the widget.

**Formats**: Same as `backgroundColor`

**Example**:
```yaml
foregroundColor: "#ECEFF4"
foregroundColor: "rgb(236, 239, 244)"
```

#### `borderColor`
Border outline color.

**Formats**: Same as `backgroundColor`

**Example**:
```yaml
borderColor: "#4C566A"
borderColor: "rgba(76, 86, 106, 255)"
```

---

### Dimensions

#### `borderWidth`
Width of the border in pixels.

**Type**: Float

**Example**:
```yaml
borderWidth: 1.0
borderWidth: 2.5
borderWidth: 0    # No border
```

#### `cornerRadius`
Radius for rounded corners in pixels.

**Type**: Float

**Example**:
```yaml
cornerRadius: 4.0   # Subtle rounding
cornerRadius: 12.0  # Pill-shaped
cornerRadius: 0     # Square corners
```

#### `spacing`
Spacing between child elements (for container widgets).

**Type**: Float

**Example**:
```yaml
spacing: 8.0
spacing: 16.0
spacing: 0    # No spacing
```

---

### Padding

#### `padding`
Internal padding within the widget.

**Formats**:
1. **Single value** (uniform padding on all sides):
```yaml
padding: 8.0
```

2. **Object** (individual sides):
```yaml
padding:
  top: 8.0
  right: 12.0
  bottom: 8.0
  left: 12.0
```

**Example - Uniform**:
```yaml
padding: 16.0  # All sides: 16px
```

**Example - Per-side**:
```yaml
padding:
  top: 4.0
  right: 8.0
  bottom: 4.0
  left: 8.0
```

---

### Text Properties

#### `fontSize`
Font size in pixels.

**Type**: Float

**Example**:
```yaml
fontSize: 14.0
fontSize: 20.0
fontSize: 12.0
```

#### `fontFamily`
Font family name (requires font to be installed).

**Type**: String

**Example**:
```yaml
fontFamily: "DejaVu Sans"
fontFamily: "Noto Sans"
fontFamily: "JetBrains Mono"
```

#### `textStyle`
Complete text style object (combines fontSize + fontFamily + color + maxWidth).

**Fields**:
- `fontFamily`: String
- `fontSize`: Float
- `color`: Color (hex or rgb)
- `maxWidth`: Float (for text wrapping)

**Example**:
```yaml
textStyle:
  fontFamily: "DejaVu Sans"
  fontSize: 14.0
  color: "#ECEFF4"
  maxWidth: 300.0
```

**Note**: If both `fontSize`/`fontFamily` and `textStyle` are specified, `textStyle` takes precedence.

---

### 3D Bevel Effects (Classic UIs)

For authentic BeOS, Windows 98, and classic Mac OS themes.

#### `bevelStyle`
Type of 3D bevel effect to apply.

**Values**:
- `Flat` - No bevel (default modern flat design)
- `Raised` - Classic 3D raised button (light top-left, dark bottom-right)
- `Sunken` - Pressed/inset appearance (dark top-left, light bottom-right)
- `Ridge` - Windows 98 panel ridge effect
- `Groove` - Windows 98 panel groove effect

**Example**:
```yaml
bevelStyle: Raised    # BeOS/Windows 98 style button
bevelStyle: Sunken    # Pressed button appearance
bevelStyle: Flat      # Modern flat design
```

#### `highlightColor`
Color for top-left bevel edge (light highlight).

**Type**: Color
**Default**: White (#FFFFFF)

**Example**:
```yaml
highlightColor: "#FFFFFF"    # Bright white highlight
highlightColor: "#F0F0F0"    # Subtle highlight
```

#### `shadowColor`
Color for bottom-right inner bevel edge.

**Type**: Color
**Default**: Gray (#808080)

**Example**:
```yaml
shadowColor: "#808080"    # Classic gray shadow
shadowColor: "#999999"    # Lighter shadow
```

#### `darkShadowColor`
Color for bottom-right outer bevel edge (darkest shadow).

**Type**: Color
**Default**: Black (#000000)

**Example**:
```yaml
darkShadowColor: "#000000"    # Deep black shadow
darkShadowColor: "#666666"    # Softer shadow
```

**Complete Bevel Example**:
```yaml
# Windows 98 Button
bevelStyle: Raised
backgroundColor: "#C0C0C0"
highlightColor: "#FFFFFF"
shadowColor: "#808080"
darkShadowColor: "#000000"
cornerRadius: 0.0    # Sharp corners

states:
  default:
    pressed:
      bevelStyle: Sunken    # Invert bevel when clicked!
```

---

### Gradient Effects (Modern UIs)

For Mac OS X Aqua, glossy buttons, and modern gradients.

#### `gradientStart`
Starting color for gradient fill.

**Type**: Color

**Example**:
```yaml
gradientStart: "#E0E8F0"    # Light blue top
```

#### `gradientEnd`
Ending color for gradient fill.

**Type**: Color

**Example**:
```yaml
gradientEnd: "#B0C0D0"    # Darker blue bottom
```

#### `gradientDirection`
Direction of gradient.

**Values**:
- `Vertical` - Top to bottom
- `Horizontal` - Left to right
- `Radial` - Center outward

**Example**:
```yaml
gradientDirection: Vertical    # Default
gradientDirection: Horizontal
gradientDirection: Radial
```

**Complete Gradient Example**:
```yaml
# Mac OS X Aqua Button
gradientStart: "#E0E8F0"
gradientEnd: "#B0C0D0"
gradientDirection: Vertical
borderColor: "#88A0B8"
borderWidth: 1.0
cornerRadius: 8.0

states:
  default:
    hovered:
      gradientStart: "#F0F8FF"    # Lighter on hover
      gradientEnd: "#C0D0E0"
```

---

### Shadow Effects (Depth and Elevation)

For modern flat design with depth.

#### `dropShadowOffset`
Offset of drop shadow from element.

**Type**: Tuple of (x, y) floats

**Example**:
```yaml
dropShadowOffset: [4.0, 4.0]      # Shadow 4px right and down
dropShadowOffset: [0.0, 8.0]      # Shadow directly below
dropShadowOffset: [-2.0, -2.0]    # Shadow up and left
```

#### `dropShadowBlur`
Blur radius of drop shadow (softness).

**Type**: Float
**Default**: 8.0

**Example**:
```yaml
dropShadowBlur: 4.0     # Sharp shadow
dropShadowBlur: 16.0    # Very soft shadow
dropShadowBlur: 0.0     # No blur (hard edge)
```

#### `dropShadowColor`
Color of drop shadow.

**Type**: Color
**Default**: Semi-transparent black

**Example**:
```yaml
dropShadowColor: "rgba(0, 0, 0, 0.3)"      # 30% black
dropShadowColor: "rgba(100, 100, 150, 0.2)" # Colored shadow
```

**Complete Shadow Example**:
```yaml
# Modern Elevated Card
backgroundColor: "#FFFFFF"
cornerRadius: 8.0
dropShadowOffset: [0.0, 4.0]
dropShadowBlur: 12.0
dropShadowColor: "rgba(0, 0, 0, 0.15)"
padding: 16.0
```

---

### Glow Effects (Focus and Highlights)

For welcoming focus states and soft highlights.

#### `glowColor`
Color of outer glow.

**Type**: Color

**Example**:
```yaml
glowColor: "#4A90E2"            # Blue glow
glowColor: "rgba(74, 144, 226, 0.5)"  # Semi-transparent blue
```

#### `glowRadius`
Radius of glow effect.

**Type**: Float
**Default**: 8.0

**Example**:
```yaml
glowRadius: 4.0     # Subtle glow
glowRadius: 16.0    # Strong glow
```

**Complete Glow Example**:
```yaml
# Focus State with Glow
states:
  default:
    focused:
      glowColor: "#4A90E2"
      glowRadius: 12.0
      borderColor: "#4A90E2"
      borderWidth: 2.0
```

---

### Inner Shadow Effects (Inset Depth)

For recessed elements and input fields.

#### `insetShadowDepth`
Depth of inner shadow in pixels.

**Type**: Float

**Example**:
```yaml
insetShadowDepth: 2.0    # Subtle inset
insetShadowDepth: 4.0    # Deeper inset
```

#### `insetShadowOpacity`
Opacity of inner shadow.

**Type**: Float (0.0 to 1.0)
**Default**: 0.2

**Example**:
```yaml
insetShadowOpacity: 0.1    # Very subtle
insetShadowOpacity: 0.4    # More pronounced
```

**Complete Inset Example**:
```yaml
# Recessed Input Field
backgroundColor: "#F5F5F5"
insetShadowDepth: 3.0
insetShadowOpacity: 0.2
borderColor: "#CCCCCC"
borderWidth: 1.0
cornerRadius: 4.0
padding: 8.0
```

---

## Complete Example Theme

```yaml
name: nord-dark
description: Nordic-inspired dark theme

base:
  default:
    backgroundColor: "#2E3440"
    foregroundColor: "#ECEFF4"
    borderColor: "#4C566A"
    borderWidth: 1.0
    cornerRadius: 4.0
    padding: 8.0
    spacing: 8.0
    fontSize: 14.0
    fontFamily: "DejaVu Sans"

  info:
    backgroundColor: "#5E81AC"
    foregroundColor: "#ECEFF4"
    borderColor: "#81A1C1"
    borderWidth: 1.0
    cornerRadius: 4.0
    padding: 8.0

  success:
    backgroundColor: "#A3BE8C"
    foregroundColor: "#2E3440"
    borderColor: "#8FBCBB"
    borderWidth: 1.0
    cornerRadius: 4.0
    padding: 8.0

  warning:
    backgroundColor: "#EBCB8B"
    foregroundColor: "#2E3440"
    borderColor: "#D08770"
    borderWidth: 1.0
    cornerRadius: 4.0
    padding: 8.0

  danger:
    backgroundColor: "#BF616A"
    foregroundColor: "#ECEFF4"
    borderColor: "#D08770"
    borderWidth: 1.0
    cornerRadius: 4.0
    padding: 8.0

states:
  default:
    normal:
      # Uses base.default

    hovered:
      backgroundColor: "#3B4252"
      borderColor: "#88C0D0"

    pressed:
      backgroundColor: "#434C5E"
      borderColor: "#81A1C1"

    focused:
      borderColor: "#88C0D0"
      borderWidth: 2.0

    disabled:
      backgroundColor: "#3B4252"
      foregroundColor: "#4C566A"
      borderColor: "#4C566A"

  info:
    hovered:
      backgroundColor: "#81A1C1"

    pressed:
      backgroundColor: "#4C7A9F"

  success:
    hovered:
      backgroundColor: "#B8D4A0"

    pressed:
      backgroundColor: "#8FAC70"

  warning:
    hovered:
      backgroundColor: "#F0D89F"

    pressed:
      backgroundColor: "#D9B76F"

  danger:
    hovered:
      backgroundColor: "#D5757E"

    pressed:
      backgroundColor: "#A94E56"
```

---

## Minimal Example Theme

You don't need to specify all fields. This is a valid minimal theme:

```yaml
name: simple-blue

base:
  default:
    backgroundColor: "#1E90FF"
    foregroundColor: "#FFFFFF"

states:
  default:
    hovered:
      backgroundColor: "#4169E1"
```

**Result**: All other properties (borders, padding, fonts) use widget defaults or inherit from built-in theme.

---

## Color Format Reference

### Hex Colors

**6-digit (RGB)**:
```yaml
color: "#FF5733"  # Red=FF, Green=57, Blue=33, Alpha=FF (opaque)
```

**8-digit (RGBA)**:
```yaml
color: "#FF573380"  # Red=FF, Green=57, Blue=33, Alpha=80 (50% transparent)
```

### RGB/RGBA Colors

**RGB (opaque)**:
```yaml
color: "rgb(255, 87, 51)"  # Red=255, Green=87, Blue=51
```

**RGBA (with transparency)**:
```yaml
color: "rgba(255, 87, 51, 128)"  # Red=255, Green=87, Blue=51, Alpha=128
```

---

## Property Inheritance

Properties are resolved in this order (last wins):

1. **Widget default** (hardcoded in widget implementation)
2. **Base theme for intent** (`base.default`, `base.info`, etc.)
3. **State override** (`states.default.hovered`, etc.)
4. **Widget instance override** (set programmatically)

**Example**:
```yaml
base:
  default:
    backgroundColor: "#2E3440"  # Base background
    borderWidth: 1.0

states:
  default:
    hovered:
      backgroundColor: "#3B4252"  # Overrides background when hovered
      # borderWidth still 1.0 (inherited from base)
```

---

## Usage in Code

### Loading a Theme

```nim
import theme_sys/theme_loader

# Load from YAML file
let theme = loadTheme("themes/my-theme.yaml")

# Apply to widget
myButton.theme = theme
myButton.intent = Info
```

### Accessing Theme Properties

```nim
# Get properties for current state
let props = theme.getProps(intent = Info, state = Hovered)

# Check individual properties
if props.backgroundColor.isSome:
  let bgColor = props.backgroundColor.get()
  drawRectangle(x, y, width, height, bgColor)
```

---

## Built-in Themes

RUI2 includes five built-in themes:

| Theme | Description |
|-------|-------------|
| `light` | Light mode, neutral colors |
| `dark` | Dark mode, low contrast |
| `beos` | BeOS-inspired classic look |
| `joy` | Colorful, playful theme |
| `wide` | Wide padding, spacious layout |

**Access built-in themes**:
```nim
import theme_sys/builtin_themes

let theme = getBuiltinTheme("dark")
```

---

## Validation Rules

1. **Color values**: Must be valid hex or rgb/rgba format
2. **Numeric values**: Must be non-negative (borderWidth, cornerRadius, spacing, fontSize, padding)
3. **Intent names**: Must be one of: `default`, `info`, `success`, `warning`, `danger`
4. **State names**: Must be one of: `normal`, `disabled`, `hovered`, `pressed`, `focused`, `selected`, `dragOver`
5. **Padding**: Can be single number or object with top/right/bottom/left

**Invalid**:
```yaml
backgroundColor: "not-a-color"  # ERROR: Invalid color format
borderWidth: -1.0              # ERROR: Negative value
```

---

## Best Practices

### 1. Define Base Colors First
```yaml
base:
  default:
    backgroundColor: "#FFFFFF"
    foregroundColor: "#000000"
    # ... other base properties
```

### 2. Use State Overrides Sparingly
Only override what changes:
```yaml
states:
  default:
    hovered:
      backgroundColor: "#F0F0F0"  # Only change background
      # All other properties inherited from base
```

### 3. Maintain Contrast
Ensure text is readable:
```yaml
# Good: High contrast
backgroundColor: "#2E3440"
foregroundColor: "#ECEFF4"

# Bad: Low contrast
backgroundColor: "#444444"
foregroundColor: "#555555"
```

### 4. Use Intent Colors Meaningfully
```yaml
success: "#A3BE8C"  # Green = positive
warning: "#EBCB8B"  # Yellow = caution
danger: "#BF616A"   # Red = danger/error
```

### 5. Test All States
Verify your theme for all common states:
- Normal (resting state)
- Hovered (mouse over)
- Pressed (clicked)
- Disabled (inactive)

---

## Branding System

Make your apps instantly recognizable with RUI2's comprehensive branding system. Create a bold, consistent visual identity across all your applications.

### Brand Color Palette

Define your company's color system separately from intent colors:

```yaml
brandPalette:
  primaryColor: "#FF6B35"        # Main brand color (logo, primary CTAs)
  secondaryColor: "#004E89"      # Supporting color
  accentColor: "#F7C545"         # Highlights, attention-grabbers
  neutralLight: "#F5F5F5"        # Light backgrounds
  neutralDark: "#333333"         # Dark text, icons
  surfaceColor: "#FFFFFF"        # Card/panel backgrounds
  errorColor: "#D32F2F"          # Custom error color
  successColor: "#388E3C"        # Custom success color
```

**Then reference brand colors in your theme:**
```yaml
base:
  default:
    backgroundColor: ${brandPalette.surfaceColor}
    foregroundColor: ${brandPalette.neutralDark}

  # Primary actions use brand color
  info:
    backgroundColor: ${brandPalette.primaryColor}
    foregroundColor: "#FFFFFF"
```

**Note**: Color references (`${...}`) are future planned feature. Currently set colors directly.

---

### Typography System

Create a consistent font hierarchy:

```yaml
typography:
  primaryFont: "Montserrat"      # Bold, modern - for headings/buttons
  secondaryFont: "Open Sans"     # Clean, readable - for body text
  monoFont: "JetBrains Mono"     # Code/monospace elements

  defaultWeight: Regular         # 400
  headingWeight: Bold            # 700

  lineHeight: 1.6                # Comfortable reading
  letterSpacing: 0.02            # Slight spacing for elegance
```

**Font Weights**:
- `Light` (300)
- `Regular` (400)
- `Medium` (500)
- `SemiBold` (600)
- `Bold` (700)
- `ExtraBold` (800)

**Usage in ThemeProps:**
```yaml
base:
  default:
    fontFamily: ${typography.secondaryFont}
    fontSize: 14.0
```

---

### Spacing/Scale System

Design tokens for consistent spacing across all widgets:

```yaml
spacing:
  baseUnit: 8.0                  # 8px grid system
  xs: 4.0                        # 0.5x base
  sm: 8.0                        # 1x base
  md: 16.0                       # 2x base
  lg: 24.0                       # 3x base
  xl: 32.0                       # 4x base
  xxl: 48.0                      # 6x base
```

**Benefits**:
- Rhythm and harmony in layouts
- Predictable sizing
- Easy to maintain consistency

**Usage:**
```yaml
base:
  default:
    padding: ${spacing.md}       # 16px
    spacing: ${spacing.sm}       # 8px between children

  # Headers get more breathing room
  heading:
    padding: ${spacing.lg}       # 24px
```

---

### Animation/Motion Settings

Define your app's motion personality:

```yaml
animation:
  durationFast: 150              # Quick feedback (ms)
  durationNormal: 250            # Standard transitions
  durationSlow: 400              # Dramatic entrances

  defaultEasing: EaseOut         # Smooth, natural feel
```

**Easing Options**:
- `Linear` - No easing, constant speed
- `EaseIn` - Slow start, fast end
- `EaseOut` - Fast start, slow end (most natural)
- `EaseInOut` - Slow start and end
- `Bounce` - Playful, energetic
- `Elastic` - Springy, attention-grabbing

**Brand Personality**:
- **Professional**: `EaseOut`, 250ms
- **Playful**: `Bounce`, 350ms
- **Instant/Snappy**: `Linear`, 100ms
- **Elegant**: `EaseInOut`, 400ms

---

### Brand Assets

Integrate custom visuals:

```yaml
assets:
  logoPath: "assets/acme-logo.png"
  iconPackPath: "assets/icons/"
  cursorPath: "assets/cursor.png"
  backgroundPattern: "assets/noise-texture.png"
  backgroundPatternOpacity: 0.05
```

**Logo**: Company logo displayed in app chrome
**Icon Pack**: Custom icon set matching brand style
**Cursor**: Branded cursor for immersive experience
**Background Pattern**: Subtle texture/noise for depth

---

### Theme Metadata

Document your theme:

```yaml
metadata:
  brandName: "Acme Corporation"
  version: "2.1.0"
  author: "Acme Design Team"
  website: "https://acme.com"
  description: "Official Acme brand theme for all products"
```

---

### Complete Branded Theme Example

```yaml
name: acme-brand
description: Official Acme Corporation brand theme

# Brand Identity
metadata:
  brandName: "Acme Corporation"
  version: "1.0.0"
  author: "Design Team"
  website: "https://acme.com"
  description: "Consistent branding across all Acme apps"

# Brand Colors
brandPalette:
  primaryColor: "#FF6B35"        # Acme Orange
  secondaryColor: "#004E89"      # Acme Navy
  accentColor: "#F7C545"         # Acme Gold
  neutralLight: "#F8F9FA"
  neutralDark: "#212529"
  surfaceColor: "#FFFFFF"

# Typography
typography:
  primaryFont: "Raleway"         # Acme's signature font
  secondaryFont: "Inter"
  monoFont: "Fira Code"
  defaultWeight: Regular
  headingWeight: Bold
  lineHeight: 1.6
  letterSpacing: 0.01

# Spacing System
spacing:
  baseUnit: 8.0
  xs: 4.0
  sm: 8.0
  md: 16.0
  lg: 24.0
  xl: 32.0
  xxl: 48.0

# Motion
animation:
  durationFast: 150
  durationNormal: 250
  durationSlow: 400
  defaultEasing: EaseOut

# Assets
assets:
  logoPath: "assets/acme-logo.svg"
  iconPackPath: "assets/acme-icons/"
  backgroundPattern: "assets/subtle-grid.png"
  backgroundPatternOpacity: 0.03

# Visual Style
base:
  default:
    backgroundColor: "#FFFFFF"
    foregroundColor: "#212529"
    borderColor: "#DEE2E6"
    borderWidth: 1.0
    cornerRadius: 8.0              # Soft, friendly
    fontSize: 14.0
    fontFamily: "Inter"            # Brand secondary font
    padding: 16.0                  # spacing.md
    spacing: 8.0                   # spacing.sm

    # Acme signature: subtle shadow
    dropShadowOffset: [0.0, 2.0]
    dropShadowBlur: 8.0
    dropShadowColor: "rgba(0, 0, 0, 0.08)"

  info:
    backgroundColor: "#FF6B35"     # Acme Orange
    foregroundColor: "#FFFFFF"
    cornerRadius: 20.0             # Pill-shaped for impact

  success:
    backgroundColor: "#38B000"     # Acme Green
    foregroundColor: "#FFFFFF"

  warning:
    backgroundColor: "#F7C545"     # Acme Gold
    foregroundColor: "#212529"

  danger:
    backgroundColor: "#DC3545"
    foregroundColor: "#FFFFFF"

states:
  default:
    hovered:
      dropShadowOffset: [0.0, 4.0]
      dropShadowBlur: 12.0
      dropShadowColor: "rgba(0, 0, 0, 0.12)"

    pressed:
      dropShadowOffset: [0.0, 1.0]
      dropShadowBlur: 4.0

    focused:
      glowColor: "#FF6B35"         # Acme Orange glow
      glowRadius: 8.0
      borderColor: "#FF6B35"
      borderWidth: 2.0

  info:
    hovered:
      backgroundColor: "#FF8555"   # Lighter orange

    pressed:
      backgroundColor: "#E55525"   # Darker orange
```

This creates a **complete brand identity** with:
- ✅ Signature colors (Acme Orange, Navy, Gold)
- ✅ Custom typography (Raleway headings)
- ✅ Consistent spacing (8px grid)
- ✅ Smooth animations (250ms ease-out)
- ✅ Recognizable style (pill buttons, orange glow)

**Result**: All Acme apps look and feel unified, instantly recognizable as part of the Acme family.

---

## Authentic OS Theme Examples

Complete themes that authentically recreate classic operating systems.

### BeOS R5 Theme

```yaml
name: beos-authentic
description: Authentic BeOS R5 look and feel

base:
  default:
    backgroundColor: "#D9D9D9"
    foregroundColor: "#000000"
    bevelStyle: Raised
    highlightColor: "#FFFFFF"
    shadowColor: "#999999"
    darkShadowColor: "#666666"
    cornerRadius: 0.0           # Sharp corners
    fontSize: 12.0
    fontFamily: "Noto Sans"     # Close to BeOS fonts
    padding:
      top: 4.0
      right: 6.0
      bottom: 4.0
      left: 6.0

states:
  default:
    pressed:
      bevelStyle: Sunken        # Invert bevel when clicked

    disabled:
      backgroundColor: "#CCCCCC"
      foregroundColor: "#999999"
```

### Windows 98 Theme

```yaml
name: windows-98-authentic
description: Classic Windows 98 look and feel

base:
  default:
    backgroundColor: "#C0C0C0"
    foregroundColor: "#000000"
    bevelStyle: Raised
    highlightColor: "#FFFFFF"
    shadowColor: "#808080"
    darkShadowColor: "#000000"
    cornerRadius: 0.0           # Sharp corners
    fontSize: 11.0
    fontFamily: "MS Sans Serif"
    padding: 4.0

states:
  default:
    pressed:
      bevelStyle: Sunken

    focused:
      borderColor: "#000000"
      borderWidth: 1.0

    disabled:
      backgroundColor: "#C0C0C0"
      foregroundColor: "#808080"
```

### Mac OS X Aqua Theme

```yaml
name: aqua-authentic
description: Mac OS X Aqua look and feel

base:
  default:
    gradientStart: "#E0E8F0"
    gradientEnd: "#B0C0D0"
    gradientDirection: Vertical
    foregroundColor: "#000000"
    borderColor: "#88A0B8"
    borderWidth: 1.0
    cornerRadius: 8.0           # Rounded Aqua buttons
    fontSize: 13.0
    fontFamily: "Lucida Grande"
    padding: 8.0

states:
  default:
    hovered:
      gradientStart: "#F0F8FF"
      gradientEnd: "#C0D0E0"

    pressed:
      gradientStart: "#B0C0D0"
      gradientEnd: "#88A0B8"

    focused:
      borderColor: "#4A90E2"
      borderWidth: 3.0          # Aqua focus ring
      glowColor: "#4A90E2"
      glowRadius: 4.0
```

### Modern Material Design Theme

```yaml
name: material-modern
description: Google Material Design inspired

base:
  default:
    backgroundColor: "#FFFFFF"
    foregroundColor: "#212121"
    cornerRadius: 4.0
    fontSize: 14.0
    fontFamily: "Roboto"
    padding: 12.0
    dropShadowOffset: [0.0, 2.0]
    dropShadowBlur: 4.0
    dropShadowColor: "rgba(0, 0, 0, 0.2)"

  info:
    backgroundColor: "#2196F3"
    foregroundColor: "#FFFFFF"

  success:
    backgroundColor: "#4CAF50"
    foregroundColor: "#FFFFFF"

  warning:
    backgroundColor: "#FF9800"
    foregroundColor: "#FFFFFF"

  danger:
    backgroundColor: "#F44336"
    foregroundColor: "#FFFFFF"

states:
  default:
    hovered:
      dropShadowOffset: [0.0, 4.0]
      dropShadowBlur: 8.0
      dropShadowColor: "rgba(0, 0, 0, 0.3)"

    pressed:
      dropShadowOffset: [0.0, 1.0]
      dropShadowBlur: 2.0
      dropShadowColor: "rgba(0, 0, 0, 0.2)"

    focused:
      glowColor: "#2196F3"
      glowRadius: 8.0
```

### Neumorphic Theme (Calming Soft UI)

```yaml
name: neumorphic-soft
description: Soft UI for calming applications

base:
  default:
    backgroundColor: "#E0E5EC"
    foregroundColor: "#4A5568"
    cornerRadius: 12.0
    fontSize: 14.0
    fontFamily: "Inter"
    padding: 16.0
    # Neumorphism uses dual shadows
    dropShadowOffset: [6.0, 6.0]
    dropShadowBlur: 12.0
    dropShadowColor: "rgba(163, 177, 198, 0.6)"
    # Plus a light highlight shadow (use glow for this)
    glowColor: "#FFFFFF"
    glowRadius: 4.0

states:
  default:
    pressed:
      insetShadowDepth: 4.0
      insetShadowOpacity: 0.3
```

---

## Summary

**Required Fields**: Only `name` (all visual properties are optional)

**All Available Fields**:

### ThemeProps (Per Intent/State)

**Basic**:
- `backgroundColor` (color)
- `foregroundColor` (color)
- `borderColor` (color)
- `borderWidth` (float)
- `cornerRadius` (float)
- `padding` (float or object)
- `spacing` (float)

**Text**:
- `fontSize` (float)
- `fontFamily` (string)
- `textStyle` (object)

**3D Bevel** (Classic UIs):
- `bevelStyle` (Flat/Raised/Sunken/Ridge/Groove)
- `highlightColor` (color)
- `shadowColor` (color)
- `darkShadowColor` (color)

**Gradients** (Modern UIs):
- `gradientStart` (color)
- `gradientEnd` (color)
- `gradientDirection` (Vertical/Horizontal/Radial)

**Shadows** (Depth):
- `dropShadowOffset` ([x, y])
- `dropShadowBlur` (float)
- `dropShadowColor` (color)

**Glow** (Focus):
- `glowColor` (color)
- `glowRadius` (float)

**Inner Shadow** (Inset):
- `insetShadowDepth` (float)
- `insetShadowOpacity` (float)

### Branding System (Theme-Wide)

**Brand Palette**:
- `brandPalette.primaryColor` (color)
- `brandPalette.secondaryColor` (color)
- `brandPalette.accentColor` (color)
- `brandPalette.neutralLight` (color)
- `brandPalette.neutralDark` (color)
- `brandPalette.surfaceColor` (color)
- `brandPalette.errorColor` (color)
- `brandPalette.successColor` (color)

**Typography**:
- `typography.primaryFont` (string)
- `typography.secondaryFont` (string)
- `typography.monoFont` (string)
- `typography.defaultWeight` (Light/Regular/Medium/SemiBold/Bold/ExtraBold)
- `typography.headingWeight` (Light/Regular/Medium/SemiBold/Bold/ExtraBold)
- `typography.lineHeight` (float)
- `typography.letterSpacing` (float)

**Spacing**:
- `spacing.baseUnit` (float)
- `spacing.xs`, `spacing.sm`, `spacing.md`, `spacing.lg`, `spacing.xl`, `spacing.xxl` (float)

**Animation**:
- `animation.durationFast` (ms)
- `animation.durationNormal` (ms)
- `animation.durationSlow` (ms)
- `animation.defaultEasing` (Linear/EaseIn/EaseOut/EaseInOut/Bounce/Elastic)

**Assets**:
- `assets.logoPath` (string)
- `assets.iconPackPath` (string)
- `assets.cursorPath` (string)
- `assets.backgroundPattern` (string)
- `assets.backgroundPatternOpacity` (float)

**Metadata**:
- `metadata.brandName` (string)
- `metadata.version` (string)
- `metadata.author` (string)
- `metadata.website` (string)
- `metadata.description` (string)

---

### Reference Tables

**Color Formats**: `#RRGGBB`, `#RRGGBBAA`, `rgb(r,g,b)`, `rgba(r,g,b,a)`

**Intent Types**: default, info, success, warning, danger

**State Types**: normal, disabled, hovered, pressed, focused, selected, dragOver

**Bevel Styles**: Flat, Raised, Sunken, Ridge, Groove

**Gradient Directions**: Vertical, Horizontal, Radial

**Font Weights**: Light (300), Regular (400), Medium (500), SemiBold (600), Bold (700), ExtraBold (800)

**Animation Easings**: Linear, EaseIn, EaseOut, EaseInOut, Bounce, Elastic

---

**Status**: ✅ Theme system with visual effects and branding complete and documented
