## Branded themes from a handful of brand decisions.
##
## A theme is a table of intents x states x some thirty optional properties,
## and filling it by hand is how the old built-ins ended up leaving half of it
## empty: no `activeColor`, no `hoverColor`, no `focusColor` -- so every
## slider fill, checkmark and selection fell back to the same hard-coded blue,
## and no theme looked like anything in particular.
##
## A brand is a few choices instead: an accent, the canvas behind everything,
## the surface controls sit on, a text colour, a corner radius, a font. The
## rest follows from them -- hovers and presses lean toward the accent,
## status intents are the status hue tinted into the surface, disabled
## controls fade toward the canvas -- so every theme made this way is complete
## and internally consistent:
##
## ```nim
## let acme = brandTheme(BrandSpec(
##   name: "Acme", accent: hex"#E4572E",
##   canvas: hex"#FAF7F2", surface: hex"#FFFFFF", text: hex"#1D1A17",
##   border: hex"#E7E0D6", radius: 10))
## app.themeManager.register("acme", acme)
## ```

import std/[options, strutils, tables]
import theme_sys_core
import rui_core

type
  BrandSpec* = object
    name*: string
    dark*: bool             ## the canvas is dark: tints go lighter, not darker
    accent*: Color          ## the brand colour: fills, focus, primary actions
    onAccent*: Color        ## text drawn on the accent (white if unset)
    canvas*: Color          ## the window behind everything
    surface*: Color         ## what controls sit on: inputs, buttons, lists
    text*: Color
    border*: Color
    info*, success*, warning*, danger*: Color   ## status hues (defaults if unset)
    radius*: float32        ## corner radius for every control
    fontSize*: float32      ## 14 if unset
    fontFamily*: string     ## "" is the system sans
    padding*: float32       ## vertical padding inside controls; 8 if unset
    paddingX*: float32      ## horizontal padding in buttons; 2 x padding if unset

    # Geometry: what makes a brand fat and bold or thin and lean. Zero means
    # the default for each.
    borderWidth*: float32     ## control outlines; 1 if unset
    borderless*: bool         ## no outlines at all (overrides borderWidth)
    focusRingWidth*: float32  ## 2 if unset
    boldCaptions*: bool       ## button captions in bold
    uppercaseCaptions*: bool  ## button captions in capitals
    shadow*: float32          ## hard drop shadow under buttons and fields, px
    shadowColor*: Color       ## the text colour if unset
    controlHeight*: float32   ## minimum button / field height; content if unset
    indicatorSize*: float32   ## check box and radio size; 20 if unset
    trackThickness*: float32  ## slider track; 8 if unset
    thumbSize*: float32       ## slider thumb; 20 if unset
    progressHeight*: float32  ## progress bar; 20 if unset

# ----------------------------------------------------------------------------
# Colour arithmetic
# ----------------------------------------------------------------------------

proc hex*(s: string): Color =
  ## "#RRGGBB" or "#RRGGBBAA".
  let h = s.strip(chars = {'#'})
  let v = parseHexInt(h)
  if h.len == 8:
    Color(r: uint8((v shr 24) and 255), g: uint8((v shr 16) and 255),
          b: uint8((v shr 8) and 255), a: uint8(v and 255))
  else:
    Color(r: uint8((v shr 16) and 255), g: uint8((v shr 8) and 255),
          b: uint8(v and 255), a: 255)

proc mix*(a, b: Color, t: float32): Color =
  ## `t` of the way from `a` to `b`.
  proc ch(x, y: uint8): uint8 =
    uint8(clamp(float32(x) + (float32(y) - float32(x)) * t, 0.0, 255.0) + 0.5)
  Color(r: ch(a.r, b.r), g: ch(a.g, b.g), b: ch(a.b, b.b), a: ch(a.a, b.a))

proc alpha*(c: Color, a: float32): Color =
  Color(r: c.r, g: c.g, b: c.b, a: uint8(clamp(a, 0.0, 1.0) * 255))

proc isSet(c: Color): bool = c.a > 0

# ----------------------------------------------------------------------------
# The generator
# ----------------------------------------------------------------------------

