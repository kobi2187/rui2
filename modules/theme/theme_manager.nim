## Theme Manager - Unified theme loading, registration, and switching
##
## Module copy with adjusted import paths.
## See drawing_primitives/theme_manager.nim for full documentation.

import std/[tables, options, os, json, strutils, parseutils]
import yaml
import ./theme_sys_core
import ./theme_types
import ./builtin_themes
import ../../core/types

export theme_sys_core, theme_types

# ============================================================================
# File Format Types (for json.to / yaml.load deserialization)
# ============================================================================
#
# Colors in files are hex strings ("#rrggbb" or "#rrggbbaa") or
# rgb(r,g,b) format. These intermediate types hold strings, then
# toThemeProps converts to actual Color objects.

type
  PaddingFile {.sparse.} = object
    all: Option[float32]
    top: Option[float32]
    right: Option[float32]
    bottom: Option[float32]
    left: Option[float32]
    horizontal: Option[float32]
    vertical: Option[float32]

  ThemePropsFile {.sparse.} = object
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

  ThemeFile {.sparse.} = object
    ## Top-level theme file structure (JSON or YAML)
    name: Option[string]
    `extends`: Option[string]
    version: Option[string]
    base: Option[Table[string, ThemePropsFile]]
    states: Option[Table[string, Table[string, ThemePropsFile]]]

# ============================================================================
# Color Parsing
# ============================================================================

proc parseColor(val: string): Color =
  ## Parse "#rrggbb", "#rrggbbaa", or "rgb(r,g,b)" to Color
  var s = val.strip()
  if s.startsWith("rgb"):
    let inner = s.replace("rgb(", "").replace("rgba(", "").replace(")", "").strip()
    let parts = inner.split(",")
    when defined(useGraphics):
      if parts.len >= 3:
        return Color(
          r: uint8(parseInt(parts[0].strip())),
          g: uint8(parseInt(parts[1].strip())),
          b: uint8(parseInt(parts[2].strip())),
          a: uint8(if parts.len == 4: parseInt(parts[3].strip()) else: 255))
    else:
      return Color()
  else:
    if s.startsWith("#"): s = s[1..^1]
    when defined(useGraphics):
      var r, g, b, a: int
      if s.len >= 6:
        discard parseHex(s[0..1], r)
        discard parseHex(s[2..3], g)
        discard parseHex(s[4..5], b)
        a = if s.len == 8: (discard parseHex(s[6..7], a); a) else: 255
        return Color(r: uint8(r), g: uint8(g), b: uint8(b), a: uint8(a))
    else:
      return Color()

proc optColor(s: Option[string]): Option[Color] =
  if s.isSome: some(parseColor(s.get())) else: none(Color)

# ============================================================================
# Conversion: File Types -> Theme Types
# ============================================================================

proc parseIntentName(s: string): ThemeIntent =
  case s.toLowerAscii()
  of "default": Default
  of "info": Info
  of "success": Success
  of "warning": Warning
  of "danger": Danger
  else: Default

proc parseStateName(s: string): ThemeState =
  case s.toLowerAscii()
  of "normal": Normal
  of "disabled": Disabled
  of "hovered": Hovered
  of "pressed": Pressed
  of "focused": Focused
  of "selected": Selected
  of "dragover": DragOver
  else: Normal

proc toThemeProps(fp: ThemePropsFile): ThemeProps =
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

proc toTheme(tf: ThemeFile, resolver: proc(name: string): Theme): Theme =
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

# ============================================================================
# ThemeManager
# ============================================================================

type
  ThemeManager* = ref object
    current*: Theme
    cache: ThemeCache
    registry: Table[string, Theme]
    searchPaths*: seq[string]

proc newThemeManager*(): ThemeManager =
  ## Create a ThemeManager with the 5 built-in themes registered.
  ## Sets "light" as the initial theme.
  result = ThemeManager(
    current: newTheme("Default"),
    cache: ThemeCache(),
    registry: initTable[string, Theme](),
    searchPaths: @[]
  )
  result.registry["light"] = createLightTheme()
  result.registry["dark"] = createDarkTheme()
  result.registry["beos"] = createBeosTheme()
  result.registry["joy"] = createJoyTheme()
  result.registry["wide"] = createWideTheme()
  result.current = result.registry["light"]
  setCurrentTheme(result.current)

# ============================================================================
# Registry
# ============================================================================

proc register*(tm: ThemeManager, name: string, theme: Theme) =
  ## Register a theme by name (overwrites if exists)
  tm.registry[name] = theme

proc unregister*(tm: ThemeManager, name: string) =
  tm.registry.del(name)

proc has*(tm: ThemeManager, name: string): bool =
  name in tm.registry

proc get*(tm: ThemeManager, name: string): Theme =
  if name notin tm.registry:
    raise newException(ValueError, "Unknown theme: " & name)
  tm.registry[name]

