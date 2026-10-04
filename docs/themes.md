# Themes

A theme says how every widget looks: colours and fonts, but also stroke
widths, corner radii, padding, shadows and control sizes, so one brand can be
fat and bold and another thin and lean. Widgets read the *current* theme from
memory while they paint; files are parsed once, into that.

```nim
app.setTheme("punch")                 # a registered theme, by name
app.setTheme(brandTheme(acmeSpec))    # or a Theme value built in code
app.themeManager.loadAndSet("themes/acme.yaml")   # or a file
```

Eight themes ship as brands -- `daylight`, `midnight`, `aurora`, `ocean`,
`forest`, `rose`, `ember`, `graphite` -- plus `punch` (fat) and `hairline`
(lean). `examples/widgets/theme_gallery.nim` shows them all.

## Three ways to write one

### 1. A brand: a handful of choices (usually enough)

```yaml
name: Acme
brand:
  accent: "#E4572E"
  canvas: "#FAF7F2"      # the window
  surface: "#FFFFFF"     # what controls sit on
  text: "#1D1A17"
  border: "#E7E0D6"
  radius: 10
  borderWidth: 3
  boldCaptions: true
  shadow: 4
```

Hovers, presses, focus, disabled states and the status intents (info,
success, warning, danger) are derived from these, so the theme is complete.
The same thing in code: `brandTheme(BrandSpec(name: "Acme", accent: hex"#E4572E", ...))`.

Brand keys: `name dark accent onAccent canvas surface text border info success
warning danger shadowColor radius fontSize fontFamily padding paddingX
borderWidth borderless focusRingWidth boldCaptions uppercaseCaptions shadow
controlHeight indicatorSize trackThickness thumbSize progressHeight rowHeight
scrollbarThickness`. Anything left out takes its default.

### 2. Per-intent properties: full control

A theme is a table of **intents** (`default info success warning danger`) by
**states** (`normal disabled hovered pressed focused selected dragOver`), each
a set of optional properties. A property you leave out inherits, in order,
from the state's intent, then the intent's base.

```yaml
name: Acme Flat
extends: daylight
base:
  default:
    borderWidth: 0
    cornerRadius: 2
    padding: {horizontal: 14, vertical: 6}
  danger:
    backgroundColor: "#3b141b"
states:
  default:
    hovered: {backgroundColor: "#f0f0f0"}
metrics:
  controlHeight: 36
```

Properties: colours (`backgroundColor foregroundColor borderColor
pressedColor hoverColor activeColor focusColor focusRingColor focusGlowColor
highlightColor shadowColor darkShadowColor gradientStart gradientEnd glowColor
dropShadowColor`, as `"#rrggbb"`, `"#rrggbbaa"` or `rgb(r,g,b)`), sizes
(`borderWidth cornerRadius fontSize spacing focusRingWidth focusGlowRadius
glowRadius insetShadowDepth insetShadowOpacity dropShadowBlur dropShadowOffset`),
text (`fontFamily fontWeight uppercase`), `padding` (`all`, `horizontal` /
`vertical`, or `left top right bottom`), and effects (`bevelStyle
gradientDirection`).

`metrics:` holds control geometry that is not per intent: `controlHeight
indicatorSize trackThickness thumbSize progressHeight rowHeight
scrollbarThickness`.

Hover-versus-focus priority is the theme's too:

```yaml
statePreference: {text: focus, pointer: hover}
```

### 3. In code

```nim
var mine = themeManager.derive("daylight", "Mine")     # a copy of a registered theme
mine.base[Default].cornerRadius = some(0.0'f32)
themeManager.register("mine", mine)
```

## Inheritance

`extends: name` starts from another theme -- a registered one, or a file
beside this one (`name.yaml`, `.yml`, `.json`) -- and everything else in the
file is laid over it, property by property. Chains work (`a` extends `b`
extends `daylight`). A `brand:` section replaces `extends`, and `base` /
`states` still override it.

Mistakes are errors, never silent defaults, and they name the file:

- a key the format does not have, with the likely fix:
  `unknown key 'corner_radius' in base.default (did you mean 'cornerRadius'?)`
- an unknown intent or state name (`dangerous`, `hover`);
- `extends` of a theme that does not exist, listing what does;
- a cycle: `theme extends itself: a -> b -> a`.

## Files

YAML or JSON, chosen by extension. `ThemeManager.addSearchPath(dir)` makes
`loadTheme("acme")` look there for `acme.yaml`. Examples:
`examples/themes/light.yaml`, `examples/themes/dark.yaml`.
