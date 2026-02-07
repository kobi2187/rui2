# Drawing Primitives Module

Layered drawing system from low-level shapes to theme-aware widget rendering.

## Public API

```nim
import modules/drawing_primitives/api
```

### Layer 1: Shape Primitives (`primitives/`)

| Function | Description |
|---|---|
| `drawRect(rect, color)` | Filled rectangle |
| `drawRoundedRect(rect, radius, color)` | Rounded rectangle |
| `drawRoundedRectLines(rect, radius, width, color)` | Rounded outline |
| `drawLine(x1, y1, x2, y2, color, width)` | Line segment |
| `drawCircle(cx, cy, radius, color)` | Filled circle |
| `drawText(text, rect, style, align)` | Styled text |
| `measureText(text, style)` | Text metrics |
| `drawCheckmark(rect, color, width)` | Check mark |
| `drawRadioCircle(rect, selected, color)` | Radio indicator |
| `drawSlider(rect, value, color)` | Slider track+thumb |
| `drawProgressBar(rect, progress, fill, bg)` | Progress bar |
| `drawScrollbar(rect, content, view, offset, color)` | Scrollbar |
| `drawGroupBox(rect, title, style)` | Group box |

### Layer 2: Drawing Effects

| Function | Description |
|---|---|
| `drawBeveledRect(bounds, style, bg, ...)` | 3D bevel (BeOS/Win98) |
| `drawGradientRect(bounds, start, end, dir)` | Gradient fill |
| `drawShadowedRect(bounds, bg, ...)` | Drop shadow |
| `drawGlowRect(bounds, bg, glowColor, ...)` | Outer glow |
| `drawInsetRect(bounds, bg, ...)` | Inner shadow |
| `drawNeumorphicRect(bounds, base, ...)` | Soft UI/neumorphism |
| `drawThemedRect(bounds, props)` | Auto-select effect from ThemeProps |

### Layer 3: Widget Primitives (theme-aware)

| Function | Description |
|---|---|
| `drawButton(rect, text, props, ...)` | Themed button |
| `drawCheckbox(rect, checked, props, ...)` | Themed checkbox |
| `drawRadioButton(rect, selected, props, ...)` | Themed radio |
| `drawSlider(rect, value, min, max, props)` | Themed slider |
| `drawProgressBar(rect, progress, props)` | Themed progress |
| `drawMenuItem(rect, text, props, ...)` | Themed menu item |
| `drawListItem(rect, text, props, ...)` | Themed list item |
| `drawComboBox(rect, text, props, ...)` | Themed combo box |
| `drawTab(rect, text, props, ...)` | Themed tab |
| `drawGroupBox(rect, title, props)` | Themed group box |

### Dependencies
- `core/types` (Rect, Color, EdgeInsets)
- `theme` module (ThemeProps, BevelStyle)
- External: raylib