proc listThemes*(tm: ThemeManager): seq[string] =
  for name in tm.registry.keys:
    result.add(name)

proc addSearchPath*(tm: ThemeManager, path: string) =
  if path notin tm.searchPaths:
    tm.searchPaths.add(path)

# ============================================================================
# Theme Switching
# ============================================================================

proc setTheme*(tm: ThemeManager, theme: Theme) =
  ## Set the active theme directly
  tm.current = theme
  tm.cache = ThemeCache()
  setCurrentTheme(theme)

proc setTheme*(tm: ThemeManager, name: string) =
  ## Set the active theme by registered name
  if name notin tm.registry:
    raise newException(ValueError, "Unknown theme: " & name &
      ". Available: " & tm.listThemes().join(", "))
  tm.setTheme(tm.registry[name])

proc getProps*(tm: ThemeManager, intent: ThemeIntent = Default,
               state: ThemeState = Normal): ThemeProps =
  ## Get themed properties for intent+state (cached)
  tm.cache.getOrCreateProps(tm.current, intent, state)

# ============================================================================
# Theme Derivation (Programmatic Inheritance)
# ============================================================================

proc derive*(tm: ThemeManager, baseName: string, newName: string = ""): Theme =
  ## Create a new theme as a copy of a registered base.
  ## Modify the returned Theme, then register it.
  if baseName notin tm.registry:
    raise newException(ValueError, "Unknown base theme: " & baseName)
  let base = tm.registry[baseName]
  result = newTheme(if newName.len > 0: newName else: base.name & " (derived)")
  result.version = base.version
  for intent in ThemeIntent:
    if intent in base.base:
      result.base[intent] = base.base[intent]
    if intent in base.states:
      for state, props in base.states[intent]:
        result.states[intent][state] = props
  result.brandPalette = base.brandPalette
  result.typography = base.typography
  result.spacing = base.spacing
  result.animation = base.animation
  result.assets = base.assets
  result.metadata = base.metadata

# ============================================================================
# File Loading
# ============================================================================

proc makeResolver(tm: ThemeManager, dir: string): proc(name: string): Theme =
  ## Create a resolver that checks registry first, then sibling files
  result = proc(name: string): Theme =
    if name in tm.registry:
      return tm.derive(name)
    for ext in [".yaml", ".yml", ".json"]:
      let siblingPath = dir / name & ext
      if fileExists(siblingPath):
        let content = readFile(siblingPath)
        var tf: ThemeFile
        if ext == ".json":
          tf = parseJson(content).to(ThemeFile)
        else:
          load(content, tf)
        return toTheme(tf, tm.makeResolver(dir))
    newTheme(name)

proc loadFromFile*(tm: ThemeManager, path: string): Theme =
  ## Load a theme from a JSON or YAML file (auto-detected by extension).
  ## Supports "extends" referencing registered themes or sibling files.
  if not fileExists(path):
    raise newException(IOError, "Theme file not found: " & path)
  let content = readFile(path)
  let ext = path.splitFile().ext.toLowerAscii()
  let dir = parentDir(path)
  var tf: ThemeFile
  if ext == ".json":
    tf = parseJson(content).to(ThemeFile)
  else:
    load(content, tf)
  result = toTheme(tf, tm.makeResolver(dir))
  # Auto-register under filename if not already registered
  let regName = if result.name.len > 0: result.name
                else: path.splitFile().name
  if regName notin tm.registry:
    tm.register(regName, result)

proc loadFromJsonString*(tm: ThemeManager, jsonStr: string): Theme =
  let tf = parseJson(jsonStr).to(ThemeFile)
  toTheme(tf, proc(name: string): Theme =
    if name in tm.registry: tm.derive(name) else: newTheme(name))

proc loadFromYamlString*(tm: ThemeManager, yamlStr: string): Theme =
  var tf: ThemeFile
  load(yamlStr, tf)
  toTheme(tf, proc(name: string): Theme =
    if name in tm.registry: tm.derive(name) else: newTheme(name))

proc loadTheme*(tm: ThemeManager, nameOrPath: string): Theme =
  ## Load a theme by name (from registry), file path, or search in searchPaths.
  if nameOrPath in tm.registry:
    return tm.registry[nameOrPath]
  if fileExists(nameOrPath):
    return tm.loadFromFile(nameOrPath)
  for dir in tm.searchPaths:
    for ext in ["", ".json", ".yaml", ".yml"]:
      let path = dir / nameOrPath & ext
      if fileExists(path):
        return tm.loadFromFile(path)
  raise newException(ValueError, "Theme not found: " & nameOrPath &
    ". Registered: " & tm.listThemes().join(", "))

proc loadAndSet*(tm: ThemeManager, nameOrPath: string) =
  ## Load a theme and set it as current.
  tm.setTheme(tm.loadTheme(nameOrPath))
