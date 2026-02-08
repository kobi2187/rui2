## Theme Manager - Unified theme loading, registration, and switching
##
## Consolidates all theme operations into a single object:
## - Built-in themes: light, dark, beos, joy, wide
## - Load from JSON or YAML files (no external dependencies)
## - Theme inheritance: "extends" field in theme files
## - Programmatic derivation: derive("dark", "My Custom")
## - Cache for fast (intent, state) -> ThemeProps lookups
## - Syncs global currentTheme for widget access during rendering
##
## Usage:
##   let tm = newThemeManager()       # registers 5 built-in themes
##   tm.setTheme("dark")             # switch by name
##   let t = tm.loadFromFile("custom.yaml")  # supports extends
##   tm.register("custom", t)
##   tm.setTheme("custom")
##   var corp = tm.derive("light", "Corporate")  # copy + override
##   corp.base[Default].cornerRadius = some(0.0f32)
##   tm.register("corporate", corp)

import std/[tables, options, os, json, strutils, parseutils]
import theme_sys_core
import theme_types
import builtin_themes
import ../core/types

export theme_sys_core, theme_types

type
  ThemeManager* = ref object
    current*: Theme
    cache: ThemeCache
    registry: Table[string, Theme]
    searchPaths*: seq[string]

# ============================================================================
# Construction
# ============================================================================

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
  ## Remove a theme from the registry
  tm.registry.del(name)

proc has*(tm: ThemeManager, name: string): bool =
  ## Check if a theme is registered
  name in tm.registry

proc get*(tm: ThemeManager, name: string): Theme =
  ## Get a registered theme by name
  if name notin tm.registry:
    raise newException(ValueError, "Unknown theme: " & name)
  tm.registry[name]

proc listThemes*(tm: ThemeManager): seq[string] =
  ## List all registered theme names
  for name in tm.registry.keys:
    result.add(name)

proc addSearchPath*(tm: ThemeManager, path: string) =
  ## Add a directory to search for theme files
  if path notin tm.searchPaths:
    tm.searchPaths.add(path)

# ============================================================================
# Theme Switching
# ============================================================================

proc setTheme*(tm: ThemeManager, theme: Theme) =
  ## Set the active theme directly
  tm.current = theme
  tm.cache = ThemeCache()  # Clear cache on theme change
  setCurrentTheme(theme)   # Update global for widget access

proc setTheme*(tm: ThemeManager, name: string) =
  ## Set the active theme by name (must be registered)
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
  ## Create a new theme as a copy of a registered base theme.
  ## Modify the returned Theme, then register it.
  if baseName notin tm.registry:
    raise newException(ValueError, "Unknown base theme: " & baseName)
  let base = tm.registry[baseName]
  result = newTheme(if newName.len > 0: newName else: base.name & " (derived)")
  # Copy all base and state properties
  for intent in ThemeIntent:
    if intent in base.base:
      result.base[intent] = base.base[intent]
    if intent in base.states:
      for state, props in base.states[intent]:
        result.states[intent][state] = props
  # Copy branding
  result.brandPalette = base.brandPalette
  result.typography = base.typography
  result.spacing = base.spacing
  result.animation = base.animation
  result.assets = base.assets
  result.metadata = base.metadata

proc mergeOverrides(target: var Theme, overrides: Theme) =
  ## Merge override properties on top of target (mutates target)
  if overrides.name.len > 0:
    target.name = overrides.name
  for intent in ThemeIntent:
    if intent in overrides.base:
      var merged = target.base.getOrDefault(intent, ThemeProps())
      merged.merge(overrides.base[intent])
      target.base[intent] = merged
    if intent in overrides.states:
      for state, props in overrides.states[intent]:
        var merged = target.states[intent].getOrDefault(state, ThemeProps())
        merged.merge(props)
        target.states[intent][state] = merged

# ============================================================================
# Color Parsing
# ============================================================================

proc parseHexColor(hex: string): Color =
  var s = hex.strip()
  if s.startsWith("#"):
    s = s[1..^1]
  when defined(useGraphics):
    if s.len == 6:
      var r, g, b: int
      discard parseHex(s[0..1], r)
      discard parseHex(s[2..3], g)
      discard parseHex(s[4..5], b)
      result = Color(r: uint8(r), g: uint8(g), b: uint8(b), a: 255)
    elif s.len == 8:
      var r, g, b, a: int
      discard parseHex(s[0..1], r)
      discard parseHex(s[2..3], g)
      discard parseHex(s[4..5], b)
      discard parseHex(s[6..7], a)
      result = Color(r: uint8(r), g: uint8(g), b: uint8(b), a: uint8(a))
  else:
    result = Color()

