## Theme file adapter — turning JSON or YAML text into a `Theme`.
##
## Split out of theme_manager.nim, which was doing two unrelated jobs behind one
## 16-proc interface: parsing files, and storing themes. Parsing was the harder
## half (the four highest-complexity routines in that file) and the less
## reachable one — you needed a live `ThemeManager` before you could parse a
## string, so a file-format bug could only be exercised through the registry.
##
## Everything here is pure: text in, `Theme` out. The only outside dependency is
## the `resolver` callback, which answers "what does this theme extend?" — the
## registry supplies the real one, a test can supply `newTheme`.
##
## Colors in files are hex strings ("#rrggbb" / "#rrggbbaa") or rgb(r,g,b).
## The `*File` types hold them as strings; `toThemeProps` converts.

import std/[tables, options, json, strutils, parseutils, editdistance, sequtils]
import yaml
import yaml/tojson
import theme_sys_core
import theme_types
import brand_themes
import rui_core

export theme_sys_core, theme_types

type
  ThemeFileFormat* = enum
    ## Which parser to use. `formatFor` picks one from a file extension.
    tffJson
    tffYaml

proc formatFor*(path: string): ThemeFileFormat =
  ## JSON only when the extension says so; everything else is treated as YAML,
  ## which is what the loaders did inline before.
  ##
  ## Suffix match rather than `os.splitFile`, so this module needs no filesystem
  ## import at all — it only ever sees text.
  if path.toLowerAscii().endsWith(".json"): tffJson else: tffYaml

type
  PaddingFile* {.sparse.} = object
    all: Option[float32]
    top: Option[float32]
    right: Option[float32]
    bottom: Option[float32]
    left: Option[float32]
    horizontal: Option[float32]
    vertical: Option[float32]

  ThemePropsFile* {.sparse.} = object
    ## Mirrors ThemeProps but with colors as strings for file loading.
    # Colors (hex strings)
    backgroundColor: Option[string]
    foregroundColor: Option[string]
    borderColor: Option[string]
    pressedColor: Option[string]
    hoverColor: Option[string]
    activeColor: Option[string]
    focusColor: Option[string]
    focusRingColor: Option[string]
    focusGlowColor: Option[string]
    highlightColor: Option[string]
    shadowColor: Option[string]
    darkShadowColor: Option[string]
    gradientStart: Option[string]
    gradientEnd: Option[string]
    glowColor: Option[string]
    dropShadowColor: Option[string]
    # Dimensions
    borderWidth: Option[float32]
    cornerRadius: Option[float32]
    fontSize: Option[float32]
    spacing: Option[float32]
    focusRingWidth: Option[float32]
    focusGlowRadius: Option[float32]
    glowRadius: Option[float32]
    insetShadowDepth: Option[float32]
    insetShadowOpacity: Option[float32]
    dropShadowBlur: Option[float32]
    # Text
    fontFamily: Option[string]
    fontWeight: Option[string]      ## light, regular, medium, semibold, bold, extrabold
    uppercase: Option[bool]
    dropShadowOffset: Option[float32]  ## hard shadow, px right and down
    # Layout
    padding: Option[PaddingFile]
    # Effects (as strings, converted to enums)
    bevelStyle: Option[string]
    gradientDirection: Option[string]

  HintFile* {.sparse.} = object
    ## A `hint:` section: how the help overlay's badges look.
    background, foreground, border: Option[string]
    borderWidth, fontSize: Option[float32]
    fontFamily: Option[string]
    uppercase: Option[bool]

  MetricsFile* {.sparse.} = object
    ## Control geometry (ControlMetrics), every field optional.
    controlHeight: Option[float32]
    indicatorSize: Option[float32]
    trackThickness: Option[float32]
    thumbSize: Option[float32]
    progressHeight: Option[float32]
    rowHeight: Option[float32]
    scrollbarThickness: Option[float32]

  AnimationFile* {.sparse.} = object
    ## Motion: how long a colour takes to change when a control's state does
    ## (`fast`, the one the widgets use), and the longer two for the author's own
    ## animations. Milliseconds; 0 makes changes instant.
    durationFast, durationNormal, durationSlow: Option[float32]
    defaultEasing: Option[string]

  BrandFile* {.sparse.} = object
    ## A `brand:` section: the same choices as `BrandSpec`, colours as strings.
    ## Everything is optional; what is left out takes the spec's own default.
    name: Option[string]
    dark: Option[bool]
    accent, onAccent, canvas, surface, text, border: Option[string]
    info, success, warning, danger, shadowColor: Option[string]
    radius, fontSize, padding, paddingX: Option[float32]
    fontFamily: Option[string]
    borderWidth, focusRingWidth, shadow: Option[float32]
    borderless, boldCaptions, uppercaseCaptions: Option[bool]
    controlHeight, indicatorSize, trackThickness, thumbSize: Option[float32]
    progressHeight, rowHeight, scrollbarThickness: Option[float32]
    transitionMs: Option[float32]
    noTransitions: Option[bool]

  ThemeFile* {.sparse.} = object
    ## Top-level theme file structure (JSON or YAML)
    name: Option[string]
    `extends`: Option[string]
    version: Option[string]
    base: Option[Table[string, ThemePropsFile]]
    states: Option[Table[string, Table[string, ThemePropsFile]]]
    statePreference: Option[Table[string, string]]
      ## role ("text" / "pointer") -> "focus" / "hover"
    metrics: Option[MetricsFile]
    hint: Option[HintFile]
    animation: Option[AnimationFile]
    brand: Option[BrandFile]
      ## A whole theme from a handful of brand choices (see brand_themes.nim).
      ## It replaces `extends`; `base` and `states` still override it.

