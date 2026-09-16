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

import std/[tables, options, json, strutils, parseutils]
import yaml
import theme_sys_core
import theme_types
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
    # Layout
    padding: Option[PaddingFile]
    # Effects (as strings, converted to enums)
    bevelStyle: Option[string]
    gradientDirection: Option[string]

  ThemeFile* {.sparse.} = object
    ## Top-level theme file structure (JSON or YAML)
    name: Option[string]
    `extends`: Option[string]
    version: Option[string]
    base: Option[Table[string, ThemePropsFile]]
    states: Option[Table[string, Table[string, ThemePropsFile]]]

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

proc toTheme*(tf: ThemeFile, resolver: proc(name: string): Theme): Theme =
  ## Convert a ThemeFile to a Theme, resolving extends via resolver
  result = if tf.`extends`.isSome:
    resolver(tf.`extends`.get())
  else:
    newTheme()
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


proc parseThemeFile*(content: string, format: ThemeFileFormat): ThemeFile =
  ## Text to the intermediate file representation. Raises on malformed input,
  ## which is the caller's to report with a filename attached.
  case format
  of tffJson: parseJson(content).to(ThemeFile)
  of tffYaml:
    var tf: ThemeFile
    load(content, tf)
    tf

proc parseTheme*(content: string, format: ThemeFileFormat,
                 resolver: proc(name: string): Theme): Theme =
  ## Text straight to a `Theme`. The whole adapter in one call.
  toTheme(parseThemeFile(content, format), resolver)