const
  DefaultInfo = Color(r: 37, g: 99, b: 235, a: 255)
  DefaultSuccess = Color(r: 22, g: 163, b: 74, a: 255)
  DefaultWarning = Color(r: 217, g: 119, b: 6, a: 255)
  DefaultDanger = Color(r: 220, g: 38, b: 38, a: 255)

proc statusProps(spec: BrandSpec, hue: Color): ThemeProps =
  ## A status intent: the hue tinted into the surface, text in the hue itself,
  ## pushed toward the text colour on light themes so it stays readable.
  let tint = if spec.dark: 0.20'f32 else: 0.12'f32
  let ink = if spec.dark: mix(hue, spec.text, 0.25) else: mix(hue, spec.text, 0.30)
  ThemeProps(backgroundColor: some(mix(spec.surface, hue, tint)),
             foregroundColor: some(ink),
             borderColor: some(mix(spec.surface, hue, 0.35)),
             activeColor: some(hue),
             hoverColor: some(mix(spec.surface, hue, tint + 0.08)),
             pressedColor: some(mix(spec.surface, hue, tint + 0.16)),
             focusColor: some(hue))

proc stateProps(spec: BrandSpec, base: ThemeProps, hue: Color,
                state: ThemeState): ThemeProps =
  ## How an intent looks hovered, pressed, focused or disabled.
  let bg = base.backgroundColor.get(spec.surface)
  case state
  of Hovered:
    ThemeProps(backgroundColor: some(mix(bg, hue, 0.08)))
  of Pressed:
    ThemeProps(backgroundColor: some(mix(bg, hue, 0.16)))
  of Focused:
    ThemeProps(borderColor: some(if spec.borderWidth >= 2: spec.border else: spec.accent),
               focusRingColor: some(spec.accent.alpha(0.45)))
  of Disabled:
    ThemeProps(backgroundColor: some(mix(bg, spec.canvas, 0.5)),
               foregroundColor: some(mix(spec.text, spec.surface, 0.55)),
               borderColor: some(mix(base.borderColor.get(spec.border),
                                     spec.canvas, 0.5)))
  of Selected:
    ThemeProps(backgroundColor: some(mix(bg, spec.accent, 0.22)))
  else:
    ThemeProps()

