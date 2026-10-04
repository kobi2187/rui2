## The user's preferences: defaults, validation, files, and what they drive.

import std/[unittest, json, os, strutils, monotimes, times, unicode]
import rui

suite "key map":

  test "defaults: Tab between groups, arrows within, Escape out":
    let m = defaultKeyMap()
    check m.matches(nextGroup, parseKeyChord("Tab").get.key, {})
    check m.matches(prevGroup, parseKeyChord("Tab").get.key, {kmShift})
    check not m.matches(nextGroup, parseKeyChord("Tab").get.key, {kmShift})  # exact
    check m.matches(nextInGroup, parseKeyChord("Down").get.key, {})
    check m.matches(prevInGroup, parseKeyChord("Left").get.key, {})
    check m.matches(leaveGroup, parseKeyChord("Escape").get.key, {})

  test "set replaces, add keeps, remove and clear take away":
    var m = defaultKeyMap()
    m.add(nextInGroup, "J")
    check m.matches(nextInGroup, chord("J").key, {})
    check m.matches(nextInGroup, chord("Down").key, {})
    m.set(nextGroup, "Ctrl+Tab", "F6")
    check m.matches(nextGroup, chord("F6").key, {})
    check m.matches(nextGroup, chord("Tab").key, {kmCtrl})
    check not m.matches(nextGroup, chord("Tab").key, {})
    m.remove(nextInGroup, "J")
    check not m.matches(nextInGroup, chord("J").key, {})
    m.clear(leaveGroup)
    check m.bindings[leaveGroup].len == 0

  test "a chord names its keys, and a bad one says so":
    check $chord("ctrl+shift+tab") == "Ctrl+Shift+Tab"
    expect ValueError:
      discard chord("Hyper+Tab")
    expect ValueError:
      discard chord("NotAKey")

  test "conflicts are reported":
    var m = defaultKeyMap()
    check m.conflicts.len == 0
    m.add(nextInGroup, "Tab")
    check m.conflicts.len == 1
    check "nextInGroup" in m.conflicts[0] and "nextGroup" in m.conflicts[0]

  test "from JSON: named actions are replaced, the rest keep their defaults":
    let m = keyMapFromJson(parseJson("""{"nextGroup": ["Ctrl+Tab"], "prevInGroup": "K"}"""))
    check m.matches(nextGroup, chord("Tab").key, {kmCtrl})
    check m.matches(prevInGroup, chord("K").key, {})
    check m.matches(nextInGroup, chord("Down").key, {})      # untouched
    expect ValueError:
      discard keyMapFromJson(parseJson("""{"nextGrup": ["Tab"]}"""))

suite "preferences":

  test "defaults are the stable RUI defaults":
    let p = defaultPreferences()
    check not p.reduceMotion
    check p.scrollSpeed == 1.0
    check p.caretBlinkMs == 500
    check p.doubleClickMs == 400
    check p.colorScheme == schemeSystem

  test "a good file is read in full":
    let (p, problems) = parsePreferences("""
keys:
  nextGroup: [F6, Ctrl+Tab]
  nextInGroup: [Down, J]
motion: reduced
scroll: 2.5
caretBlinkMs: 0
doubleClickMs: 600
colorScheme: dark
""")
    check problems.len == 0
    check p.reduceMotion
    check p.scrollSpeed == 2.5
    check p.caretBlinkMs == 0
    check p.doubleClickMs == 600
    check p.colorScheme == schemeDark
    check p.keys.matches(nextInGroup, chord("J").key, {})

  test "mistakes degrade one setting, never the file":
    let (p, problems) = parsePreferences("""
motion: sideways
scroll: 99
doubleClickMs: 600
colour: dark
keys:
  nextGroup: [NotAKey]
""")
    check p.doubleClickMs == 600            # the good one still applies
    check p.scrollSpeed == 1.0              # the bad ones keep their defaults
    check not p.reduceMotion
    check p.keys.matches(nextGroup, chord("Tab").key, {})
    check problems.len == 4
    check problems.join("\n").contains("motion: expected full or reduced")
    check problems.join("\n").contains("colour: unknown setting; allowed:")

  test "a file that is not even YAML falls back to the defaults":
    let (p, problems) = parsePreferences("keys: [unclosed")
    check p.doubleClickMs == 400
    check problems.len == 1

  test "conflicting key bindings are flagged":
    let (_, problems) = parsePreferences("keys:\n  nextInGroup: [Tab]\n")
    check problems.len == 1 and "bound to" in problems[0]

  test "a missing file is normal; the path can be overridden":
    putEnv("RUI_PREFERENCES", "/nonexistent/prefs.yaml")
    check preferencesPath() == "/nonexistent/prefs.yaml"
    let (p, problems) = loadPreferences()
    check problems.len == 0 and p.doubleClickMs == 400
    delEnv("RUI_PREFERENCES")
    check preferencesPath().endsWith("rui" / "preferences.yaml")

  test "problems name the file":
    let dir = getTempDir() / "rui_prefs_test"
    createDir(dir)
    defer: removeDir(dir)
    writeFile(dir / "p.yaml", "scroll: 99\n")
    let (_, problems) = loadPreferences(dir / "p.yaml")
    check problems.len == 1 and "p.yaml" in problems[0]

