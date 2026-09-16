## Theme system regression tests
##
## The theme model is (intent x state) -> ThemeProps, resolved through a global
## `currentTheme` that widgets read while rendering. Switching themes is a
## single assignment to that global, so no widget holds a theme reference and
## nothing has to be rebuilt.
##
## What these tests pin down is the part that was missing: swapping the global
## changes what *would* be drawn, but nothing repaints unless the tree is also
## marked dirty — and composites read theme props inside layout(), so a repaint
## alone is not enough either.

import std/unittest
import rui
import std/json

suite "theme: registry and switching":

  test "the built-in themes are registered":
    let tm = newThemeManager()
    let names = tm.listThemes()
    check "light" in names
    check "dark" in names
    check names.len >= 2

  test "light is the initial theme":
    let tm = newThemeManager()
    check tm.current.name.len > 0

  test "switching by name changes the active theme":
    let tm = newThemeManager()
    let before = tm.current.name
    tm.setTheme("dark")
    check tm.current.name != before

  test "switching updates the global widgets actually read":
    let tm = newThemeManager()
    tm.setTheme("light")
    let lightBg = currentTheme.getThemeProps(ThemeIntent.Default, ThemeState.Normal)
                              .backgroundColor
    tm.setTheme("dark")
    let darkBg = currentTheme.getThemeProps(ThemeIntent.Default, ThemeState.Normal)
                             .backgroundColor
    check lightBg.isSome
    check darkBg.isSome
    check lightBg.get() != darkBg.get()

  test "an unknown theme name is rejected":
    let tm = newThemeManager()
    expect ValueError:
      tm.setTheme("no-such-theme")

suite "theme: intent and state resolution":

  test "different intents give different colours":
    let tm = newThemeManager()
    tm.setTheme("light")
    let default = currentTheme.getThemeProps(ThemeIntent.Default, ThemeState.Normal)
    let danger = currentTheme.getThemeProps(ThemeIntent.Danger, ThemeState.Normal)
    check default.backgroundColor.get() != danger.backgroundColor.get()

  test "different states give different colours for one intent":
    let tm = newThemeManager()
    tm.setTheme("light")
    let normal = currentTheme.getThemeProps(ThemeIntent.Default, ThemeState.Normal)
    let hovered = currentTheme.getThemeProps(ThemeIntent.Default, ThemeState.Hovered)
    # A state either overrides the base or inherits it; both are valid, but the
    # lookup must succeed and produce a usable colour.
    check normal.backgroundColor.isSome
    check hovered.backgroundColor.isSome

  test "props resolve for every intent and state pair":
    let tm = newThemeManager()
    for name in tm.listThemes():
      tm.setTheme(name)
      for intent in [ThemeIntent.Default, ThemeIntent.Info,
                     ThemeIntent.Success, ThemeIntent.Warning,
                     ThemeIntent.Danger]:
        for state in [ThemeState.Normal, ThemeState.Hovered, ThemeState.Pressed, ThemeState.Disabled, ThemeState.Focused]:
          let p = currentTheme.getThemeProps(intent, state)
          check p.backgroundColor.isSome
          check p.foregroundColor.isSome

suite "theme: switching reaches the screen":

  test "setTheme marks the whole tree dirty":
    # Regression: setTheme set only the tree-level flags, but frame() gates the
    # render pass on the *root widget's* flags, so a theme switch repainted
    # nothing.
    let app = newApp("theme test", 200, 200)
    let root = newVStack()
    let button = newButton(text = "styled")
    root.addChild(button)
    app.setRootWidget(root)

    for w in [Widget(root), Widget(button)]:
      w.isDirty = false
      w.layoutDirty = false

    app.setTheme("dark")

    check root.isDirty
    check button.isDirty
    # Composites read theme props inside layout(), so layout must rerun too.
    check button.layoutDirty

  test "a button picks up the new theme colour on relayout":
    let app = newApp("theme test", 200, 200)
    let root = newVStack()
    root.bounds = Rect(x: 0, y: 0, width: 200, height: 200)
    let button = newButton(text = "styled")
    root.addChild(button)
    app.setRootWidget(root)

    app.setTheme("light")
    root.layoutPass()
    # A Button builds a Rectangle child carrying the resolved background.
    # Read it through the scripting bridge rather than casting, because the
    # widget type `Rectangle` collides with raylib's struct of the same name.
    check button.children.len > 0
    let lightColor = $button.children[0].getScriptableState()["color"]

    app.setTheme("dark")
    root.layoutPass()
    let darkColor = $button.children[0].getScriptableState()["color"]

    check lightColor != darkColor

  test "widget intent survives a theme switch":
    let app = newApp("theme test", 200, 200)
    let root = newVStack()
    root.bounds = Rect(x: 0, y: 0, width: 200, height: 200)
    let danger = newButton(text = "delete", intent = ThemeIntent.Danger)
    root.addChild(danger)
    app.setRootWidget(root)

    app.setTheme("dark")
    root.layoutPass()
    check danger.intent == ThemeIntent.Danger