# ============================================================================
# Color Parsing
# ============================================================================

proc parseColor*(val: string): Color =
  ## Parse "#rrggbb", "#rrggbbaa", or "rgb(r,g,b)" to Color
  var s = val.strip()
  if s.startsWith("rgb"):
    let inner = s.replace("rgb(", "").replace("rgba(", "").replace(")", "").strip()
    let parts = inner.split(",")
    if parts.len >= 3:
      return Color(
        r: uint8(parseInt(parts[0].strip())),
        g: uint8(parseInt(parts[1].strip())),
        b: uint8(parseInt(parts[2].strip())),
        a: uint8(if parts.len == 4: parseInt(parts[3].strip()) else: 255))
  else:
    if s.startsWith("#"): s = s[1..^1]
    var r, g, b, a: int
    if s.len >= 6:
      discard parseHex(s[0..1], r)
      discard parseHex(s[2..3], g)
      discard parseHex(s[4..5], b)
      a = if s.len == 8: (discard parseHex(s[6..7], a); a) else: 255
      return Color(r: uint8(r), g: uint8(g), b: uint8(b), a: uint8(a))
proc optColor*(s: Option[string]): Option[Color] =
  if s.isSome: some(parseColor(s.get())) else: none(Color)

# ============================================================================
# Conversion: File Types -> Theme Types
# ============================================================================

proc parseIntentName*(s: string): ThemeIntent =
  case s.toLowerAscii()
  of "default": Default
  of "info": Info
  of "success": Success
  of "warning": Warning
  of "danger": Danger
  else: Default

proc parseStateName*(s: string): ThemeState =
  case s.toLowerAscii()
  of "normal": Normal
  of "disabled": Disabled
  of "hovered": Hovered
  of "pressed": Pressed
  of "focused": Focused
  of "selected": Selected
  of "dragover": DragOver
  else: Normal

proc parseRoleName*(s: string): ControlRole =
  case s.toLowerAscii()
  of "text": crText
  of "pointer": crPointer
  else: raise newException(ValueError, "Unknown control role: " & s &
                           " (expected text or pointer)")

proc parsePreference*(s: string): StatePreference =
  case s.toLowerAscii()
  of "focus": spFocusFirst
  of "hover": spHoverFirst
  of "default": spRoleDefault
  else: raise newException(ValueError, "Unknown state preference: " & s &
                           " (expected focus, hover or default)")

proc parseEasingName*(s: string): AnimationEasing =
  case s.toLowerAscii()
  of "linear": Linear
  of "easein": EaseIn
  of "easeout": EaseOut
  of "easeinout": EaseInOut
  of "bounce": Bounce
  of "elastic": Elastic
  else: raise newException(ValueError, "Unknown easing: " & s &
    " (expected linear, easeIn, easeOut, easeInOut, bounce or elastic)")

