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

  test "the navigation line uses the user's bindings, in short words":
    var m = defaultKeyMap()
    m.set(nextGroup, "Ctrl+Tab", "F6")
    let items = navigationItems(m)
    check items[0] == ("Ctrl+Tab/F6", "next container")
    check ("Shift+Tab", "previous container") in items
    check ("↓/→", "next widget") in items            # arrows read as arrows
    check ("Esc", "leave container") in items
    check items[^1] == ("F1/?", "help")
    check infoLine(m).startsWith("Ctrl+Tab/F6 next container   ·   ")

  test "an unbound action is left out of the line":
    var m = defaultKeyMap()
    m.clear(leaveGroup)
    for item in navigationItems(m):
      check item.text != "leave container"

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


suite "shortcuts and hints":

  proc tree(): tuple[root, save, open, hidden: Widget, field: TextArea] =
    let root = newVStack(spacing = 8.0)
    let save = newButton(text = "Save").shortcut("Ctrl+S")
    let open = newButton(text = "Open").shortcut("Ctrl+O")
    let hidden = newButton(text = "Hidden").shortcut("F9")
    let field = newTextInput()
    root.addChild save
    root.addChild open
    root.addChild hidden
    root.addChild field
    hidden.visible = false
    root.bounds = Rect(x: 0, y: 0, width: 400, height: 300)
    root.layout()
    (Widget(root), Widget(save), Widget(open), Widget(hidden), field)

  test "hints are collected for visible widgets with shortcuts, in tree order":
    let t = tree()
    let hints = collectHints(t.root)
    check hints.len == 2
    check hints[0].keys == "Ctrl+S" and hints[0].target == t.save.bounds
    check hints[1].keys == "Ctrl+O"

  test "a disabled widget has no hint, and a chord that does not parse has none":
    let t = tree()
    t.open.enabled = false
    t.save.hotkey = "Ctrl+NotAKey"
    check collectHints(t.root).len == 0

  test "findShortcut matches the exact chord on a live widget":
    let t = tree()
    check findShortcut(t.root, chord("S").key, {kmCtrl}) == t.save
    check findShortcut(t.root, chord("S").key, {}).isNil           # no Ctrl: not it
    check findShortcut(t.root, chord("F9").key, {}).isNil          # hidden
    t.save.enabled = false
    check findShortcut(t.root, chord("S").key, {kmCtrl}).isNil

  test "a badge is centred on the widget's top-right corner":
    let within = Rect(x: 0, y: 0, width: 600, height: 400)
    let target = Rect(x: 100, y: 100, width: 80, height: 30)
    let b = placeBadge(target, Size(width: 60, height: 20), within)
    check b.x + b.width / 2 == 180.0                   # centre on the right edge
    check b.y + b.height / 2 == 100.0                  # and on the top edge

  test "a badge stays on screen, and keeps clear of others":
    let within = Rect(x: 0, y: 40, width: 400, height: 300)
    let target = Rect(x: 20, y: 100, width: 80, height: 30)
    let a = placeBadge(target, Size(width: 60, height: 20), within)
    let b = placeBadge(target, Size(width: 60, height: 20), within, [a])
    check b.y >= a.y + a.height                        # moved clear of a
    let edge = placeBadge(Rect(x: 380, y: 330, width: 80, height: 30),
                          Size(width: 60, height: 20), within)
    check edge.x + edge.width <= within.x + within.width
    check edge.y + edge.height <= within.y + within.height
    let top = placeBadge(Rect(x: 10, y: 40, width: 80, height: 30), Size(width: 60, height: 20), within)
    check top.y >= within.y                            # not pushed above the bar

  test "pressing a shortcut clicks its widget":
    let app = newApp("shortcuts")
    let t = tree()
    app.setRootWidget(t.root)
    var saved = 0
    Button(t.save).onClick = proc() = inc saved
    check app.handleShortcut(GuiEvent(kind: evKeyDown, key: chord("S").key, mods: {kmCtrl}))
    check saved == 1
    check not app.handleShortcut(GuiEvent(kind: evKeyDown, key: chord("S").key))   # not the chord
    check saved == 1

  test "a typing-style shortcut is left to a focused text field":
    let app = newApp("shortcuts")
    let t = tree()
    let plain = newButton(text = "Find").shortcut("F")
    t.root.addChild plain
    t.root.layout()
    app.setRootWidget(t.root)
    var found = 0
    Button(plain).onClick = proc() = inc found
    app.focusManager.setFocus(t.field)
    check not app.handleShortcut(GuiEvent(kind: evKeyDown, key: chord("F").key))   # typing an F
    check found == 0
    app.focusManager.clearFocus()
    check app.handleShortcut(GuiEvent(kind: evKeyDown, key: chord("F").key))
    check found == 1
    # a Ctrl chord still works from inside the field
    app.focusManager.setFocus(t.field)
    check app.handleShortcut(GuiEvent(kind: evKeyDown, key: chord("S").key, mods: {kmCtrl}))

  test "shortcuts do not fire while the help overlay is up":
    let app = newApp("shortcuts")
    let t = tree()
    app.setRootWidget(t.root)
    var saved = 0
    Button(t.save).onClick = proc() = inc saved
    app.showHelp()
    check not app.handleShortcut(GuiEvent(kind: evKeyDown, key: chord("S").key, mods: {kmCtrl}))
    check saved == 0
    clearOverlays()


