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
## YAML and JSON both become one JSON document. Per-state properties and the
## `brand:` section are read and written by the fields of ThemeProps and
## BrandSpec themselves (propsFromJson, brandSpecFrom, propsToJson): a setting
## is declared once, on the type that holds it. The other sections are small
## `*File` types read with std/json's `to`.

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

  BackdropFile* {.sparse.} = object
    ## The page behind a modal: `color` tints it ("#00000080"), `blur` softens
    ## it (pixels), `saturation` fades its colour (1 as is, 0 grey).
    color: Option[string]
    blur, saturation: Option[float32]

  BackgroundFile* {.sparse.} = object
    ## A picture behind everything, tiled: `image` (a path, relative to the
    ## theme file, or `tile:<name>` for one that ships, tiles.nim), `opacity`
    ## (0 .. 1) over the canvas colour, `scale` (a tile at this many times its
    ## size), `tint` (a colour that multiplies it).
    image, tint: Option[string]
    opacity, scale: Option[float32]

  ThemeFile* {.sparse.} = object
    ## Top-level theme file structure (JSON or YAML)
    name: Option[string]
    `extends`: Option[string]
    version: Option[string]
    # `base`, `states` and `brand` are read straight from the document, by
    # the fields of ThemeProps and BrandSpec themselves (propsFromJson,
    # brandSpecFrom): each setting is declared once, on the type that holds it.
    statePreference: Option[Table[string, string]]
      ## role ("text" / "pointer") -> "focus" / "hover"
    metrics: Option[MetricsFile]
    hint: Option[HintFile]
    animation: Option[AnimationFile]
    backdrop: Option[BackdropFile]
    background: Option[BackgroundFile]
    headingFont: Option[string]
      ## The font titles and headings use; the body font when left out.
    # The theme-wide looks (`themeWideNames`: tipShape, glass, fizz, pulse) are
    # top-level keys too, read and written by the fields of Theme.

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

# ============================================================================
# Settings declared once: read by the fields of the type that holds them
#
# A per-state property is a field of ThemeProps and a brand choice is a field of
# BrandSpec; the file format is those fields by name. Adding one is adding the
# field (and the code that draws it): reading, writing and key checking follow.
# ============================================================================

const legacyPropNames = ["gradientStart", "gradientEnd", "gradientDirection", "glowColor",
                         "glowRadius", "insetShadowDepth", "insetShadowOpacity",
                         "dropShadowBlur"]
  ## Older effect names, still read (mapped onto the finish), never written.
const unfiledPropNames = ["textStyle"]
  ## ThemeProps fields a file does not set.

proc expectKind(v: JsonNode, kinds: set[JsonNodeKind], where: string) =
  if v.kind notin kinds:
    raise newException(ValueError, "theme: " & where & " has the wrong type (" &
                       $v.kind & ")")

proc numberOf(v: JsonNode, where: string): float32 =
  expectKind(v, {JInt, JFloat}, where)
  v.getFloat.float32

