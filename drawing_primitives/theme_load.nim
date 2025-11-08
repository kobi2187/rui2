import std/[options, os, strutils, tables]
import yaml

import theme_sys_core
import builtin_base_themes
import ../core/types

type
  ThemeParseError* = object of ValueError

const
  intentNameMap = {
    "default": Default,
    "info": Info,
    "success": Success,
    "warning": Warning,
    "danger": Danger
  }

  stateNameMap = {
    "normal": Normal,
    "disabled": Disabled,
    "hovered": Hovered,
    "pressed": Pressed,
    "focused": Focused,
    "selected": Selected,
    "dragover": DragOver
  }

proc parseHexComponent(slice: string): uint8 =
  let value = fromHex[int](slice)
  if value < 0 or value > 255:
    raise newException(ThemeParseError, "Color component out of range: " & slice)
  uint8(value)

proc parseColor(value: string): Color =
  var cleaned = value.strip()
  if cleaned.len == 0:
    raise newException(ThemeParseError, "Empty color value")
  if cleaned.startsWith("#"):
    cleaned = cleaned[1..^1]
  case cleaned.len
  of 6:
    let r = parseHexComponent(cleaned[0..1])
    let g = parseHexComponent(cleaned[2..3])
    let b = parseHexComponent(cleaned[4..5])
    makeColor(r.int, g.int, b.int)
  of 8:
    let r = parseHexComponent(cleaned[0..1])
    let g = parseHexComponent(cleaned[2..3])
    let b = parseHexComponent(cleaned[4..5])
    let a = parseHexComponent(cleaned[6..7])
    makeColor(r.int, g.int, b.int, a.int)
  else:
    raise newException(ThemeParseError, "Unsupported color format: " & value)

proc nodeToFloat32(node: YamlNode): float32 =
  case node.kind
  of yScalar:
    try:
      node.scalar.parseFloat.float32
    except ValueError:
      raise newException(ThemeParseError, "Expected number, got " & node.scalar)
  of yInteger:
    node.intVal.float32
  of yFloat:
    node.floatVal.float32
  else:
    raise newException(ThemeParseError, "Expected numeric value")

proc parseEdgeInsets(node: YamlNode): EdgeInsets =
  case node.kind
  of yScalar, yInteger, yFloat:
    let value = nodeToFloat32(node)
    edgeInsets(value)
  of yMapping:
    if node.hasKey("all"):
      return edgeInsets(nodeToFloat32(node["all"]))
    var left = 0.0'f32
    var right = 0.0'f32
    var top = 0.0'f32
    var bottom = 0.0'f32
    if node.hasKey("horizontal"):
      let h = nodeToFloat32(node["horizontal"])
      left = h
      right = h
    if node.hasKey("vertical"):
      let v = nodeToFloat32(node["vertical"])
      top = v
      bottom = v
    if node.hasKey("left"):
      left = nodeToFloat32(node["left"])
    if node.hasKey("right"):
      right = nodeToFloat32(node["right"])
    if node.hasKey("top"):
      top = nodeToFloat32(node["top"])
    if node.hasKey("bottom"):
      bottom = nodeToFloat32(node["bottom"])
    edgeInsetsLTRB(left, top, right, bottom)
  else:
    raise newException(ThemeParseError, "Invalid padding definition")

proc parseThemeProps(node: YamlNode): ThemeProps =
  result = ThemeProps()
  if node.kind != yMapping:
    raise newException(ThemeParseError, "Theme properties must be a mapping")

  if node.hasKey("backgroundColor"):
    result.backgroundColor = some(parseColor(node["backgroundColor"].scalar))
  if node.hasKey("foregroundColor"):
    result.foregroundColor = some(parseColor(node["foregroundColor"].scalar))
  if node.hasKey("borderColor"):
    result.borderColor = some(parseColor(node["borderColor"].scalar))
  if node.hasKey("borderWidth"):
    result.borderWidth = some(nodeToFloat32(node["borderWidth"]))
  if node.hasKey("cornerRadius"):
    result.cornerRadius = some(nodeToFloat32(node["cornerRadius"]))
  if node.hasKey("padding"):
    result.padding = some(parseEdgeInsets(node["padding"]))
  if node.hasKey("spacing"):
    result.spacing = some(nodeToFloat32(node["spacing"]))
  if node.hasKey("fontSize"):
    result.fontSize = some(nodeToFloat32(node["fontSize"]))

proc parseIntent(key: string): ThemeIntent =
  let normalized = key.toLowerAscii()
  if normalized in intentNameMap:
    intentNameMap[normalized]
  else:
    raise newException(ThemeParseError, "Unknown theme intent: " & key)

proc parseState(key: string): ThemeState =
  let normalized = key.toLowerAscii()
  if normalized in stateNameMap:
    stateNameMap[normalized]
  else:
    raise newException(ThemeParseError, "Unknown theme state: " & key)

proc mergeIntentProps(theme: var Theme, intent: ThemeIntent, props: ThemeProps) =
  var merged = theme.base[intent]
  merged.merge(props)
  theme.base[intent] = merged

proc mergeStateProps(theme: var Theme, intent: ThemeIntent, state: ThemeState, props: ThemeProps) =
  var stateTable = theme.states[intent]
  var merged = stateTable.getOrDefault(state, ThemeProps())
  merged.merge(props)
  stateTable[state] = merged
  theme.states[intent] = stateTable

proc applyOverrides(theme: var Theme, node: YamlNode) =
  if node.kind != yMapping:
    raise newException(ThemeParseError, "Theme file root must be a mapping")

  if node.hasKey("name"):
    theme.name = node["name"].scalar

  if node.hasKey("base"):
    for pair in node["base"].pairs:
      let intent = parseIntent(pair.key.scalar)
      let props = parseThemeProps(pair.val)
      theme.mergeIntentProps(intent, props)

  if node.hasKey("states"):
    for intentPair in node["states"].pairs:
      let intent = parseIntent(intentPair.key.scalar)
      if intentPair.val.kind != yMapping:
        raise newException(ThemeParseError, "States for intent " & intentPair.key.scalar & " must be a mapping")
      for statePair in intentPair.val.pairs:
        let state = parseState(statePair.key.scalar)
        let props = parseThemeProps(statePair.val)
        theme.mergeStateProps(intent, state, props)

proc resolveExtendedTheme(baseValue, currentDir: string): Theme =
  var candidates = @[baseValue]
  if not baseValue.endsWith(".yaml") and not baseValue.endsWith(".yml"):
    candidates.add(baseValue & ".yaml")
    candidates.add(baseValue & ".yml")

  for candidate in candidates:
    let path = if isAbsolute(candidate): candidate else: joinPath(currentDir, candidate)
    if fileExists(path):
      return loadThemeFromFile(path)

  builtInTheme(baseValue)

proc loadThemeFromFile*(path: string): Theme =
  if not fileExists(path):
    raise newException(ThemeParseError, "Theme file not found: " & path)

  let content = readFile(path)
  let yamlNode = loadYaml(content)
  if yamlNode.kind != yMapping:
    raise newException(ThemeParseError, "Theme file root must be a mapping")

  var theme = newTheme(extractFilename(path))
  if yamlNode.hasKey("extends"):
    let baseName = yamlNode["extends"].scalar
    theme = resolveExtendedTheme(baseName, parentDir(path))

  applyOverrides(theme, yamlNode)
  theme