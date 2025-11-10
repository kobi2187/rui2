# Global App with Theme Integration

## Overview

Integration of global app singleton with existing theme system for immediate-mode theme access in all widgets.

## Existing Components

RUI2 already has:
1. **App type** (`core/app.nim`) - Application state and main loop
2. **Theme system** (`drawing_primitives/theme_sys_core.nim`) - Complete theme framework
3. **Widget DSL v2** (`core/widget_dsl_v2.nim`) - Macro-based widget creation

## Integration Design

### 1. Add Theme to App

Enhance existing `App` type with theme support:

```nim
# core/app.nim (add to existing App type)
type
  App* = ref object
    # ... existing fields ...

    # Theme system (NEW)
    currentTheme*: Theme              # Active theme
    themeCache*: ThemeCache          # Performance cache
    themes*: Table[string, Theme]    # Available themes

# Add theme management functions
proc setTheme*(app: App, themeName: string)
proc registerTheme*(app: App, name: string, theme: Theme)
proc createDefaultThemes*(app: App)
```

### 2. Create Global App Instance

```nim
# core/app.nim (add at module level)

# Global app singleton - accessible from anywhere
var app*: App

# Or for thread-safety (uncomment if needed):
# threadvar app*: App

proc initGlobalApp*(...) =
  ## Initialize the global app instance
  app = newApp(...)
  app.createDefaultThemes()
  # ... rest of initialization
```

### 3. Widget Theme Access Pattern

Widgets access theme directly via global `app`:

```nim
# Before (hardcoded colors ❌)
definePrimitive(Button):
  render:
    DrawRectangle(
      widget.bounds,
      Color(r: 200, g: 200, b: 200, a: 255)  # Hardcoded!
    )

# After (theme-based ✅)
definePrimitive(Button):
  render:
    let props = app.currentTheme.getThemeProps(
      intent = widget.intent,
      state = widget.getCurrentState()
    )

    DrawRectangle(
      widget.bounds,
      props.backgroundColor.get(app.currentTheme.base[Default].backgroundColor.get())
    )
```

### 4. Convenience Template Pattern

Add convenience templates for common theme access:

```nim
# core/theme_helpers.nim (NEW FILE)

import app
import ../drawing_primitives/theme_sys_core

template themeProps*(intent: ThemeIntent = Default,
                     state: ThemeState = Normal): ThemeProps =
  ## Quick access to theme properties
  app.currentTheme.getThemeProps(intent, state)

template themeBgColor*(intent: ThemeIntent = Default,
                       state: ThemeState = Normal): Color =
  ## Quick access to background color
  themeProps(intent, state).backgroundColor.get(makeColor(255, 255, 255))

template themeFgColor*(intent: ThemeIntent = Default,
                       state: ThemeState = Normal): Color =
  ## Quick access to foreground color
  themeProps(intent, state).foregroundColor.get(makeColor(0, 0, 0))

template themeFontSize*(intent: ThemeIntent = Default,
                        state: ThemeState = Normal): float32 =
  ## Quick access to font size
  themeProps(intent, state).fontSize.get(14.0)

# Usage in widgets:
definePrimitive(Button):
  render:
    DrawRectangle(widget.bounds, themeBgColor(Default, widget.state))
    DrawText(widget.text, themeFontSize(), themeFgColor())
```

## Implementation Steps

### Step 1: Enhance core/app.nim

```nim
# core/app.nim

import ../drawing_primitives/theme_sys_core

type
  App* = ref object
    # Existing fields...
    tree*: WidgetTree
    store*: Store
    window*: WindowConfig
    eventManager*: EventManager

    # Theme system (NEW)
    currentTheme*: Theme
    themeCache*: ThemeCache
    themes*: Table[string, Theme]

    # ... rest of existing fields

# Global singleton
var app*: App

proc createDefaultThemes*(app: App) =
  ## Create and register default themes
  var lightTheme = newTheme("light")
  # Configure light theme...
  app.themes["light"] = lightTheme

  var darkTheme = newTheme("dark")
  # Configure dark theme...
  app.themes["dark"] = darkTheme

  var highContrastTheme = newTheme("high-contrast")
  # Configure high contrast theme...
  app.themes["high-contrast"] = highContrastTheme

  # Set default
  app.currentTheme = lightTheme

proc setTheme*(app: App, themeName: string) =
  ## Switch to a different theme
  ## Changes apply immediately (immediate mode)
  if themeName in app.themes:
    app.currentTheme = app.themes[themeName]
    app.themeCache = ThemeCache()  # Clear cache
    echo "Theme changed to: ", themeName
  else:
    echo "Warning: Theme not found: ", themeName

proc registerTheme*(app: App, name: string, theme: Theme) =
  ## Register a custom theme
  app.themes[name] = theme
  echo "Theme registered: ", name

proc newApp*(title = "RUI Application", ...): App =
  result = App(
    # ... existing initialization ...

    # Theme initialization
    currentTheme: newTheme("default"),
    themeCache: ThemeCache(),
    themes: initTable[string, Theme]()
  )

  # Create default themes
  result.createDefaultThemes()

  # Set global instance
  app = result
```

