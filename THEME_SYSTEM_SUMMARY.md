# Theme System - Vision & Architecture

## Current State (from existing files)

### Core Concepts

**1. ThemeState** - Widget interaction states
- Normal, Disabled, Hovered, Pressed, Focused, Selected, DragOver

**2. ThemeIntent** - Semantic meaning
- Default, Info, Success, Warning, Danger

**3. ThemeProps** - Visual properties (all Optional)
```nim
backgroundColor, foregroundColor, borderColor
borderWidth, cornerRadius, padding, spacing
textStyle, fontSize
```

**4. Theme Structure**
```nim
Theme:
  name: string
  base: Table[ThemeIntent, ThemeProps]        # Base colors per intent
  states: Table[Intent, Table[State, Props]]  # State overrides
```

### Built-in Themes

Five base themes with different personalities:
1. **"light"** - Modern light theme
2. **"dark"** - Modern dark theme
3. **"beos"** - Classic BeOS (sharp corners, classic colors)
4. **"joy"** - Playful (very rounded, vibrant)
5. **"wide"** - Spacious (larger padding/spacing)

### Key Design Decisions

**Shared Theme Data**
- Single ThemeData instance shared across all widgets via pointer
- When theme changes, update pointer → all widgets see new theme
- No need to traverse tree updating each widget

**Property Merging**
- Themes inherit from base themes (e.g., "extends: light")
- Properties cascade: Base → Intent → State
- Only override what's different

**State-Based Rendering**
```nim
widget.state = if disabled: Disabled
              elif pressed: Pressed
              elif hovered: Hovered
              else: Normal

let props = theme.getThemeProps(widget.intent, widget.state)
drawRect(bounds, props.backgroundColor, props.cornerRadius)
```

**Performance: Theme Cache**
```nim
ThemeCache:
  cache: Table[(intent, state), ThemeProps]

# Pre-compute all combinations, reuse during render
```

## Integration with RUI2 Architecture

### Immediate Mode UI - No Reactivity Needed

Theme is queried every frame during render:

```nim
type App = object
  currentTheme*: Theme  # Simple value, no Link!

# When theme changes:
app.currentTheme = loadTheme("dark")
# Next frame: widgets query new theme values automatically
```

**Key Point**: Widgets ask "what color should I be?" every frame.
No dirty flags, no dependencies, no complexity.

### Theme is NOT part of Widget DSL

Theme is a **rendering helper**, separate from widget structure:

```nim
# Widgets DON'T have theme props - they just render
defineWidget(Button):
  props:
    text: string

  render:
    # Simple direct rendering
    drawRoundedRect(widget.bounds, 4.0, BLUE)
    drawText(widget.text, widget.bounds)

# Theme is used by DRAWING FUNCTIONS
proc drawThemedButton*(bounds: Rect, text: string, state: ThemeState, intent: ThemeIntent) =
  let props = getThemeProps(app.currentTheme, intent, state)
  drawRoundedRect(bounds, props.cornerRadius.get(4.0), props.backgroundColor.get(BLUE))
  drawText(text, bounds, props.textStyle.get(defaultStyle))
```

**Separation of Concerns**:
- Widget DSL: Structure, layout, events
- Theme System: Visual styling (colors, borders, etc.)
- Drawing Primitives: Low-level rendering

### With YAML-UI

```yaml
- button "Save":
    theme: "button.primary"    # Maps to Success intent
    on_click: save/0

- button "Delete":
    theme: "button.danger"     # Maps to Danger intent
    on_click: delete/0
```

## Implementation Plan

### Phase 1: Core Types (Already Exists!)
✅ ThemeState, ThemeIntent, ThemeProps
✅ Theme with base + states
✅ Property merging
✅ Built-in themes

### Phase 2: Integration with Link System
```nim
# Global app theme
var currentTheme*: Link[Theme]

# Widgets bind to theme
proc getThemedProps*(widget: Widget): ThemeProps =
  # This creates a dependency on currentTheme Link
  let theme = currentTheme.value
  let state = widget.getState()
  theme.getThemeProps(widget.intent, state)
```

### Phase 3: Widget Theme Support
- Add `intent: ThemeIntent` prop to widgets
- Widgets use `getThemedProps()` in render
- When theme Link changes → widgets re-render

### Phase 4: Theme Loading
```nim
proc loadTheme*(path: string): Theme =
  # Parse YAML/JSON theme file
  # Merge with base theme if "extends" specified

proc setTheme*(themeName: string) =
  currentTheme.value = BaseThemes[themeName]
  # All widgets marked dirty automatically!
```

### Phase 5: Advanced Features
- Theme hot-reloading
- Custom theme creation API
- Theme inheritance/composition
- Runtime theme switching with animation

## Example: Complete Themed Button

```nim
defineWidget(ThemedButton):
  props:
    text: string
    intent: ThemeIntent
    onClick: ButtonCallback

  init:
    widget.intent = Default
    widget.bounds.height = 40

  render:
    # Determine state
    let state = if not widget.enabled: Disabled
                elif widget.pressed: Pressed
                elif widget.hovered: Hovered
                elif widget.focused: Focused
                else: Normal

    # Get themed properties (creates Link dependency)
    let props = currentTheme.value.getThemeProps(widget.intent, state)

    # Render with theme
    drawRoundedRect(
      widget.bounds,
      props.cornerRadius.get(4.0),
      props.backgroundColor.get(GRAY),
      filled = true
    )

    if props.borderWidth.isSome and props.borderWidth.get > 0:
      drawRoundedRect(
        widget.bounds,
        props.cornerRadius.get(4.0),
        props.borderColor.get(BLACK),
        filled = false
      )

    let textStyle = props.textStyle.get(defaultTextStyle)
    drawText(widget.text, widget.bounds, textStyle, Center)

  on_click:
    if widget.onClick != nil:
      widget.onClick()
```

## Benefits

1. **Consistent Design** - All widgets follow theme automatically
2. **Runtime Switching** - Change theme → instant UI update
3. **Accessibility** - High contrast themes for readability
4. **Branding** - Custom themes per client/product
5. **User Choice** - Light/dark mode toggle
6. **State Feedback** - Hover/press states themed consistently

## Next Steps

1. ✅ Understand existing theme vision
2. Create Link-based theme system
3. Add theme support to existing widgets (Button, Label, etc.)
4. Create theme switching example
5. Test theme hot-reload
6. Document theme creation guide
