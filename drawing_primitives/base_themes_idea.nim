# Built-in base themes
const BaseThemes = {
  "light": ThemeData(
    name: "Light Base",
    base: {
      Default: ThemeProps(
        backgroundColor: rgb(255, 255, 255),
        foregroundColor: rgb(33, 33, 33),
        borderColor: rgb(224, 224, 224),
        borderWidth: 1.0,
        cornerRadius: 4.0,
        fontSize: 14.0,
        padding: EdgeInsets(all: 8)
      ),
      # ... other intents with sensible defaults
    }.toTable,
    states: {...}.toTable
  ).toTable,
  
  "dark": ThemeData(...),
  "beos": ThemeData(  # Classic BeOS look
    cornerRadius: 0.0,  # Square corners
    # Bold colors, etc
  ),
  "joy": ThemeData(   # Playful, rounded
    cornerRadius: 12.0,
    # Vibrant colors
  ),
  "wide": ThemeData(  # Spacious layout
    padding: EdgeInsets(all: 16),
    spacing: 12.0,
    # Larger text etc
  )
}.toTable

# YAML format for custom themes:
"""
name: Custom Theme
extends: light      # Inherit from built-in light theme
base:
  default:
    backgroundColor: "#fafafa"  # Only override what's different
  info:
    backgroundColor: "#e3f2fd"
states:
  default:
    hovered:
      backgroundColor: "#f0f0f0"
"""

proc loadTheme*(path: string): ThemeData =
  let yaml = loadYaml(path)
  let baseName = yaml["extends"].strVal
  result = BaseThemes[baseName].deepCopy()  # Start with base theme
  # Then override with custom values
  mergeTheme(result, yaml)