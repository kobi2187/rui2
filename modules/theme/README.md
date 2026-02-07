# Theme Module

State/intent-based theming with property merging, caching, and branding support.

## Public API

```nim
import modules/theme/api
```

### Core Types
- `Theme` — Complete theme with base/state overrides and branding
- `ThemeProps` — Visual properties (colors, borders, padding, effects, etc.)
- `ThemeState` — Normal, Disabled, Hovered, Pressed, Focused, Selected, DragOver
- `ThemeIntent` — Default, Info, Success, Warning, Danger
- `BevelStyle` — Flat, Raised, Sunken, Ridge, Groove, Soft, Convex, etc.
- `ThemeCache` — Performance cache for (intent, state) -> ThemeProps lookup

### Key Functions

| Function | Description |
|---|---|
| `newTheme(name)` | Create empty theme |
| `getThemeProps(theme, intent, state)` | Get merged properties |
| `merge(a, b: ThemeProps)` | Merge two property sets (b overrides a) |
| `makeThemeProps(...)` | Convenience constructor |
| `makeColor(r, g, b, a)` | Create Color from ints |
| `getOrCreateProps(cache, theme, intent, state)` | Cached lookup |

### Built-in Themes

| Name | Description |
|---|---|
| `createLightTheme()` | Modern light (Material-inspired) |
| `createDarkTheme()` | Modern dark |
| `createBeosTheme()` | Classic BeOS with 3D bevels |
| `createJoyTheme()` | Playful (rounded, vibrant) |
| `createWideTheme()` | Spacious (larger padding) |

### Testing Without Graphics

Theme lookup works headlessly. Colors are stub objects without `useGraphics`.

```nim
var theme = newTheme("Test")
let props = theme.getThemeProps(Default, Normal)
assert props.cornerRadius.isNone  # No defaults set
```

### Dependencies
- `core/types` (Color, EdgeInsets, Rect)
- `drawing_primitives/primitives/text` (TextStyle)