suite "hints and app shortcuts":

  proc form(): tuple[root, save, slider: Widget] =
    let root = newVStack(spacing = 8.0)
    let save = newButton(text = "Save").shortcut("Ctrl+S")
    let slider = newSlider().hint("← → adjust")
    root.addChild save
    root.addChild slider
    root.addChild newLabel(text = "no hint")
    root.bounds = Rect(x: 0, y: 0, width: 400, height: 300)
    root.layout()
    (Widget(root), Widget(save), Widget(slider))

  test "any widget can carry a hint; the overlay gets its text and place":
    let f = form()
    let hints = collectHints(f.root)
    check hints.len == 2                                   # the label has none
    check hints[0] == (f.save.bounds, "Ctrl+S")            # a shortcut supplies its chord
    check hints[1] == (f.slider.bounds, "← → adjust")      # a hint is any text

  test "an explicit hint wins over the shortcut's chord":
    let f = form()
    f.save.hint = "save (Ctrl+S)"
    check collectHints(f.root)[0].keys == "save (Ctrl+S)"

  test "a hint on a hidden widget is not shown":
    let f = form()
    f.slider.visible = false
    check collectHints(f.root).len == 1

  test "a hint is only a label: it does not make a key do anything":
    let app = newApp("hints")
    let f = form()
    app.setRootWidget(f.root)
    check not app.handleShortcut(GuiEvent(kind: evKeyDown, key: chord("Left").key))

  test "an app shortcut runs its action with no widget behind it":
    let app = newApp("appkeys")
    app.setRootWidget(newVStack())
    var found = 0
    app.bindShortcut("Ctrl+F", "find", proc() = inc found)
    check app.handleShortcut(GuiEvent(kind: evKeyDown, key: chord("F").key, mods: {kmCtrl}))
    check found == 1
    check not app.handleShortcut(GuiEvent(kind: evKeyDown, key: chord("F").key))   # no Ctrl

  test "a widget's shortcut wins over an app shortcut on the same chord":
    let app = newApp("appkeys")
    let f = form()
    app.setRootWidget(f.root)
    var widgetFired, appFired = 0
    Button(f.save).onClick = proc() = inc widgetFired
    app.bindShortcut("Ctrl+S", "save all", proc() = inc appFired)
    discard app.handleShortcut(GuiEvent(kind: evKeyDown, key: chord("S").key, mods: {kmCtrl}))
    check widgetFired == 1 and appFired == 0

  test "app shortcuts are listed on the overlay, in the user's words":
    let app = newApp("appkeys")
    app.setRootWidget(newVStack())
    app.bindShortcut("Ctrl+F", "find", proc() = discard)
    app.addHelp("Ctrl+Q", "quit")
    app.showHelp()
    check ("Ctrl+F", "find") in app.helpOverlay.notes
    check ("Ctrl+Q", "quit") in app.helpOverlay.notes
    clearOverlays()

  test "a typing-style app shortcut leaves a focused text field alone":
    let app = newApp("appkeys")
    let field = newTextInput()
    let root = newVStack()
    root.addChild field
    root.layout()
    app.setRootWidget(root)
    var found = 0
    app.bindShortcut("G", "go", proc() = inc found)
    app.focusManager.setFocus(field)
    check not app.handleShortcut(GuiEvent(kind: evKeyDown, key: chord("G").key))
    check found == 0

  test "a bad chord fails where it is written":
    let app = newApp("appkeys")
    expect ValueError:
      app.bindShortcut("Hyper+F", "x", proc() = discard)


suite "hint badge look":

  test "by default a sign post: yellow, thick dark border, small uppercase monospace":
    let look = brandTheme(daylightSpec()).hintLook
    check look.background == Color(r: 255, g: 212, b: 0, a: 255)
    check look.borderWidth >= 2.5
    check look.fontFamily == "Monospace"
    check look.uppercase
    check look.fontSize <= 12

  test "a theme can change any part of it":
    var t = brandTheme(daylightSpec())
    t.hint.background = some(Color(r: 1, g: 2, b: 3, a: 255))
    t.hint.uppercase = some(false)
    t.hint.fontSize = some(14.0'f32)
    let look = t.hintLook
    check look.background == Color(r: 1, g: 2, b: 3, a: 255)
    check not look.uppercase and look.fontSize == 14.0
    check look.fontFamily == "Monospace"               # the rest keeps its default

  test "a theme file's hint: section sets it, and its keys are validated":
    proc noExtends(name: string): Theme = newTheme(name)
    let t = parseTheme("""
hint:
  background: "#00AAFF"
  borderWidth: 4
  fontFamily: Sans
  uppercase: false
""", tffYaml, noExtends)
    let look = t.hintLook
    check look.background == Color(r: 0, g: 170, b: 255, a: 255)
    check look.borderWidth == 4.0 and look.fontFamily == "Sans" and not look.uppercase
    expect ValueError:
      discard parseTheme("hint:\n  colour: red\n", tffYaml, noExtends)
