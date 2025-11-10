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

## Summary

**Required Fields**: Only `name` (all visual properties are optional)

**All Available Fields**:
- `backgroundColor` (color)
- `foregroundColor` (color)
- `borderColor` (color)
- `borderWidth` (float)
- `cornerRadius` (float)
- `padding` (float or object)
- `spacing` (float)
- `fontSize` (float)
- `fontFamily` (string)
- `textStyle` (object)

**Color Formats**: `#RRGGBB`, `#RRGGBBAA`, `rgb(r,g,b)`, `rgba(r,g,b,a)`

**Intent Types**: default, info, success, warning, danger

**State Types**: normal, disabled, hovered, pressed, focused, selected, dragOver

---

**Status**: ✅ Theme system complete and documented
