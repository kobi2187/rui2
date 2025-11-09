# Font Family Support in Themes

Font family support has been added to the theme system!

## Changes Made

### 1. ThemeProps Updated
**File:** `drawing_primitives/theme_sys_core.nim:35`

Added `fontFamily` field to `ThemeProps`:
```nim
type ThemeProps* = object
  backgroundColor*: Option[Color]
  foregroundColor*: Option[Color]
  borderColor*: Option[Color]
  borderWidth*: Option[float32]
  cornerRadius*: Option[float32]
  padding*: Option[EdgeInsets]
  spacing*: Option[float32]
  textStyle*: Option[TextStyle]
  fontSize*: Option[float32]
  fontFamily*: Option[string]  # NEW!
```

### 2. Built-in Themes Updated
**File:** `drawing_primitives/builtin_base_themes.nim:20-29`

The `themedProps` helper now includes fontFamily with default "sans-serif":
```nim
proc themedProps(
    bg: tuple[r, g, b: int],
    fg: tuple[r, g, b: int],
    border: tuple[r, g, b: int] = (224, 224, 224),
    paddingValue = 8.0,
    spacingValue = 8.0,
    borderWidthValue = 1.0,
    cornerRadiusValue = 4.0,
    fontSizeValue = 14.0,
    fontFamilyValue = "sans-serif"  # NEW!
  ): ThemeProps
```

All built-in themes now automatically include the font family:
- Light theme: "sans-serif"
- Dark theme: "sans-serif"
- BeOS theme: "sans-serif"
- Joy theme: "sans-serif"
- Wide theme: "sans-serif"

### 3. Label Widget Updated
**File:** `widgets/basic/label.nim:72-84`

Label now reads fontFamily from theme:
```nim
let fontFamily = if props.fontFamily.isSome:
                   props.fontFamily.get()
                 else:
                   ""  # Empty = use default

let textStyle = TextStyle(
  fontFamily: fontFamily,
  fontSize: float32(fontSize),
  color: fgColor,
  bold: false,
  italic: false,
  underline: false
)
```

## Usage

### Using Built-in Themes with Fonts

```nim
import drawing_primitives/builtin_base_themes

# Get a theme with fonts configured
let theme = builtInTheme("light")  # or "dark", "beos", "joy", "wide"

# Create a label with the theme
let label = newLabel()
label.theme = theme
label.text = "This uses sans-serif font!"
```

### Custom Font in Theme

```nim
# Create custom theme with specific font
var customTheme = newTheme("Custom")
customTheme.base[Default] = ThemeProps(
  backgroundColor: some(makeColor(255, 255, 255)),
  foregroundColor: some(makeColor(0, 0, 0)),
  fontSize: some(16.0'f32),
  fontFamily: some("Helvetica")  # Custom font!
)

label.theme = customTheme
```

### Override Font Per-Intent

```nim
var theme = builtInTheme("light")

# Use different font for danger intent
theme.base[Danger].fontFamily = some("monospace")

# Now danger labels will use monospace
dangerLabel.intent = Danger
dangerLabel.theme = theme
```

## Font Family Values

The `fontFamily` field accepts:
- `""` - Empty string uses Raylib default font (ugly but reliable)
- `"sans-serif"` - System sans-serif font
- `"serif"` - System serif font
- `"monospace"` - System monospace font
- `"Helvetica"`, `"Arial"`, etc. - Specific font names

Note: Actual font rendering depends on what fonts are available on the system and how Raylib/Pango resolves font names.

## Widgets Supporting Font Family

Currently implemented:
- ✓ Label (`widgets/basic/label.nim`)

TODO:
- Button (still uses hardcoded TextStyle)
- ButtonYAML (still uses hardcoded TextStyle)
- TextInput (still uses hardcoded fontSize)

## Benefits

1. **No more ugly Raylib default font** - All themes now specify "sans-serif" by default
2. **Consistent typography** - Font is part of the theme, not hardcoded per widget
3. **Easy customization** - Change font for entire app by changing theme
4. **Per-intent fonts** - Can use different fonts for Default, Info, Success, Warning, Danger
5. **Per-state fonts** - Could override font in Hovered, Pressed states if needed

## Testing

All components compile successfully:
```bash
nim c -d:useGraphics drawing_primitives/builtin_base_themes.nim  ✓
nim c -d:useGraphics widgets/basic/label.nim                      ✓
```