proc brandTheme*(spec: BrandSpec): Theme =
  ## A complete theme from a brand spec. See the module comment.
  var s = spec
  if not s.onAccent.isSet: s.onAccent = Color(r: 255, g: 255, b: 255, a: 255)
  if not s.info.isSet: s.info = s.accent
  if not s.success.isSet: s.success = DefaultSuccess
  if not s.warning.isSet: s.warning = DefaultWarning
  if not s.danger.isSet: s.danger = DefaultDanger
  if s.fontSize <= 0: s.fontSize = 14
  if s.padding <= 0: s.padding = 8
  if s.paddingX <= 0: s.paddingX = s.padding * 2
  if s.borderWidth <= 0: s.borderWidth = 1
  if s.borderless: s.borderWidth = 0
  if s.focusRingWidth <= 0: s.focusRingWidth = 2
  if not s.shadowColor.isSet: s.shadowColor = s.text

  result = newTheme(s.name)
  result.brandPalette = BrandPalette(
    primaryColor: some(s.accent), accentColor: some(s.accent),
    surfaceColor: some(s.canvas), neutralLight: some(s.border),
    neutralDark: some(s.text), errorColor: some(s.danger),
    successColor: some(s.success))
  if s.fontFamily.len > 0:
    result.typography.primaryFont = some(s.fontFamily)
    result.typography.secondaryFont = some(s.fontFamily)
  if s.boldCaptions:
    result.typography.headingWeight = some(Bold)

  proc opt(v: float32): Option[float32] =
    if v > 0: some(v) else: none(float32)
  result.metrics = ControlMetrics(
    controlHeight: opt(s.controlHeight), indicatorSize: opt(s.indicatorSize),
    trackThickness: opt(s.trackThickness), thumbSize: opt(s.thumbSize),
    progressHeight: opt(s.progressHeight))

  # The geometry every intent shares, so a Danger button is as fat as a
  # Default one.
  proc shaped(p: ThemeProps): ThemeProps =
    result = p
    result.borderWidth = some(s.borderWidth)
    result.cornerRadius = some(s.radius)
    result.fontSize = some(s.fontSize)
    result.padding = some(EdgeInsets(top: s.padding, bottom: s.padding,
                                     left: s.paddingX, right: s.paddingX))
    result.spacing = some(s.padding)
    result.focusRingWidth = some(s.focusRingWidth)
    if s.fontFamily.len > 0:
      result.fontFamily = some(s.fontFamily)
    if s.boldCaptions:
      result.fontWeight = some(Bold)
    if s.uppercaseCaptions:
      result.uppercase = some(true)
    if s.shadow > 0:
      result.dropShadowOffset = some((s.shadow, s.shadow))
      result.dropShadowColor = some(s.shadowColor)

  var default = shaped(ThemeProps(
    backgroundColor: some(s.surface), foregroundColor: some(s.text),
    borderColor: some(s.border),
    activeColor: some(s.accent), focusColor: some(s.accent),
    hoverColor: some(mix(s.surface, s.accent, 0.08)),
    pressedColor: some(mix(s.surface, s.accent, 0.16)),
    focusRingColor: some(s.accent.alpha(0.45))))
  result.base[Default] = default

  let hues = [(Info, s.info), (Success, s.success), (Warning, s.warning),
              (Danger, s.danger)]
  for (intent, hue) in hues:
    var p = shaped(statusProps(s, hue))
    if s.borderWidth >= 2:
      p.borderColor = some(s.border)   # a heavy outline stays the brand's ink
    result.base[intent] = p

  for intent in ThemeIntent:
    # Each intent leans toward its own hue; Default toward the brand accent.
    let hue = result.base[intent].activeColor.get(s.accent)
    for state in [Hovered, Pressed, Focused, Disabled, Selected]:
      result.states[intent][state] = stateProps(s, result.base[intent], hue, state)

  # Info is the brand's primary action: solid accent, not a tint. Its hover
  # and press shade the accent itself -- toward white on a dark theme, where
  # darkening would sink it into the canvas.
  let shadeTo = if s.dark: Color(r: 255, g: 255, b: 255, a: 255)
                else: Color(r: 0, g: 0, b: 0, a: 255)
  var primary = result.base[Info]
  primary.backgroundColor = some(s.accent)
  primary.foregroundColor = some(s.onAccent)
  primary.borderColor = some(if s.borderWidth >= 2: s.border else: s.accent)
  result.base[Info] = primary
  result.states[Info][Hovered] = ThemeProps(backgroundColor: some(mix(s.accent, shadeTo, 0.10)))
  result.states[Info][Pressed] = ThemeProps(backgroundColor: some(mix(s.accent, shadeTo, 0.20)))

# ----------------------------------------------------------------------------
# The brands that ship
# ----------------------------------------------------------------------------

proc daylightSpec*(): BrandSpec =
  ## Crisp neutral light with an indigo accent. The default.
  BrandSpec(name: "Daylight", accent: hex"#4F46E5",
            canvas: hex"#F3F4F7", surface: hex"#FFFFFF",
            text: hex"#1F2330", border: hex"#DCDFE6", radius: 6)

proc midnightSpec*(): BrandSpec =
  ## Deep blue-black with a soft periwinkle accent.
  BrandSpec(name: "Midnight", dark: true, accent: hex"#8B93FF",
            onAccent: hex"#0E1016",
            canvas: hex"#0E1016", surface: hex"#181B24",
            text: hex"#E6E8EF", border: hex"#2A2F3D", radius: 6,
            success: hex"#34D399", warning: hex"#FBBF24", danger: hex"#F87171")

proc auroraSpec*(): BrandSpec =
  ## Lavender light, violet accent, generous rounding.
  BrandSpec(name: "Aurora", accent: hex"#7C3AED",
            canvas: hex"#F6F3FE", surface: hex"#FFFFFF",
            text: hex"#221B35", border: hex"#E3DAF7", radius: 10)

