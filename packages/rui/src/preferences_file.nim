## Reading the user's preferences file.
##
## One file per user, shared by every RUI application on the machine:
##
##   Linux    ~/.config/rui/preferences.yaml      ($XDG_CONFIG_HOME respected)
##   macOS    ~/Library/Application Support/rui/preferences.yaml
##   Windows  %APPDATA%\rui\preferences.yaml
##
## `RUI_PREFERENCES=/path/to/file` points somewhere else (YAML or JSON, by
## extension). A missing file is normal -- the defaults apply. A file with
## mistakes is not fatal either: each wrong setting keeps its default and the
## problems are reported on stderr, because an application must always start.
## See docs/preferences.md for every setting.

import std/[os, json, strutils]
import yaml/tojson
import rui_core

proc preferencesPath*(): string =
  ## Where the user's preferences live on this machine.
  let override = getEnv("RUI_PREFERENCES")
  if override.len > 0: override
  else: getConfigDir() / "rui" / "preferences.yaml"

proc parsePreferences*(content: string, asJson = false):
    tuple[prefs: Preferences, problems: seq[string]] =
  ## Text to preferences, never raising (see preferencesFromJson).
  try:
    let node = if asJson: parseJson(content)
               else:
                 let docs = loadToJson(content)
                 if docs.len == 0: newJObject() else: docs[0]
    preferencesFromJson(node)
  except CatchableError as e:
    (defaultPreferences(), @["could not read the file: " & e.msg])

proc loadPreferences*(path = preferencesPath()): tuple[prefs: Preferences,
                                                       problems: seq[string]] =
  ## The user's preferences, or the defaults if there is no file.
  if not fileExists(path):
    return (defaultPreferences(), @[])
  var r = parsePreferences(readFile(path), path.toLowerAscii.endsWith(".json"))
  for i in 0 ..< r.problems.len:
    r.problems[i] = path & ": " & r.problems[i]
  r

proc applyPreferences*(p: Preferences) =
  ## Make `p` the preferences in force. (Navigation keys reach a FocusManager
  ## when it is created or told to refresh; see App.)
  prefs = p
  animationsEnabled = not p.reduceMotion