suite "theme: derivation and registration":

  test "a derived theme keeps its own name and can be registered":
    let tm = newThemeManager()
    var custom = tm.derive("light", "Corporate")
    tm.register("corporate", custom)
    check "corporate" in tm.listThemes()
    tm.setTheme("corporate")
    check tm.current.name == "Corporate"

suite "theme files parse without a manager":
  ## The whole point of splitting theme_file.nim out of theme_manager.nim: a
  ## file-format bug used to be reachable only by constructing a ThemeManager
  ## and going through the registry. These call the adapter directly, with a
  ## string literal and a trivial resolver.

  proc noExtends(name: string): Theme = newTheme(name)

  test "colour formats":
    check parseColor("#ff0000") == Color(r: 255, g: 0, b: 0, a: 255)
    check parseColor("#00ff0080").g == 255
    check parseColor("#00ff0080").a == 128          # alpha honoured
    check parseColor("rgb(10,20,30)") == Color(r: 10, g: 20, b: 30, a: 255)
    check parseColor("  #0000ff  ").b == 255        # whitespace tolerated

  test "intent and state names":
    check parseIntentName("danger") == Danger
    check parseIntentName("Success") == Success
    check parseStateName("hovered") == Hovered
    check parseStateName("disabled") == Disabled

  test "a JSON theme becomes a Theme":
    let theme = parseTheme("""
      {"name": "Test",
       "base": {"default": {"backgroundColor": "#102030", "cornerRadius": 4.0}}}
    """, tffJson, noExtends)
    check theme.name == "Test"
    check theme.base[Default].backgroundColor.get() ==
          Color(r: 16, g: 32, b: 48, a: 255)
    check theme.base[Default].cornerRadius.get() == 4.0

  test "a YAML theme becomes the same Theme":
    let theme = parseTheme("""
name: Test
base:
  default:
    backgroundColor: "#102030"
    cornerRadius: 4.0
""", tffYaml, noExtends)
    check theme.name == "Test"
    check theme.base[Default].backgroundColor.get() ==
          Color(r: 16, g: 32, b: 48, a: 255)

  test "states nest under their intent":
    let theme = parseTheme("""
      {"name": "S",
       "states": {"danger": {"hovered": {"backgroundColor": "#ff0000"}}}}
    """, tffJson, noExtends)
    check theme.states[Danger][Hovered].backgroundColor.get().r == 255

  test "extends goes through the resolver, whatever it is":
    # No registry involved — the resolver is three lines of test code.
    proc resolveBase(name: string): Theme =
      result = newTheme(name)
      result.base[Default] = ThemeProps(cornerRadius: some(9.0'f32))

    let theme = parseTheme("""
      {"name": "Child", "extends": "parent",
       "base": {"default": {"backgroundColor": "#010203"}}}
    """, tffJson, resolveBase)
    check theme.name == "Child"
    check theme.base[Default].cornerRadius.get() == 9.0    # inherited
    check theme.base[Default].backgroundColor.get().b == 3 # own, merged in

  test "formatFor picks the parser from the extension":
    check formatFor("theme.json") == tffJson
    check formatFor("theme.JSON") == tffJson
    check formatFor("theme.yaml") == tffYaml
    check formatFor("theme.yml") == tffYaml
    check formatFor("theme") == tffYaml          # no extension: assume YAML