proc oceanSpec*(): BrandSpec =
  ## Airy blue-grey with a sky accent.
  BrandSpec(name: "Ocean", accent: hex"#0284C7",
            canvas: hex"#EEF5F9", surface: hex"#FFFFFF",
            text: hex"#0F2733", border: hex"#D2E3EC", radius: 8)

proc forestSpec*(): BrandSpec =
  ## Warm paper and a deep green; squarer corners, serif type.
  BrandSpec(name: "Forest", accent: hex"#2F7D4A",
            canvas: hex"#F2F1EA", surface: hex"#FBFAF5",
            text: hex"#1E2A22", border: hex"#DAD8CB", radius: 4,
            fontFamily: "Serif")

proc roseSpec*(): BrandSpec =
  ## Blush light, raspberry accent, pill-round controls.
  BrandSpec(name: "Rose", accent: hex"#DB2777",
            canvas: hex"#FDF2F6", surface: hex"#FFFFFF",
            text: hex"#34121F", border: hex"#F5D5E2", radius: 14)

proc emberSpec*(): BrandSpec =
  ## Warm charcoal with an amber-orange accent.
  BrandSpec(name: "Ember", dark: true, accent: hex"#F97316",
            onAccent: hex"#1A120C",
            canvas: hex"#15110E", surface: hex"#211A15",
            text: hex"#F4E9E1", border: hex"#3A2E25", radius: 8,
            success: hex"#4ADE80", warning: hex"#FACC15", danger: hex"#F87171")

proc graphiteSpec*(): BrandSpec =
  ## Neutral pro dark with a cyan accent and tight corners.
  BrandSpec(name: "Graphite", dark: true, accent: hex"#22D3EE",
            onAccent: hex"#0B0C0E",
            canvas: hex"#101113", surface: hex"#1B1C20",
            text: hex"#E4E6EA", border: hex"#2C2E34", radius: 3,
            success: hex"#34D399", warning: hex"#FBBF24", danger: hex"#FB7185")

proc punchSpec*(): BrandSpec =
  ## Fat and bold: slab outlines in ink, hard offset shadows that buttons sink
  ## into when pressed, bold capitals, big controls. Same widgets as Hairline.
  BrandSpec(name: "Punch", accent: hex"#FF5A1F", onAccent: hex"#111111",
            canvas: hex"#FFF1D6", surface: hex"#FFFFFF",
            text: hex"#111111", border: hex"#111111", radius: 6,
            fontSize: 15, padding: 10, paddingX: 22,
            borderWidth: 3, focusRingWidth: 3, boldCaptions: true,
            uppercaseCaptions: true, shadow: 4, controlHeight: 46,
            indicatorSize: 24, trackThickness: 12, thumbSize: 26,
            progressHeight: 26,
            info: hex"#2F6BFF", success: hex"#1FA35C", warning: hex"#FFB000",
            danger: hex"#E5242B")

proc hairlineSpec*(): BrandSpec =
  ## Thin and lean: hairline strokes, near-square corners, small type and
  ## tight padding, ink-black accent. Same widgets as Punch.
  BrandSpec(name: "Hairline", accent: hex"#111111",
            canvas: hex"#FAFAFA", surface: hex"#FFFFFF",
            text: hex"#1A1A1A", border: hex"#D4D4D4", radius: 2,
            fontSize: 13, padding: 5, paddingX: 12,
            borderWidth: 1, focusRingWidth: 1, controlHeight: 28,
            indicatorSize: 14, trackThickness: 2, thumbSize: 12,
            progressHeight: 6)

proc brandThemes*(): seq[tuple[key: string, theme: Theme]] =
  ## Every shipped brand, by registry name.
  @[("daylight", brandTheme(daylightSpec())),
    ("midnight", brandTheme(midnightSpec())),
    ("aurora", brandTheme(auroraSpec())),
    ("ocean", brandTheme(oceanSpec())),
    ("forest", brandTheme(forestSpec())),
    ("rose", brandTheme(roseSpec())),
    ("ember", brandTheme(emberSpec())),
    ("graphite", brandTheme(graphiteSpec())),
    ("punch", brandTheme(punchSpec())),
    ("hairline", brandTheme(hairlineSpec()))]