proc paddingFrom(v: JsonNode, where: string): EdgeInsets =
  if v.kind in {JInt, JFloat}: return edgeInsets(numberOf(v, where))
  expectKind(v, {JObject}, where)
  template f(k: string): float32 = (if v.hasKey(k): numberOf(v[k], where & "." & k) else: 0'f32)
  if v.hasKey("all"): edgeInsets(f("all"))
  elif v.hasKey("horizontal") or v.hasKey("vertical"):
    edgeInsetsSymmetric(f("horizontal"), f("vertical"))
  else: edgeInsetsLTRB(f("left"), f("top"), f("right"), f("bottom"))

proc weightFrom(s: string): FontWeight =
  case s.toLowerAscii
  of "light", "300": Light
  of "medium", "500": Medium
  of "semibold", "600": SemiBold
  of "bold", "700": Bold
  of "extrabold", "800": ExtraBold
  else: Regular

proc bevelFrom(s: string): BevelStyle =
  case s.toLowerAscii
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
  of "beraised": BeRaised
  of "besunken": BeSunken
  else: Flat

proc propsFromJson*(node: JsonNode, where = "props"): ThemeProps =
  ## One intent's (or state's) properties from a theme document, by the
  ## fields of ThemeProps.
  # The older effect names, as the finish says them, first: a newer key below
  # wins over them.
  if node.hasKey("gradientStart") or node.hasKey("gradientEnd"):
    result.gradient = some(0.5'f32)
  if node.hasKey("glowColor"):
    result.focusGlowColor = some(parseColor(node["glowColor"].getStr))
    result.focusGlowRadius = some(if node.hasKey("glowRadius"): numberOf(node["glowRadius"], where)
                                  else: 6'f32)
  if node.hasKey("insetShadowDepth"):
    result.relief = some(-abs(numberOf(node["insetShadowDepth"], where)))
  if node.hasKey("dropShadowBlur"):
    result.softShadow = some(numberOf(node["dropShadowBlur"], where))
  for name, field in fieldPairs(result):
    if node.hasKey(name):
      let v = node[name]
      let at = where & "." & name
      when field is Option[Color]:
        expectKind(v, {JString}, at); field = some(parseColor(v.getStr))
      elif field is Option[float32]:
        field = some(numberOf(v, at))
      elif field is Option[bool]:
        expectKind(v, {JBool}, at); field = some(v.getBool)
      elif field is Option[string]:
        expectKind(v, {JString}, at); field = some(v.getStr)
      elif field is Option[EdgeInsets]:
        field = some(paddingFrom(v, at))
      elif field is Option[FontWeight]:
        expectKind(v, {JString, JInt}, at)
        field = some(weightFrom(if v.kind == JInt: $v.getInt else: v.getStr))
      elif field is Option[BevelStyle]:
        expectKind(v, {JString}, at); field = some(bevelFrom(v.getStr))
      elif field is Option[tuple[x, y: float32]]:
        let o = numberOf(v, at)             # one offset, right and down
        field = some((o, o))

proc propKeys(): seq[string] =
  ## The keys a properties block may use.
  var p: ThemeProps
  for name, _ in fieldPairs(p):
    if name notin unfiledPropNames: result.add name
  for n in legacyPropNames: result.add n

proc brandSpecFrom*(node: JsonNode): BrandSpec =
  ## A `brand:` section, by the fields of BrandSpec (colours as strings).
  ## What is left out takes the spec's own default.
  result.name = "Brand"
  for name, field in fieldPairs(result):
    if node.hasKey(name):
      let v = node[name]
      let at = "brand." & name
      when field is Color:
        expectKind(v, {JString}, at); field = parseColor(v.getStr)
      elif field is float32:
        field = numberOf(v, at)
      elif field is bool:
        expectKind(v, {JBool}, at); field = v.getBool
      elif field is string:
        expectKind(v, {JString}, at); field = v.getStr
      else:
        raise newException(ValueError, "theme: " & at & " cannot be set in a file")

proc num(v: float32): JsonNode

const themeWideNames = ["tipShape", "glass", "fizz", "pulse"]
  ## The Theme fields that are theme-wide looks, written as top-level keys of a
  ## theme file. A new one is a Theme field and its name here.

proc tipShapeName(t: TipShape): string =
  case t
  of tsBox: "box"
  of tsBubble: "bubble"

proc readThemeWide(theme: var Theme, doc: JsonNode) =
  ## The theme-wide looks a document sets, by the fields of Theme.
  for name, field in fieldPairs(theme):
    when name in themeWideNames:
      if doc.hasKey(name):
        let v = doc[name]
        when field is float32:
          field = max(0'f32, numberOf(v, name))
        elif field is bool:
          expectKind(v, {JBool}, name); field = v.getBool
        elif field is TipShape:
          expectKind(v, {JString}, name)
          var found = false
          for t in TipShape:
            if tipShapeName(t) == v.getStr.toLowerAscii:
              field = t; found = true
          if not found:
            raise newException(ValueError, "tipShape is \"box\" or \"bubble\", not \"" &
                               v.getStr & "\"")

proc writeThemeWide(theme: Theme, dest: JsonNode) =
  ## The theme-wide looks a theme sets (not their defaults), by its fields.
  for name, field in fieldPairs(theme):
    when name in themeWideNames:
      when field is float32:
        if field > 0: dest[name] = num(field)
      elif field is bool:
        if field: dest[name] = newJBool(true)
      elif field is TipShape:
        if field != TipShape.low: dest[name] = newJString(tipShapeName(field))

proc brandKeys(): seq[string] =
  var b: BrandSpec
  for name, field in fieldPairs(b):
    when field is Color or field is float32 or field is bool or field is string:
      result.add name

proc toTheme*(tf: ThemeFile, doc: JsonNode, resolver: proc(name: string): Theme): Theme =
  ## A theme from its file: the typed sections in `tf`, and `base`, `states`
  ## and `brand` read from the document `doc` by the types that hold them.
  ## `extends` is resolved by `resolver`.
  let hasBrand = doc.hasKey("brand")
  result = if hasBrand:
    brandTheme(brandSpecFrom(doc["brand"]))
  elif tf.`extends`.isSome:
    resolver(tf.`extends`.get())
  else:
    newTheme()
  if tf.`extends`.isSome and not hasBrand:
    result.parent = tf.`extends`.get()
  if tf.name.isSome:
    result.name = tf.name.get()
  if tf.version.isSome:
    result.version = tf.version.get()
  if doc.hasKey("base"):
    for intentKey, propsNode in doc["base"]:
      let intent = parseIntentName(intentKey)
      let props = propsFromJson(propsNode, "base." & intentKey)
      var merged = result.base.getOrDefault(intent, ThemeProps())
      merged.merge(props)
      result.base[intent] = merged
  if doc.hasKey("states"):
    for intentKey, stateTable in doc["states"]:
      let intent = parseIntentName(intentKey)
      for stateKey, propsNode in stateTable:
        let state = parseStateName(stateKey)
        let props = propsFromJson(propsNode, "states." & intentKey & "." & stateKey)
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
  if tf.backdrop.isSome:
    let b = tf.backdrop.get()
    if b.color.isSome: result.backdrop.color = some(parseColor(b.color.get()))
    if b.blur.isSome: result.backdrop.blur = b.blur
    if b.saturation.isSome: result.backdrop.saturation = b.saturation
  if tf.headingFont.isSome: result.typography.headingFont = tf.headingFont
  readThemeWide(result, doc)
  if tf.background.isSome:
    let bg = tf.background.get()
    if bg.image.isSome: result.assets.backgroundPattern = bg.image
    if bg.opacity.isSome: result.assets.backgroundPatternOpacity = bg.opacity
    if bg.scale.isSome: result.assets.backgroundScale = bg.scale
    if bg.tint.isSome: result.assets.backgroundTint = optColor(bg.tint)
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
  checkKeys(node, where, propKeys())
  if node.hasKey("padding") and node["padding"].kind == JObject:
    checkKeys(node["padding"], where & ".padding", fieldNames(PaddingFile))

proc validateThemeNode*(root: JsonNode) =
  ## Raise a ValueError naming the first key a theme file has that the format
  ## does not. Intent, state and role names are checked by their own parsers.
  checkKeys(root, "the top level", fieldNames(ThemeFile) & @["base", "states", "brand"] &
            @themeWideNames)
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
  if root.hasKey("backdrop"):
    checkKeys(root["backdrop"], "backdrop", fieldNames(BackdropFile))
  if root.hasKey("background"):
    checkKeys(root["background"], "background", fieldNames(BackgroundFile))
  if root.hasKey("brand"):
    checkKeys(root["brand"], "brand", brandKeys())

proc parseThemeDoc*(content: string, format: ThemeFileFormat): JsonNode =
  ## Text to the theme document, checked: YAML and JSON alike. Raises on
  ## malformed input or an unknown key, which the caller reports with a
  ## filename attached.
  result = case format
    of tffJson: parseJson(content)
    of tffYaml:
      let docs = loadToJson(content)
      if docs.len > 0: docs[0] else: newJObject()
  if result.kind == JNull: result = newJObject()
  validateThemeNode(result)

proc parseThemeFile*(content: string, format: ThemeFileFormat): ThemeFile =
  ## The typed sections of a theme file (the document's other keys are read
  ## by `toTheme`).
  parseThemeDoc(content, format).to(ThemeFile)

proc parseTheme*(content: string, format: ThemeFileFormat,
                 resolver: proc(name: string): Theme): Theme =
  ## Text straight to a `Theme`. The whole adapter in one call.
  let doc = parseThemeDoc(content, format)
  toTheme(doc.to(ThemeFile), doc, resolver)


# ============================================================================
# Theme -> file: the other direction
#
# What `parseTheme` reads, `toYaml` writes: only what the theme sets, so the
# file of a derived theme names what it changed. Brand-derived themes come out
# as the base/states tables they were expanded into (the `brand:` shorthand is
# a way to *write* a theme, not part of one). Not written: `extends` (a Theme
# no longer knows its parent), and the unused branding fields. A background
# picture is written as the theme holds it: a file's relative path was made
# absolute when the file was loaded (theme_manager.loadFromFile).
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
  ## The properties that are set, by the fields of ThemeProps: what
  ## `propsFromJson` reads back.
  result = newJObject()
  for name, field in fieldPairs(p):
    when field is Option[Color]:
      if field.isSome: result[name] = newJString(formatColor(field.get))
    elif field is Option[float32]:
      if field.isSome: result[name] = num(field.get)
    elif field is Option[bool]:
      if field.isSome: result[name] = newJBool(field.get)
    elif field is Option[string]:
      if field.isSome: result[name] = newJString(field.get)
    elif field is Option[FontWeight]:
      if field.isSome:
        result[name] = newJString(case field.get
          of Light: "light"
          of Regular: "regular"
          of Medium: "medium"
          of SemiBold: "semibold"
          of Bold: "bold"
          of ExtraBold: "extrabold")
    elif field is Option[BevelStyle]:
      if field.isSome: result[name] = newJString(($field.get).toLowerAscii)
    elif field is Option[tuple[x, y: float32]]:
      if field.isSome:
        let o = field.get
        if o.x != o.y:
          raise newException(ValueError,
            name & " " & $o.x & "," & $o.y & " cannot be written: the theme " &
            "format has one offset for right and down")
        result[name] = num(o.x)
    elif field is Option[EdgeInsets]:
      if field.isSome:
        let e = field.get
        result[name] =
          if e.top == e.bottom and e.left == e.right and e.top == e.left:
            %*{"all": num(e.top)}
          elif e.top == e.bottom and e.left == e.right:
            %*{"horizontal": num(e.left), "vertical": num(e.top)}
          else:
            %*{"left": num(e.left), "top": num(e.top), "right": num(e.right),
               "bottom": num(e.bottom)}

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
  let bd = theme.backdrop
  var backdrop = newJObject()
  if bd.color.isSome: backdrop["color"] = newJString(formatColor(bd.color.get))
  if bd.blur.isSome: backdrop["blur"] = num(bd.blur.get)
  if bd.saturation.isSome: backdrop["saturation"] = num(bd.saturation.get)
  if backdrop.len > 0: result["backdrop"] = backdrop
  let assets = theme.assets
  var background = newJObject()
  if assets.backgroundPattern.isSome: background["image"] = newJString(assets.backgroundPattern.get)
  if assets.backgroundPatternOpacity.isSome:
    background["opacity"] = num(assets.backgroundPatternOpacity.get)
  if assets.backgroundScale.isSome: background["scale"] = num(assets.backgroundScale.get)
  if assets.backgroundTint.isSome: background["tint"] = newJString(formatColor(assets.backgroundTint.get))
  if theme.typography.headingFont.isSome:
    result["headingFont"] = newJString(theme.typography.headingFont.get)
  writeThemeWide(theme, result)
  if background.len > 0: result["background"] = background

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
