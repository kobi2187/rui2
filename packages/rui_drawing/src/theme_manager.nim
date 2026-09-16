## Theme Manager - Unified theme loading, registration, and switching
##
## Consolidates all theme operations into a single object:
## - Built-in themes: light, dark, beos, joy, wide
## - Load from JSON or YAML files
## - Theme inheritance via "extends" field
## - Programmatic derivation: derive("dark", "My Custom")
## - Syncs global currentTheme for widget access during rendering
##
## Usage:
##   let tm = newThemeManager()
##   tm.setTheme("dark")
##   let t = tm.loadFromFile("themes/corporate.yaml")
##   tm.setTheme(t)
##   var corp = tm.derive("light", "Corporate")
##   corp.base[Default].cornerRadius = some(0.0f32)
##   tm.register("corporate", corp)
##
## Supported ThemeProps (all Optional):
##
##   Colors: backgroundColor, foregroundColor, borderColor,
##           pressedColor, hoverColor, activeColor, focusColor,
##           focusRingColor, focusGlowColor,
##           highlightColor, shadowColor, darkShadowColor,
##           gradientStart, gradientEnd, glowColor, dropShadowColor
##
##   Dimensions: borderWidth, cornerRadius, fontSize, spacing,
##               focusRingWidth, focusGlowRadius, glowRadius,
##               insetShadowDepth, insetShadowOpacity, dropShadowBlur
##
##   Text: fontFamily, textStyle
##
##   Layout: padding (EdgeInsets)
##
##   Effects: bevelStyle (Flat/Raised/Sunken/Ridge/Groove/Soft/Convex/
##              Drop/Interior/Flatsoft/Flatconvex)
##            gradientDirection (Vertical/Horizontal/Radial)
##            dropShadowOffset (tuple[x, y: float32])
##
## Bevel implementation status:
##   Working: Flat, Raised, Sunken
##   Partial: Ridge, Groove (fallback to simple border)
##   Stub:    Soft, Convex, Drop, Interior, Flatsoft, Flatconvex

import std/[tables, os, strutils]
import theme_sys_core
import theme_types
import theme_file
import builtin_themes
import rui_core

export theme_sys_core, theme_types, theme_file

# ============================================================================
# File parsing lives in theme_file.nim
# ============================================================================
#
# The file-format types, colour parsing, and ThemeFile -> Theme conversion moved
# to theme_file.nim. They were the four highest-complexity routines here and had
# nothing to do with storing themes -- but you needed a live ThemeManager to
# reach them, so a file-format bug could only be exercised through the registry.
# They are pure functions over text now, re-exported below for callers that
# still reach for them through this module.
# ============================================================================
# ThemeManager
# ============================================================================

type
  ThemeManager* = ref object
    current*: Theme
    registry: Table[string, Theme]
    searchPaths*: seq[string]

proc newThemeManager*(): ThemeManager =
  ## Create a ThemeManager with the 5 built-in themes registered.
  ## Sets "light" as the initial theme.
  result = ThemeManager(
    current: newTheme("Default"),
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
  setCurrentTheme(theme)

proc setTheme*(tm: ThemeManager, name: string) =
  ## Set the active theme by registered name
  if name notin tm.registry:
    raise newException(ValueError, "Unknown theme: " & name &
      ". Available: " & tm.listThemes().join(", "))
  tm.setTheme(tm.registry[name])

proc getProps*(tm: ThemeManager, intent: ThemeIntent = Default,
               state: ThemeState = Normal): ThemeProps =
  ## Themed properties for an intent and state.
  ##
  ## Widgets do not call this -- they read the global `currentTheme` directly,
  ## which `setTheme` keeps in step. It exists for code that holds a manager and
  ## wants its theme without reaching for a global.
  tm.current.getThemeProps(intent, state)

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
        return parseTheme(readFile(siblingPath), formatFor(ext),
                          tm.makeResolver(dir))
    newTheme(name)

proc loadFromFile*(tm: ThemeManager, path: string): Theme =
  ## Load a theme from a JSON or YAML file (auto-detected by extension).
  ## Supports "extends" referencing registered themes or sibling files.
  if not fileExists(path):
    raise newException(IOError, "Theme file not found: " & path)
  result = parseTheme(readFile(path), formatFor(path),
                      tm.makeResolver(parentDir(path)))
  # Auto-register under filename if not already registered
  let regName = if result.name.len > 0: result.name
                else: path.splitFile().name
  if regName notin tm.registry:
    tm.register(regName, result)

proc registryResolver(tm: ThemeManager): proc(name: string): Theme =
  ## Resolve `extends` against the registry only -- no sibling-file lookup,
  ## because a string has no directory to look beside.
  result = proc(name: string): Theme =
    if name in tm.registry: tm.derive(name) else: newTheme(name)

proc loadFromJsonString*(tm: ThemeManager, jsonStr: string): Theme =
  parseTheme(jsonStr, tffJson, tm.registryResolver())

proc loadFromYamlString*(tm: ThemeManager, yamlStr: string): Theme =
  parseTheme(yamlStr, tffYaml, tm.registryResolver())

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