### Step 2: Create core/theme_helpers.nim

```nim
## Theme Helper Templates
##
## Convenience templates for quick theme access in widgets

import app
import ../drawing_primitives/theme_sys_core

template themeProps*(intent: ThemeIntent = Default,
                     state: ThemeState = Normal): ThemeProps =
  app.currentTheme.getThemeProps(intent, state)

template themeBgColor*(intent: ThemeIntent = Default,
                       state: ThemeState = Normal): Color =
  themeProps(intent, state).backgroundColor.get(makeColor(255, 255, 255))

template themeFgColor*(intent: ThemeIntent = Default,
                       state: ThemeState = Normal): Color =
  themeProps(intent, state).foregroundColor.get(makeColor(0, 0, 0))

template themeBorderColor*(intent: ThemeIntent = Default,
                           state: ThemeState = Normal): Color =
  themeProps(intent, state).borderColor.get(makeColor(200, 200, 200))

template themeBorderWidth*(intent: ThemeIntent = Default,
                           state: ThemeState = Normal): float32 =
  themeProps(intent, state).borderWidth.get(1.0)

template themeCornerRadius*(intent: ThemeIntent = Default,
                            state: ThemeState = Normal): float32 =
  themeProps(intent, state).cornerRadius.get(4.0)

template themeFontSize*(intent: ThemeIntent = Default,
                        state: ThemeState = Normal): float32 =
  themeProps(intent, state).fontSize.get(14.0)

template themeFontFamily*(intent: ThemeIntent = Default,
                          state: ThemeState = Normal): string =
  themeProps(intent, state).fontFamily.get("")
```

### Step 3: Update Widget Template

Add helper methods to widgets for state detection:

```nim
# In widget_dsl_v2.nim or as mixin

proc getCurrentState*(widget: WidgetType): ThemeState =
  ## Determine current theme state based on widget state
  if widget.disabled:
    return Disabled
  elif widget.pressed:
    return Pressed
  elif widget.focused:
    return Focused
  elif widget.hovered:
    return Hovered
  elif widget.selected:
    return Selected
  else:
    return Normal
```

### Step 4: Refactor Example Widget (Checkbox)

**Before:**
```nim
# widgets/basic/checkbox.nim
definePrimitive(Checkbox):
  props:
    text: string = ""
    disabled: bool = false

  state:
    checked: bool
    hovered: bool

  render:
    when defined(useGraphics):
      # Hardcoded colors ❌
      DrawRectangle(
        widget.bounds,
        Color(r: 240, g: 240, b: 240, a: 255)
      )
```

**After:**
```nim
# widgets/basic/checkbox.nim
import ../../core/theme_helpers

definePrimitive(Checkbox):
  props:
    text: string = ""
    disabled: bool = false
    intent: ThemeIntent = Default  # NEW: semantic intent

  state:
    checked: bool
    hovered: bool
    pressed: bool

  render:
    when defined(useGraphics):
      # Determine current state
      let state = if widget.disabled: Disabled
                  elif widget.pressed: Pressed
                  elif widget.hovered: Hovered
                  else: Normal

      # Get theme properties for this state ✅
      let bgColor = themeBgColor(widget.intent, state)
      let fgColor = themeFgColor(widget.intent, state)
      let borderColor = themeBorderColor(widget.intent, state)
      let borderWidth = themeBorderWidth(widget.intent, state)
      let cornerRadius = themeCornerRadius(widget.intent, state)

      # Draw using theme colors
      DrawRectangleRounded(
        widget.bounds,
        cornerRadius,
        16,
        bgColor
      )

      DrawRectangleRoundedLines(
        widget.bounds,
        cornerRadius,
        16,
        borderWidth,
        borderColor
      )

      DrawText(
        widget.text.cstring,
        (widget.bounds.x + 30.0).cint,
        (widget.bounds.y + 5.0).cint,
        themeFontSize(widget.intent, state).cint,
        fgColor
      )
```