suite "preferences drive behaviour":

  setup:
    let saved = prefs
  teardown:
    applyPreferences(saved)
    animationsEnabled = true

  test "reduced motion turns animations off":
    var p = defaultPreferences()
    p.reduceMotion = true
    applyPreferences(p)
    check not animationsEnabled
    applyPreferences(defaultPreferences())
    check animationsEnabled

  test "a new focus manager starts from the user's keys":
    var p = defaultPreferences()
    p.keys.set(nextGroup, "F6")
    applyPreferences(p)
    let fm = newFocusManager()
    check fm.keys.matches(nextGroup, chord("F6").key, {})
    check not fm.keys.matches(nextGroup, chord("Tab").key, {})

  test "the user's blink period sets the caret phase; 0 keeps it steady":
    check abs(caretPhaseRemaining(10.0, 0.25) - 0.25) < 1e-9
    check abs(caretPhaseRemaining(10.1, 0.25) - 0.15) < 1e-9

suite "colour scheme":

  test "what the platform tools print":
    check parseSystemScheme("'prefer-dark'\n") == schemeDark
    check parseSystemScheme("'default'\n") == schemeLight
    check parseSystemScheme("'prefer-light'") == schemeLight
    check parseSystemScheme("Dark\n") == schemeDark                  # macOS
    check parseSystemScheme("The domain/default pair ... does not exist") == schemeLight
    check parseSystemScheme("    AppsUseLightTheme    REG_DWORD    0x0") == schemeDark   # Windows
    check parseSystemScheme("    AppsUseLightTheme    REG_DWORD    0x1") == schemeLight
    check parseSystemScheme("") == schemeLight

  test "the user's choice wins; system defers to the platform":
    check effectiveScheme(schemeDark, schemeLight) == schemeDark
    check effectiveScheme(schemeLight, schemeDark) == schemeLight
    check effectiveScheme(schemeSystem, schemeDark) == schemeDark
    check effectiveScheme(schemeSystem, schemeLight) == schemeLight

  test "detecting never fails or returns 'system'":
    check detectSystemScheme() in {schemeLight, schemeDark}

  test "useThemes starts on the user's scheme":
    let saved = prefs
    defer: applyPreferences(saved)
    let app = newApp("t")
    var p = defaultPreferences()
    p.colorScheme = schemeDark
    applyPreferences(p)
    app.useThemes(light = "daylight", dark = "midnight")
    check app.getTheme().name == "Midnight"
    p.colorScheme = schemeLight
    applyPreferences(p)
    app.useThemes(light = "daylight", dark = "midnight")
    check app.getTheme().name == "Daylight"

suite "keyboard help":

  test "the sections list the bindings in force, in the user's words":
    var m = defaultKeyMap()
    m.set(nextGroup, "Ctrl+Tab", "F6")
    let s = helpSections(m, @[("Ctrl+S", "Save")])
    check s.len == 3
    check s[0].title == "Moving around"
    check s[0].entries[0] == ("Ctrl+Tab / F6", "Next container")
    check s[1].title == "This application" and s[1].entries == @[("Ctrl+S", "Save")]
    check s[2].entries[0].keys == "F1 / ?"

  test "an unbound action says so; no app shortcuts means no app section":
    var m = defaultKeyMap()
    m.clear(leaveGroup)
    let s = helpSections(m)
    check s.len == 2
    check s[0].entries[^1].keys == "(unbound)"

  test "what counts as typing":
    check chord("Shift+Slash").isTyping
    check chord("A").isTyping
    check not chord("F1").isTyping
    check not chord("Ctrl+Slash").isTyping
    check not chord("Escape").isTyping
    check not chord("Tab").isTyping

  proc newTestApp(): App = newApp("help")

  test "F1 opens the overlay; any key closes it; the typed character is swallowed":
    let app = newTestApp()
    check not app.helpVisible
    check app.handleHelp(GuiEvent(kind: evKeyDown, key: chord("F1").key))
    check app.helpVisible
    check app.handleHelp(GuiEvent(kind: evChar, rune: Rune('x')))        # eaten while open
    check app.handleHelp(GuiEvent(kind: evKeyDown, key: chord("A").key)) # closes it
    check not app.helpVisible
    check app.handleHelp(GuiEvent(kind: evChar, rune: Rune('a')))        # and its character
    clearOverlays()

  test "a click closes it; pointer events are held while it is up":
    let app = newTestApp()
    discard app.handleHelp(GuiEvent(kind: evKeyDown, key: chord("F1").key))
    check app.handleHelp(GuiEvent(kind: evMouseMove))
    check app.handleHelp(GuiEvent(kind: evMouseDown))
    check not app.helpVisible
    clearOverlays()

  test "'?' opens it, but not while a text field is typing":
    let app = newTestApp()
    let question = GuiEvent(kind: evKeyDown, key: chord("Slash").key, mods: {kmShift})
    let field = newTextInput()
    field.layout()
    app.focusManager.setFocus(field)
    check field.takesText
    check not app.handleHelp(question)           # it is a "?" being typed
    check not app.helpVisible
    check app.handleHelp(GuiEvent(kind: evKeyDown, key: chord("F1").key))   # F1 still works
    check app.helpVisible
    discard app.handleHelp(GuiEvent(kind: evKeyDown, key: chord("Escape").key))
    app.focusManager.clearFocus()
    check app.handleHelp(question)               # nothing is typing: opens
    check app.helpVisible
    clearOverlays()

  test "the user's rebinding applies: F1 can be taken away":
    let saved = prefs
    defer: applyPreferences(saved)
    let app = newTestApp()          # newApp loads the user's file, so apply after it
    var p = defaultPreferences()
    p.keys.set(showHelp, "F2")
    applyPreferences(p)
    check not app.handleHelp(GuiEvent(kind: evKeyDown, key: chord("F1").key))
    check app.handleHelp(GuiEvent(kind: evKeyDown, key: chord("F2").key))
    clearOverlays()