proc parseRgbColor(rgb: string): Color =
  let inner = rgb.replace("rgb(", "").replace("rgba(", "").replace(")", "").strip()
  let parts = inner.split(",")
  when defined(useGraphics):
    if parts.len >= 3:
      let r = parseInt(parts[0].strip())
      let g = parseInt(parts[1].strip())
      let b = parseInt(parts[2].strip())
      let a = if parts.len == 4: parseInt(parts[3].strip()) else: 255
      result = Color(r: uint8(r), g: uint8(g), b: uint8(b), a: uint8(a))
  else:
    result = Color()

proc parseColorValue(val: string): Color =
  if val.startsWith("#"):
    parseHexColor(val)
  elif val.startsWith("rgb"):
    parseRgbColor(val)
  else:
    parseHexColor(val)  # Try as hex without #

# ============================================================================
# JSON Loading
# ============================================================================

proc parseThemePropsFromJson(node: JsonNode): ThemeProps =
  result = ThemeProps()
  if node.kind != JObject: return

  if node.hasKey("backgroundColor"):
    result.backgroundColor = some(parseColorValue(node["backgroundColor"].getStr()))
  if node.hasKey("foregroundColor"):
    result.foregroundColor = some(parseColorValue(node["foregroundColor"].getStr()))
  if node.hasKey("borderColor"):
    result.borderColor = some(parseColorValue(node["borderColor"].getStr()))
  if node.hasKey("hoverColor"):
    result.hoverColor = some(parseColorValue(node["hoverColor"].getStr()))
  if node.hasKey("pressedColor"):
    result.pressedColor = some(parseColorValue(node["pressedColor"].getStr()))
  if node.hasKey("activeColor"):
    result.activeColor = some(parseColorValue(node["activeColor"].getStr()))
  if node.hasKey("focusColor"):
    result.focusColor = some(parseColorValue(node["focusColor"].getStr()))
  if node.hasKey("focusRingColor"):
    result.focusRingColor = some(parseColorValue(node["focusRingColor"].getStr()))
  if node.hasKey("highlightColor"):
    result.highlightColor = some(parseColorValue(node["highlightColor"].getStr()))
  if node.hasKey("shadowColor"):
    result.shadowColor = some(parseColorValue(node["shadowColor"].getStr()))
  if node.hasKey("darkShadowColor"):
    result.darkShadowColor = some(parseColorValue(node["darkShadowColor"].getStr()))
  if node.hasKey("gradientStart"):
    result.gradientStart = some(parseColorValue(node["gradientStart"].getStr()))
  if node.hasKey("gradientEnd"):
    result.gradientEnd = some(parseColorValue(node["gradientEnd"].getStr()))
  if node.hasKey("glowColor"):
    result.glowColor = some(parseColorValue(node["glowColor"].getStr()))
  if node.hasKey("focusGlowColor"):
    result.focusGlowColor = some(parseColorValue(node["focusGlowColor"].getStr()))
  if node.hasKey("dropShadowColor"):
    result.dropShadowColor = some(parseColorValue(node["dropShadowColor"].getStr()))

  if node.hasKey("borderWidth"):
    result.borderWidth = some(node["borderWidth"].getFloat().float32)
  if node.hasKey("cornerRadius"):
    result.cornerRadius = some(node["cornerRadius"].getFloat().float32)
  if node.hasKey("fontSize"):
    result.fontSize = some(node["fontSize"].getFloat().float32)
  if node.hasKey("spacing"):
    result.spacing = some(node["spacing"].getFloat().float32)
  if node.hasKey("focusRingWidth"):
    result.focusRingWidth = some(node["focusRingWidth"].getFloat().float32)
  if node.hasKey("focusGlowRadius"):
    result.focusGlowRadius = some(node["focusGlowRadius"].getFloat().float32)
  if node.hasKey("glowRadius"):
    result.glowRadius = some(node["glowRadius"].getFloat().float32)
  if node.hasKey("insetShadowDepth"):
    result.insetShadowDepth = some(node["insetShadowDepth"].getFloat().float32)
  if node.hasKey("insetShadowOpacity"):
    result.insetShadowOpacity = some(node["insetShadowOpacity"].getFloat().float32)
  if node.hasKey("dropShadowBlur"):
    result.dropShadowBlur = some(node["dropShadowBlur"].getFloat().float32)
  if node.hasKey("fontFamily"):
    result.fontFamily = some(node["fontFamily"].getStr())

  if node.hasKey("padding"):
    let p = node["padding"]
    if p.kind == JInt or p.kind == JFloat:
      let val = p.getFloat().float32
      result.padding = some(edgeInsets(val))
    elif p.kind == JObject:
      if p.hasKey("all"):
        result.padding = some(edgeInsets(p["all"].getFloat().float32))
      else:
        let top = if p.hasKey("top"): p["top"].getFloat().float32 else: 0.0f32
        let right = if p.hasKey("right"): p["right"].getFloat().float32 else: 0.0f32
        let bottom = if p.hasKey("bottom"): p["bottom"].getFloat().float32 else: 0.0f32
        let left = if p.hasKey("left"): p["left"].getFloat().float32 else: 0.0f32
        if p.hasKey("horizontal") or p.hasKey("vertical"):
          let h = if p.hasKey("horizontal"): p["horizontal"].getFloat().float32 else: 0.0f32
          let v = if p.hasKey("vertical"): p["vertical"].getFloat().float32 else: 0.0f32
          result.padding = some(edgeInsetsSymmetric(h, v))
        else:
          result.padding = some(edgeInsetsLTRB(left, top, right, bottom))

  if node.hasKey("bevelStyle"):
    let s = node["bevelStyle"].getStr().toLowerAscii()
    let style = case s
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
      else: Flat
    result.bevelStyle = some(style)

  if node.hasKey("gradientDirection"):
    let s = node["gradientDirection"].getStr().toLowerAscii()
    let dir = case s
      of "vertical": theme_types.Vertical
      of "horizontal": theme_types.Horizontal
      of "radial": theme_types.Radial
      else: theme_types.Vertical
    result.gradientDirection = some(dir)

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