## Usage Examples

### Basic Application

```nim
import core/app
import core/theme_helpers

# Initialize app with theme support
proc main() =
  let myApp = newApp(
    title = "My RUI2 App",
    width = 1200,
    height = 800
  )

  # App is now available globally via `app` variable
  echo "Current theme: ", app.currentTheme.name

  # Create UI with themed widgets
  let mainView = VStack:
    Label(text = "Hello RUI2")  # Uses theme colors automatically
    Button(text = "Click Me", intent = Success)  # Green success button
    Button(text = "Delete", intent = Danger)     # Red danger button

  # Switch theme at runtime
  app.setTheme("dark")  # All widgets update immediately!

  # Run app
  myApp.run()
```

### Theme Switching UI

```nim
# Theme switcher widget
defineWidget(ThemeSwitcher):
  render:
    HStack(spacing = 10):
      Button(
        text = "Light",
        onClick = proc() = app.setTheme("light")
      )
      Button(
        text = "Dark",
        onClick = proc() = app.setTheme("dark")
      )
      Button(
        text = "High Contrast",
        onClick = proc() = app.setTheme("high-contrast")
      )
```

### Custom Theme

```nim
# Create custom theme
var myTheme = newTheme("my-custom")

# Configure base properties
myTheme.base[Default] = ThemeProps(
  backgroundColor: some(makeColor(250, 250, 250)),
  foregroundColor: some(makeColor(30, 30, 30)),
  fontSize: some(16.0),
  cornerRadius: some(8.0)
)

# Configure success intent
myTheme.base[Success] = ThemeProps(
  backgroundColor: some(makeColor(76, 175, 80)),
  foregroundColor: some(makeColor(255, 255, 255))
)

# Configure hover state for success
myTheme.states[Success][Hovered] = ThemeProps(
  backgroundColor: some(makeColor(56, 142, 60))
)

# Register and activate
app.registerTheme("my-custom", myTheme)
app.setTheme("my-custom")
```

## Migration Strategy

### Phase 1: Add Theme Support to App (Week 1)
- [ ] Enhance `core/app.nim` with theme fields
- [ ] Create `core/theme_helpers.nim`
- [ ] Add default theme definitions
- [ ] Test theme switching

### Phase 2: Refactor Existing Widgets (Week 2)
- [ ] Add `intent` prop to all widgets
- [ ] Replace hardcoded colors with theme calls
- [ ] Test visual consistency
- [ ] Update examples

### Phase 3: Create Theme Presets (Week 3)
- [ ] Design light theme
- [ ] Design dark theme
- [ ] Design high-contrast theme
- [ ] Design colorblind-friendly themes

### Phase 4: Advanced Features (Week 4)
- [ ] Theme hot-reload from files
- [ ] Theme editor widget
- [ ] Save/load user preferences
- [ ] Theme transition animations

## Benefits

1. **No Hardcoded Values** ✅
   - All colors, fonts, sizes from theme
   - Easy to maintain and change

2. **Immediate Mode** ✅
   - Changes apply instantly
   - No cache invalidation needed
   - Simple mental model

3. **Semantic Intents** ✅
   - Success (green), Danger (red), etc.
   - Consistent visual language
   - Accessibility built-in

4. **Global Access** ✅
   - Available anywhere via `app`
   - No prop drilling
   - Simple to use

5. **Performance** ✅
   - Theme cache for computed properties
   - Fast lookups
   - Minimal overhead

## Testing

```nim
# tests/test_theme_integration.nim

suite "Theme Integration":
  test "Global app has theme":
    let myApp = newApp()
    check myApp.currentTheme.name == "light"
    check app.currentTheme.name == "light"  # Global access

  test "Theme switching works":
    let myApp = newApp()
    app.setTheme("dark")
    check app.currentTheme.name == "dark"

  test "Theme helpers work":
    let myApp = newApp()
    let bgColor = themeBgColor()
    check bgColor.r > 0  # Has valid color

  test "Widget gets themed colors":
    let myApp = newApp()
    let checkbox = newCheckbox(text = "Test")
    # Widget should use theme colors, not hardcoded
```

## Next Steps

1. Implement app enhancement
2. Create theme helpers
3. Refactor one widget as proof-of-concept
4. Test thoroughly
5. Roll out to all widgets
6. Create theme presets
7. Update documentation
8. Add theme editor tool
