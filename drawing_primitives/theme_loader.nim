## Theme Loading System - Load themes from YAML/JSON files
##
## Supports:
## - Built-in themes (light, dark, beos, joy, wide)
## - Loading from YAML files
## - Loading from JSON files
## - Theme inheritance (extends: "base_theme")

import std/[json, tables, strutils, options, parseutils]
import theme_sys_core
import ../core/types

# Helper to parse color from hex string
proc parseHexColor*(hex: string): Color =
  var hexStr = hex
  if hexStr.startsWith("#"):
    hexStr = hexStr[1..^1]

  when defined(useGraphics):
    if hexStr.len == 6:
      var r, g, b: int
      discard parseHex(hexStr[0..1], r)
      discard parseHex(hexStr[2..3], g)
      discard parseHex(hexStr[4..5], b)
      result = Color(r: uint8(r), g: uint8(g), b: uint8(b), a: 255)
    elif hexStr.len == 8:
      var r, g, b, a: int
      discard parseHex(hexStr[0..1], r)
      discard parseHex(hexStr[2..3], g)
      discard parseHex(hexStr[4..5], b)
      discard parseHex(hexStr[6..7], a)
      result = Color(r: uint8(r), g: uint8(g), b: uint8(b), a: uint8(a))
  else:
    result = Color()

# Helper to parse color from rgb(r, g, b) format
proc parseRgbColor*(rgb: string): Color =
  # Format: "rgb(255, 255, 255)" or "rgba(255, 255, 255, 255)"
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

# Parse ThemeProps from JSON object
proc parseThemeProps*(json: JsonNode): ThemeProps =
  result = ThemeProps()

  if json.hasKey("backgroundColor"):
    let val = json["backgroundColor"].getStr()
    if val.startsWith("#"):
      result.backgroundColor = some(parseHexColor(val))
    elif val.startsWith("rgb"):
      result.backgroundColor = some(parseRgbColor(val))

  if json.hasKey("foregroundColor"):
    let val = json["foregroundColor"].getStr()
    if val.startsWith("#"):
      result.foregroundColor = some(parseHexColor(val))
    elif val.startsWith("rgb"):
      result.foregroundColor = some(parseRgbColor(val))

  if json.hasKey("borderColor"):
    let val = json["borderColor"].getStr()
    if val.startsWith("#"):
      result.borderColor = some(parseHexColor(val))
    elif val.startsWith("rgb"):
      result.borderColor = some(parseRgbColor(val))

  if json.hasKey("borderWidth"):
    result.borderWidth = some(json["borderWidth"].getFloat())

  if json.hasKey("cornerRadius"):
    result.cornerRadius = some(json["cornerRadius"].getFloat())

  if json.hasKey("fontSize"):
    result.fontSize = some(json["fontSize"].getFloat())

  if json.hasKey("spacing"):
    result.spacing = some(json["spacing"].getFloat())

  if json.hasKey("padding"):
    let p = json["padding"]
    if p.kind == JInt or p.kind == JFloat:
      # Single value - all sides
      let val = p.getFloat()
      result.padding = some(EdgeInsets(top: val, right: val, bottom: val, left: val))
    elif p.kind == JObject:
      # Object with top, right, bottom, left
      let top = if p.hasKey("top"): p["top"].getFloat() else: 0.0
      let right = if p.hasKey("right"): p["right"].getFloat() else: 0.0
      let bottom = if p.hasKey("bottom"): p["bottom"].getFloat() else: 0.0
      let left = if p.hasKey("left"): p["left"].getFloat() else: 0.0
      result.padding = some(EdgeInsets(top: top, right: right, bottom: bottom, left: left))

# Parse ThemeIntent from string
proc parseThemeIntent*(s: string): ThemeIntent =
  case s.toLowerAscii()
  of "default": Default
  of "info": Info
  of "success": Success
  of "warning": Warning
  of "danger": Danger
  else: Default