proc themeFromJson(node: JsonNode, resolver: proc(name: string): Theme): Theme =
  ## Parse a Theme from a JSON object, using resolver for extends
  result = newTheme()

  # Handle inheritance
  if node.hasKey("extends"):
    let baseName = node["extends"].getStr()
    result = resolver(baseName)

  if node.hasKey("name"):
    result.name = node["name"].getStr()

  if node.hasKey("base"):
    for intentKey, propsNode in node["base"].pairs():
      let intent = parseIntentName(intentKey)
      let props = parseThemePropsFromJson(propsNode)
      var merged = result.base.getOrDefault(intent, ThemeProps())
      merged.merge(props)
      result.base[intent] = merged

  if node.hasKey("states"):
    for intentKey, stateTable in node["states"].pairs():
      let intent = parseIntentName(intentKey)
      for stateKey, propsNode in stateTable.pairs():
        let state = parseStateName(stateKey)
        let props = parseThemePropsFromJson(propsNode)
        var merged = result.states[intent].getOrDefault(state, ThemeProps())
        merged.merge(props)
        result.states[intent][state] = merged

# ============================================================================
# Simple YAML Parser (covers theme file subset, no external deps)
# ============================================================================

proc yamlToJson(yamlContent: string): JsonNode =
  ## Convert simple YAML (as used by theme files) to a JsonNode tree.
  ## Handles: key: value, nested mappings via indentation, comments, blank lines.
  ## Does NOT handle: arrays, multi-line strings, anchors, tags, flow style.

  type StackEntry = tuple[indent: int, node: JsonNode, key: string]

  result = newJObject()
  var stack: seq[StackEntry] = @[(indent: -1, node: result, key: "")]

  for line in yamlContent.splitLines():
    # Skip blank lines and comments
    let trimmed = line.strip()
    if trimmed.len == 0 or trimmed.startsWith("#"):
      continue

    # Measure indentation
    var indent = 0
    for c in line:
      if c == ' ': inc indent
      else: break

    # Pop stack to find parent at correct indent level
    while stack.len > 1 and stack[^1].indent >= indent:
      discard stack.pop()

    let parent = stack[^1].node

    # Parse key: value
    let colonPos = trimmed.find(':')
    if colonPos < 0:
      continue

    let key = trimmed[0 ..< colonPos].strip()
    let rawValue = trimmed[colonPos + 1 .. ^1].strip()

    if rawValue.len == 0:
      # Section header (key with no value) -> nested object
      let child = newJObject()
      parent[key] = child
      stack.add((indent: indent, node: child, key: key))
    else:
      # Leaf value - determine type
      let unquoted = rawValue.strip(chars = {'"', '\''})

      # Try int
      try:
        let intVal = parseInt(unquoted)
        parent[key] = newJInt(intVal)
        continue
      except ValueError:
        discard

      # Try float
      try:
        let floatVal = parseFloat(unquoted)
        parent[key] = newJFloat(floatVal)
        continue
      except ValueError:
        discard

      # String
      parent[key] = newJString(unquoted)

