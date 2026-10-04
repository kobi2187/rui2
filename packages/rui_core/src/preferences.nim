## Preferences: how the person at the keyboard likes to use applications.
##
## There are two layers, and they are kept apart on purpose:
##
## - **Preferences** (this module) are the *user's*: navigation keys, whether
##   things animate, scroll speed, caret blink, double-click speed. One file
##   per user, shared by every RUI application on the machine, so the general
##   way of using an app is the same everywhere, and RUI keeps its defaults
##   stable. An application reads them; it does not set them.
## - **Themes** are the *application author's*: looks, brand, the app's own
##   behaviour. See theme_sys_core.nim.
##
## The file itself is read and written by the `rui` package (preferences_file);
## this module holds the model, the defaults and the validation, with no I/O.

import std/[json, strutils]
import types
import key_map

type
  ColorScheme* = enum
    schemeSystem   ## follow the operating system
    schemeLight
    schemeDark

  Preferences* = object
    keys*: KeyMap
    reduceMotion*: bool       ## no animations: every change lands at once
    scrollSpeed*: float32     ## wheel multiplier, 0.1 .. 10 (1 = as the OS reports)
    caretBlinkMs*: int        ## half a blink period; 0 keeps the caret steady
    doubleClickMs*: int       ## the longest gap between clicks of a double-click
    colorScheme*: ColorScheme ## which look the user wants applications to prefer

proc defaultPreferences*(): Preferences =
  Preferences(keys: defaultKeyMap(), reduceMotion: false, scrollSpeed: 1.0,
              caretBlinkMs: 500, doubleClickMs: 400, colorScheme: schemeSystem)

var prefs* = defaultPreferences()
  ## The preferences in force. Loaded once at startup by the App; read by
  ## widgets, like `currentTheme`.

proc parseColorScheme(s: string): ColorScheme =
  case s.toLowerAscii()
  of "system", "auto": schemeSystem
  of "light": schemeLight
  of "dark": schemeDark
  else:
    raise newException(ValueError, "expected system, light or dark, not '" & s & "'")

proc preferencesFromJson*(node: JsonNode): tuple[prefs: Preferences,
                                                 problems: seq[string]] =
  ## Read preferences from parsed JSON. Never raises: a field that is wrong
  ## keeps its default and adds a line to `problems`, so a typo in a settings
  ## file can degrade a setting but never stop an application starting.
  result.prefs = defaultPreferences()
  if node.kind != JObject:
    result.problems.add "preferences must be a mapping"
    return
  const allowed = ["keys", "motion", "scroll", "caretBlinkMs", "doubleClickMs",
                   "colorScheme"]
  for key, value in node:
    try:
      case key
      of "keys":
        result.prefs.keys = keyMapFromJson(value)
        for c in result.prefs.keys.conflicts:
          result.problems.add "keys: " & c
      of "motion":
        case value.getStr.toLowerAscii
        of "full": result.prefs.reduceMotion = false
        of "reduced": result.prefs.reduceMotion = true
        else: raise newException(ValueError, "expected full or reduced")
      of "scroll":
        let v = value.getFloat
        if v < 0.1 or v > 10: raise newException(ValueError, "expected 0.1 to 10")
        result.prefs.scrollSpeed = v.float32
      of "caretBlinkMs":
        let v = value.getInt
        if v < 0 or v > 5000: raise newException(ValueError, "expected 0 to 5000")
        result.prefs.caretBlinkMs = v
      of "doubleClickMs":
        let v = value.getInt
        if v < 100 or v > 2000: raise newException(ValueError, "expected 100 to 2000")
        result.prefs.doubleClickMs = v
      of "colorScheme":
        result.prefs.colorScheme = parseColorScheme(value.getStr)
      else:
        raise newException(ValueError,
          "unknown setting; allowed: " & allowed.join(", "))
    except ValueError as e:
      result.problems.add key & ": " & e.msg