proc toThemeProps*(fp: ThemePropsFile): ThemeProps =
  ## Convert file props (string colors) to runtime ThemeProps (Color objects)
  result = ThemeProps()
  result.backgroundColor = optColor(fp.backgroundColor)
  result.foregroundColor = optColor(fp.foregroundColor)
  result.borderColor = optColor(fp.borderColor)
  result.pressedColor = optColor(fp.pressedColor)
  result.hoverColor = optColor(fp.hoverColor)
  result.activeColor = optColor(fp.activeColor)
  result.focusColor = optColor(fp.focusColor)
  result.focusRingColor = optColor(fp.focusRingColor)
  result.focusGlowColor = optColor(fp.focusGlowColor)
  result.highlightColor = optColor(fp.highlightColor)
  result.shadowColor = optColor(fp.shadowColor)
  result.darkShadowColor = optColor(fp.darkShadowColor)
  result.gradientStart = optColor(fp.gradientStart)
  result.gradientEnd = optColor(fp.gradientEnd)
  result.glowColor = optColor(fp.glowColor)
  result.dropShadowColor = optColor(fp.dropShadowColor)
  result.borderWidth = fp.borderWidth
  result.cornerRadius = fp.cornerRadius
  result.fontSize = fp.fontSize
  result.spacing = fp.spacing
  result.focusRingWidth = fp.focusRingWidth
  result.focusGlowRadius = fp.focusGlowRadius
  result.glowRadius = fp.glowRadius
  result.insetShadowDepth = fp.insetShadowDepth
  result.insetShadowOpacity = fp.insetShadowOpacity
  result.dropShadowBlur = fp.dropShadowBlur
  result.fontFamily = fp.fontFamily
  if fp.fontWeight.isSome:
    result.fontWeight = some(case fp.fontWeight.get().toLowerAscii()
      of "light", "300": Light
      of "medium", "500": Medium
      of "semibold", "600": SemiBold
      of "bold", "700": Bold
      of "extrabold", "800": ExtraBold
      else: Regular)
  result.uppercase = fp.uppercase
  if fp.dropShadowOffset.isSome:
    let o = fp.dropShadowOffset.get()
    result.dropShadowOffset = some((o, o))
  # Padding
  if fp.padding.isSome:
    let p = fp.padding.get()
    if p.all.isSome:
      result.padding = some(edgeInsets(p.all.get()))
    elif p.horizontal.isSome or p.vertical.isSome:
      result.padding = some(edgeInsetsSymmetric(
        p.horizontal.get(0.0f32), p.vertical.get(0.0f32)))
    else:
      result.padding = some(edgeInsetsLTRB(
        p.left.get(0.0f32), p.top.get(0.0f32),
        p.right.get(0.0f32), p.bottom.get(0.0f32)))
  # Bevel style
  if fp.bevelStyle.isSome:
    result.bevelStyle = some(case fp.bevelStyle.get().toLowerAscii()
      of "flat": Flat
      of "raised": Raised
      of "sunken": Sunken
      of "ridge": Ridge
      of "groove": Groove
      of "soft": Soft
      of "convex": Convex
      of "drop": Drop
      of "interior": Interior
      of "flatsoft": Flatsoft
      of "flatconvex": Flatconvex
      else: Flat)
  # Gradient direction
  if fp.gradientDirection.isSome:
    result.gradientDirection = some(case fp.gradientDirection.get().toLowerAscii()
      of "vertical": theme_types.Vertical
      of "horizontal": theme_types.Horizontal
      of "radial": theme_types.Radial
      else: theme_types.Vertical)