# Parse ThemeState from string
proc parseThemeState*(s: string): ThemeState =
  case s.toLowerAscii()
  of "normal": Normal
  of "disabled": Disabled
  of "hovered": Hovered
  of "pressed": Pressed
  of "focused": Focused
  of "selected": Selected
  of "dragover": DragOver
  else: Normal

# Load theme from JSON
proc loadThemeFromJson*(json: JsonNode): Theme =
  result = newTheme()

  if json.hasKey("name"):
    result.name = json["name"].getStr()

  # Parse base properties
  if json.hasKey("base"):
    let baseNode = json["base"]
    for intentKey, propsNode in baseNode.pairs():
      let intent = parseThemeIntent(intentKey)
      result.base[intent] = parseThemeProps(propsNode)

  # Parse state overrides
  if json.hasKey("states"):
    let statesNode = json["states"]
    for intentKey, stateTable in statesNode.pairs():
      let intent = parseThemeIntent(intentKey)
      for stateKey, propsNode in stateTable.pairs():
        let state = parseThemeState(stateKey)
        result.states[intent][state] = parseThemeProps(propsNode)

# Load theme from JSON string
proc loadThemeFromJsonString*(jsonStr: string): Theme =
  let json = parseJson(jsonStr)
  result = loadThemeFromJson(json)

# Load theme from JSON file
proc loadThemeFromJsonFile*(path: string): Theme =
  let content = readFile(path)
  result = loadThemeFromJsonString(content)

# Simple YAML parser (basic support for theme files)
proc parseYamlTheme*(yamlContent: string): Theme =
  # This is a simplified YAML parser specifically for theme files
  # For full YAML support, use a proper YAML library

  result = newTheme()
  var lines = yamlContent.splitLines()
  var currentSection = ""
  var currentIntent = ""
  var currentState = ""
  var indent = 0

  for line in lines:
    let trimmed = line.strip()
    if trimmed.len == 0 or trimmed.startsWith("#"):
      continue

    # Count indentation
    var lineIndent = 0
    for c in line:
      if c == ' ': lineIndent += 1
      else: break

    if trimmed.startsWith("name:"):
      result.name = trimmed.split(":", 1)[1].strip().replace("\"", "")
    elif trimmed == "base:":
      currentSection = "base"
      currentIntent = ""
    elif trimmed == "states:":
      currentSection = "states"
      currentIntent = ""
    elif currentSection == "base" and trimmed.endsWith(":") and not trimmed.contains(" "):
      currentIntent = trimmed[0..^2]
    elif currentSection == "states":
      if lineIndent == 2 and trimmed.endsWith(":"):
        currentIntent = trimmed[0..^2]
        currentState = ""
      elif lineIndent == 4 and trimmed.endsWith(":"):
        currentState = trimmed[0..^2]

# Load theme from YAML file
proc loadThemeFromYamlFile*(path: string): Theme =
  let content = readFile(path)
  result = parseYamlTheme(content)

# Load theme by name (built-in or from file)
proc loadTheme*(name: string, searchPaths: seq[string] = @[]): Theme =
  # First check if it's a file path
  if fileExists(name):
    if name.endsWith(".json"):
      return loadThemeFromJsonFile(name)
    elif name.endsWith(".yaml") or name.endsWith(".yml"):
      return loadThemeFromYamlFile(name)

  # Search in provided paths
  for path in searchPaths:
    let jsonPath = path / name & ".json"
    let yamlPath = path / name & ".yaml"
    let ymlPath = path / name & ".yml"

    if fileExists(jsonPath):
      return loadThemeFromJsonFile(jsonPath)
    elif fileExists(yamlPath):
      return loadThemeFromYamlFile(yamlPath)
    elif fileExists(ymlPath):
      return loadThemeFromYamlFile(ymlPath)

  # If not found, return empty theme
  result = newTheme(name)
