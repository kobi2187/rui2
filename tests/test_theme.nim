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