# ============================================================================
# File Loading
# ============================================================================

proc loadFromJson*(tm: ThemeManager, node: JsonNode): Theme =
  ## Load a theme from a parsed JSON object.
  ## Supports "extends" referencing a registered theme name.
  themeFromJson(node, proc(name: string): Theme =
    if name in tm.registry:
      # Return a copy so the base isn't mutated
      tm.derive(name)
    else:
      newTheme(name)
  )

proc loadFromJsonString*(tm: ThemeManager, jsonStr: string): Theme =
  ## Load a theme from a JSON string
  tm.loadFromJson(parseJson(jsonStr))

proc loadFromYamlString*(tm: ThemeManager, yamlStr: string): Theme =
  ## Load a theme from a YAML string (simple subset used by theme files)
  tm.loadFromJson(yamlToJson(yamlStr))

proc loadFromFile*(tm: ThemeManager, path: string): Theme =
  ## Load a theme from a JSON or YAML file (auto-detected by extension).
  ## Supports "extends" referencing registered themes or sibling files.
  if not fileExists(path):
    raise newException(IOError, "Theme file not found: " & path)

  let content = readFile(path)
  let ext = path.splitFile().ext.toLowerAscii()

  let node = if ext == ".json":
    parseJson(content)
  else:
    # .yaml, .yml, or anything else -> try YAML
    yamlToJson(content)

  # Resolver: check registry first, then look for sibling files
  let dir = parentDir(path)
  themeFromJson(node, proc(name: string): Theme =
    # Check registry
    if name in tm.registry:
      return tm.derive(name)
    # Check sibling files
    for ext in [".yaml", ".yml", ".json"]:
      let siblingPath = dir / name & ext
      if fileExists(siblingPath):
        return tm.loadFromFile(siblingPath)
    # Check bare name as file
    let barePath = dir / name
    if fileExists(barePath):
      return tm.loadFromFile(barePath)
    # Fallback to empty
    newTheme(name)
  )

proc loadTheme*(tm: ThemeManager, nameOrPath: string): Theme =
  ## Load a theme by name (from registry), file path, or search in searchPaths.
  # 1. Check registry
  if nameOrPath in tm.registry:
    return tm.registry[nameOrPath]

  # 2. Check as direct file path
  if fileExists(nameOrPath):
    return tm.loadFromFile(nameOrPath)

  # 3. Search in searchPaths
  for dir in tm.searchPaths:
    for ext in ["", ".json", ".yaml", ".yml"]:
      let path = dir / nameOrPath & ext
      if fileExists(path):
        return tm.loadFromFile(path)

  raise newException(ValueError, "Theme not found: " & nameOrPath &
    ". Registered: " & tm.listThemes().join(", "))

proc loadAndSet*(tm: ThemeManager, nameOrPath: string) =
  ## Load a theme and set it as current in one step.
  ## If loaded from file, registers it under its name.
  let theme = tm.loadTheme(nameOrPath)
  if theme.name.len > 0 and theme.name notin tm.registry:
    tm.register(theme.name, theme)
  tm.setTheme(theme)

proc loadAndRegister*(tm: ThemeManager, path: string, name: string = ""): Theme =
  ## Load a theme from file and register it.
  ## Uses the given name, or the theme's own name field.
  result = tm.loadFromFile(path)
  let regName = if name.len > 0: name
                elif result.name.len > 0: result.name
                else: path.splitFile().name
  tm.register(regName, result)