proc toBrandSpec*(bf: BrandFile): BrandSpec =
  ## File form to `BrandSpec`. A colour that fails to parse raises, like any
  ## other colour in a theme file.
  template color(f: Option[string]): Color =
    (if f.isSome: parseColor(f.get()) else: Color())
  template num(f: Option[float32]): float32 = f.get(0.0'f32)
  BrandSpec(
    name: bf.name.get("Brand"), dark: bf.dark.get(false),
    accent: color(bf.accent), onAccent: color(bf.onAccent),
    canvas: color(bf.canvas), surface: color(bf.surface),
    text: color(bf.text), border: color(bf.border),
    info: color(bf.info), success: color(bf.success),
    warning: color(bf.warning), danger: color(bf.danger),
    shadowColor: color(bf.shadowColor),
    radius: num(bf.radius), fontSize: num(bf.fontSize),
    fontFamily: bf.fontFamily.get(""), padding: num(bf.padding),
    paddingX: num(bf.paddingX), borderWidth: num(bf.borderWidth),
    borderless: bf.borderless.get(false), focusRingWidth: num(bf.focusRingWidth),
    boldCaptions: bf.boldCaptions.get(false),
    uppercaseCaptions: bf.uppercaseCaptions.get(false), shadow: num(bf.shadow),
    controlHeight: num(bf.controlHeight), indicatorSize: num(bf.indicatorSize),
    trackThickness: num(bf.trackThickness), thumbSize: num(bf.thumbSize),
    progressHeight: num(bf.progressHeight), rowHeight: num(bf.rowHeight),
    scrollbarThickness: num(bf.scrollbarThickness),
    transitionMs: num(bf.transitionMs), noTransitions: bf.noTransitions.get(false))

proc toTheme*(tf: ThemeFile, resolver: proc(name: string): Theme): Theme =
  ## Convert a ThemeFile to a Theme, resolving extends via resolver
  result = if tf.brand.isSome:
    brandTheme(toBrandSpec(tf.brand.get()))
  elif tf.`extends`.isSome:
    resolver(tf.`extends`.get())
  else:
    newTheme()
  if tf.`extends`.isSome and tf.brand.isNone:
    result.parent = tf.`extends`.get()
  if tf.name.isSome:
    result.name = tf.name.get()
  if tf.version.isSome:
    result.version = tf.version.get()
  if tf.base.isSome:
    for intentKey, propsFile in tf.base.get():
      let intent = parseIntentName(intentKey)
      let props = toThemeProps(propsFile)
      var merged = result.base.getOrDefault(intent, ThemeProps())
      merged.merge(props)
      result.base[intent] = merged
  if tf.states.isSome:
    for intentKey, stateTable in tf.states.get():
      let intent = parseIntentName(intentKey)
      for stateKey, propsFile in stateTable:
        let state = parseStateName(stateKey)
        let props = toThemeProps(propsFile)
        var merged = result.states[intent].getOrDefault(state, ThemeProps())
        merged.merge(props)
        result.states[intent][state] = merged
  if tf.statePreference.isSome:
    for role, pref in tf.statePreference.get():
      result.statePreference[parseRoleName(role)] = parsePreference(pref)
  if tf.hint.isSome:
    let h = tf.hint.get()
    # Field by field: a child that only recolours the badge keeps the border,
    # size and type its parent chose.
    let own = HintStyle(
      background: optColor(h.background), foreground: optColor(h.foreground),
      border: optColor(h.border), borderWidth: h.borderWidth,
      fontSize: h.fontSize, fontFamily: h.fontFamily, uppercase: h.uppercase)
    template inherit(field: untyped) =
      if own.field.isSome: result.hint.field = own.field
    inherit background
    inherit foreground
    inherit border
    inherit borderWidth
    inherit fontSize
    inherit fontFamily
    inherit uppercase
  if tf.animation.isSome:
    let a = tf.animation.get()
    template takeMotion(field: untyped) =
      if a.field.isSome: result.animation.field = a.field
    takeMotion durationFast
    takeMotion durationNormal
    takeMotion durationSlow
    if a.defaultEasing.isSome:
      result.animation.defaultEasing = some(parseEasingName(a.defaultEasing.get()))
  if tf.metrics.isSome:
    let m = tf.metrics.get()
    template take(field: untyped) =
      if m.field.isSome: result.metrics.field = m.field
    take controlHeight
    take indicatorSize
    take trackThickness
    take thumbSize
    take progressHeight
    take rowHeight
    take scrollbarThickness


# ============================================================================
# Validation
#
# The decoders ignore a key they do not know, which turns `corner_radius: 8`
# or `borderwidth: 3` into a theme that quietly looks default. Every key is
# checked against the file types above first, and a wrong one is an error that
# says where it is and what was probably meant.
# ============================================================================

proc fieldNames(T: typedesc): seq[string] =
  var x: T
  for name, _ in fieldPairs(x):
    result.add name

proc suggestion(key: string, allowed: seq[string]): string =
  let k = key.toLowerAscii.replace("_", "").replace("-", "")
  for a in allowed:
    if a.toLowerAscii == k:
      return " (did you mean '" & a & "'?)"
  for a in allowed:
    if editDistanceAscii(k, a.toLowerAscii) <= 2:
      return " (did you mean '" & a & "'?)"

proc checkKeys(node: JsonNode, where: string, allowed: seq[string],
               fold = false) =
  ## `fold`: names that are matched without regard to case (intents, states).
  if node.kind != JObject:
    raise newException(ValueError, "theme: " & where & " must be a mapping")
  for key, _ in node:
    let known = if fold: key.toLowerAscii in allowed else: key in allowed
    if not known:
      raise newException(ValueError,
        "theme: unknown key '" & key & "' in " & where & suggestion(key, allowed) &
        "; allowed: " & allowed.join(", "))

proc checkProps(node: JsonNode, where: string) =
  checkKeys(node, where, fieldNames(ThemePropsFile))
  if node.hasKey("padding") and node["padding"].kind == JObject:
    checkKeys(node["padding"], where & ".padding", fieldNames(PaddingFile))

proc validateThemeNode*(root: JsonNode) =
  ## Raise a ValueError naming the first key a theme file has that the format
  ## does not. Intent, state and role names are checked by their own parsers.
  checkKeys(root, "the top level", fieldNames(ThemeFile))
  if root.hasKey("base"):
    checkKeys(root["base"], "base", @["default", "info", "success", "warning", "danger"], fold = true)
    for intent, props in root["base"]:
      checkProps(props, "base." & intent)
  if root.hasKey("states"):
    checkKeys(root["states"], "states", @["default", "info", "success", "warning", "danger"], fold = true)
    for intent, byState in root["states"]:
      checkKeys(byState, "states." & intent,
                @["normal", "disabled", "hovered", "pressed", "focused", "selected", "dragover"],
                fold = true)
      for state, props in byState:
        checkProps(props, "states." & intent & "." & state)
  if root.hasKey("hint"):
    checkKeys(root["hint"], "hint", fieldNames(HintFile))
  if root.hasKey("metrics"):
    checkKeys(root["metrics"], "metrics", fieldNames(MetricsFile))
  if root.hasKey("animation"):
    checkKeys(root["animation"], "animation", fieldNames(AnimationFile))
  if root.hasKey("brand"):
    checkKeys(root["brand"], "brand", fieldNames(BrandFile))

proc parseThemeFile*(content: string, format: ThemeFileFormat): ThemeFile =
  ## Text to the intermediate file representation. Raises on malformed input,
  ## which is the caller's to report with a filename attached.
  case format
  of tffJson:
    let node = parseJson(content)
    validateThemeNode(node)
    node.to(ThemeFile)
  of tffYaml:
    let docs = loadToJson(content)
    if docs.len > 0:
      validateThemeNode(docs[0])
    var tf: ThemeFile
    load(content, tf)
    tf

proc parseTheme*(content: string, format: ThemeFileFormat,
                 resolver: proc(name: string): Theme): Theme =
  ## Text straight to a `Theme`. The whole adapter in one call.
  toTheme(parseThemeFile(content, format), resolver)


# ============================================================================
# Theme -> file: the other direction
#
# What `parseTheme` reads, `toYaml` writes: only what the theme sets, so the
# file of a derived theme names what it changed. Brand-derived themes come out
# as the base/states tables they were expanded into (the `brand:` shorthand is
# a way to *write* a theme, not part of one). Not written: `extends` (a Theme
# no longer knows its parent), and the unused branding fields.
# ============================================================================

proc formatColor*(c: Color): string =
  ## "#rrggbb", or "#rrggbbaa" when not opaque.
  result = "#" & toHex(int(c.r), 2).toLowerAscii & toHex(int(c.g), 2).toLowerAscii &
           toHex(int(c.b), 2).toLowerAscii
  if c.a != 255: result.add toHex(int(c.a), 2).toLowerAscii

proc num(v: float32): JsonNode =
  ## Whole numbers as integers, so the file reads `borderWidth: 2`.
  if v == float32(int(v)): newJInt(int(v)) else: newJFloat(float(v))

proc propsToJson*(p: ThemeProps): JsonNode =
  result = newJObject()
  template color(key: string, field: Option[Color]) =
    if field.isSome: result[key] = newJString(formatColor(field.get))
  template number(key: string, field: Option[float32]) =
    if field.isSome: result[key] = num(field.get)
  color "backgroundColor", p.backgroundColor
  color "foregroundColor", p.foregroundColor
  color "borderColor", p.borderColor
  color "pressedColor", p.pressedColor
  color "hoverColor", p.hoverColor
  color "activeColor", p.activeColor
  color "focusColor", p.focusColor
  color "focusRingColor", p.focusRingColor
  color "focusGlowColor", p.focusGlowColor
  color "highlightColor", p.highlightColor
  color "shadowColor", p.shadowColor
  color "darkShadowColor", p.darkShadowColor
  color "gradientStart", p.gradientStart
  color "gradientEnd", p.gradientEnd
  color "glowColor", p.glowColor
  color "dropShadowColor", p.dropShadowColor
  number "borderWidth", p.borderWidth
  number "cornerRadius", p.cornerRadius
  number "fontSize", p.fontSize
  number "spacing", p.spacing
  number "focusRingWidth", p.focusRingWidth
  number "focusGlowRadius", p.focusGlowRadius
  number "glowRadius", p.glowRadius
  number "insetShadowDepth", p.insetShadowDepth
  number "insetShadowOpacity", p.insetShadowOpacity
  number "dropShadowBlur", p.dropShadowBlur
  if p.fontFamily.isSome: result["fontFamily"] = newJString(p.fontFamily.get)
  if p.fontWeight.isSome:
    result["fontWeight"] = newJString(case p.fontWeight.get
      of Light: "light"
      of Regular: "regular"
      of Medium: "medium"
      of SemiBold: "semibold"
      of Bold: "bold"
      of ExtraBold: "extrabold")
  if p.uppercase.isSome: result["uppercase"] = newJBool(p.uppercase.get)
  if p.dropShadowOffset.isSome:
    let o = p.dropShadowOffset.get
    if o.x != o.y:
      raise newException(ValueError,
        "dropShadowOffset " & $o.x & "," & $o.y & " cannot be written: the theme " &
        "format has one offset for right and down")
    result["dropShadowOffset"] = num(o.x)
  if p.padding.isSome:
    let e = p.padding.get
    result["padding"] =
      if e.top == e.bottom and e.left == e.right and e.top == e.left:
        %*{"all": num(e.top)}
      elif e.top == e.bottom and e.left == e.right:
        %*{"horizontal": num(e.left), "vertical": num(e.top)}
      else:
        %*{"left": num(e.left), "top": num(e.top), "right": num(e.right),
           "bottom": num(e.bottom)}
  if p.bevelStyle.isSome:
    result["bevelStyle"] = newJString(($p.bevelStyle.get).toLowerAscii)
  if p.gradientDirection.isSome:
    result["gradientDirection"] = newJString(($p.gradientDirection.get).toLowerAscii)

const IntentNames = ["default", "info", "success", "warning", "danger"]
const StateNames = ["normal", "disabled", "hovered", "pressed", "focused",
                    "selected", "dragover"]

proc themeToJson*(theme: Theme): JsonNode =
  ## The theme as the document `parseTheme` reads.
  result = newJObject()
  result["name"] = newJString(theme.name)
  if theme.version.len > 0: result["version"] = newJString(theme.version)
  var base = newJObject()
  for intent in ThemeIntent:
    let props = propsToJson(theme.base.getOrDefault(intent, ThemeProps()))
    if props.len > 0: base[IntentNames[ord(intent)]] = props
  if base.len > 0: result["base"] = base
  var states = newJObject()
  for intent in ThemeIntent:
    var byState = newJObject()
    if intent in theme.states:
      for state in ThemeState:
        if state in theme.states[intent]:
          let props = propsToJson(theme.states[intent][state])
          if props.len > 0: byState[StateNames[ord(state)]] = props
    if byState.len > 0: states[IntentNames[ord(intent)]] = byState
  if states.len > 0: result["states"] = states
  var prefs = newJObject()
  for role in ControlRole:
    case theme.statePreference[role]
    of spFocusFirst: prefs[(if role == crText: "text" else: "pointer")] = newJString("focus")
    of spHoverFirst: prefs[(if role == crText: "text" else: "pointer")] = newJString("hover")
    of spRoleDefault: discard
  if prefs.len > 0: result["statePreference"] = prefs
  let m = theme.metrics
  var metrics = newJObject()
  template metric(field: untyped) =
    if m.field.isSome: metrics[astToStr(field)] = num(m.field.get)
  metric controlHeight
  metric indicatorSize
  metric trackThickness
  metric thumbSize
  metric progressHeight
  metric rowHeight
  metric scrollbarThickness
  if metrics.len > 0: result["metrics"] = metrics
  let h = theme.hint
  var hint = newJObject()
  if h.background.isSome: hint["background"] = newJString(formatColor(h.background.get))
  if h.foreground.isSome: hint["foreground"] = newJString(formatColor(h.foreground.get))
  if h.border.isSome: hint["border"] = newJString(formatColor(h.border.get))
  if h.borderWidth.isSome: hint["borderWidth"] = num(h.borderWidth.get)
  if h.fontSize.isSome: hint["fontSize"] = num(h.fontSize.get)
  if h.fontFamily.isSome: hint["fontFamily"] = newJString(h.fontFamily.get)
  if h.uppercase.isSome: hint["uppercase"] = newJBool(h.uppercase.get)
  if hint.len > 0: result["hint"] = hint
  let a = theme.animation
  var motion = newJObject()
  if a.durationFast.isSome: motion["durationFast"] = num(a.durationFast.get)
  if a.durationNormal.isSome: motion["durationNormal"] = num(a.durationNormal.get)
  if a.durationSlow.isSome: motion["durationSlow"] = num(a.durationSlow.get)
  if a.defaultEasing.isSome:
    let name = $a.defaultEasing.get
    motion["defaultEasing"] = newJString(name[0 .. 0].toLowerAscii & name[1 .. ^1])
  if motion.len > 0: result["animation"] = motion

proc yamlScalar(node: JsonNode): string =
  case node.kind
  of JString:
    let s = node.getStr
    # Quote anything YAML could read as something other than this string.
    let plain = s.len > 0 and s[0] in {'a' .. 'z', 'A' .. 'Z'} and
                s.allIt(it in {'a' .. 'z', 'A' .. 'Z', '0' .. '9', ' ', '-', '_'}) and
                s.toLowerAscii notin ["true", "false", "yes", "no", "null", "on", "off"]
    if plain: s else: escapeJson(s)
  of JBool: $node.getBool
  of JInt: $node.getInt
  of JFloat: $node.getFloat
  else: "null"

proc emitYaml(node: JsonNode, indent: int, result: var string) =
  let pad = repeat(' ', indent)
  for key, value in node:
    if value.kind == JObject:
      result.add pad & key & ":\n"
      emitYaml(value, indent + 2, result)
    else:
      result.add pad & key & ": " & yamlScalar(value) & "\n"

proc toYaml*(theme: Theme): string =
  ## The theme as a YAML file that `parseTheme` reads back to the same theme.
  emitYaml(themeToJson(theme), 0, result)

proc toJsonText*(theme: Theme): string = pretty(themeToJson(theme))


# ============================================================================
# describe: what a theme changed
# ============================================================================

proc diffJson(a, b: JsonNode, path: string, lines: var seq[string]) =
  ## Every leaf where `b` differs from `a`, as "path: was -> now".
  proc show(n: JsonNode): string =
    if n == nil: "(unset)" else: yamlScalar(n)
  if (a != nil and a.kind == JObject) or (b != nil and b.kind == JObject):
    var keys: seq[string]
    for src in [a, b]:
      if src != nil and src.kind == JObject:
        for k, _ in src:
          if k notin keys: keys.add k
    for k in keys:
      let av = if a != nil and a.kind == JObject and a.hasKey(k): a[k] else: nil
      let bv = if b != nil and b.kind == JObject and b.hasKey(k): b[k] else: nil
      diffJson(av, bv, (if path.len > 0: path & "." else: "") & k, lines)
  elif a != b:
    lines.add path & ": " & show(a) & " -> " & show(b)

proc describeChange*(parent, child: Theme): seq[string] =
  ## What `child` sets differently from `parent`, one line per property:
  ## `base.default.cornerRadius: 4 -> 0`, `states.default.hovered.hoverColor: (unset) -> #ff0000`.
  var a = themeToJson(parent)
  var b = themeToJson(child)
  a.delete("name"); b.delete("name")
  diffJson(a, b, "", result)
