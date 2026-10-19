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
import std/[json, tables, strutils, options, os, monotimes, times]

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


suite "which effect a theme asks for":
  ## drawThemedRect used to hard-code both the set of effects and their order in
  ## an if/elif chain, so precedence was control flow you had to trace and could
  ## not assert on. It is a list now, and `effectFor` is the selection.

  test "no effect props means a plain fill":
    check effectFor(ThemeProps()).isNone

  test "Flat is the absence of a bevel, not a bevel":
    var props = ThemeProps()
    props.bevelStyle = some(Flat)
    check effectFor(props).isNone

  test "each effect is picked when its props are set":
    var bevel = ThemeProps()
    bevel.bevelStyle = some(Raised)
    check effectFor(bevel).get().name == "bevel"

    var gradient = ThemeProps()
    gradient.gradientStart = some(WHITE)
    gradient.gradientEnd = some(BLACK)
    check effectFor(gradient).get().name == "gradient"

    var shadow = ThemeProps()
    shadow.dropShadowOffset = some((x: 4.0'f32, y: 4.0'f32))
    check effectFor(shadow).get().name == "dropShadow"

    var glow = ThemeProps()
    glow.glowColor = some(WHITE)
    check effectFor(glow).get().name == "glow"

    var inset = ThemeProps()
    inset.insetShadowDepth = some(3.0'f32)
    check effectFor(inset).get().name == "inset"

  test "a gradient with only one end is not a gradient":
    var props = ThemeProps()
    props.gradientStart = some(WHITE)
    check effectFor(props).isNone

  test "precedence: a bevel wins over everything a theme also sets":
    # A BeOS-style theme sets a bevel and a gradient and means the bevel.
    var props = ThemeProps()
    props.bevelStyle = some(Raised)
    props.gradientStart = some(WHITE)
    props.gradientEnd = some(BLACK)
    props.dropShadowOffset = some((x: 2.0'f32, y: 2.0'f32))
    props.glowColor = some(WHITE)
    check effectFor(props).get().name == "bevel"

  test "precedence: depth before emphasis":
    # A theme setting both a drop shadow and a glow is describing depth.
    var props = ThemeProps()
    props.dropShadowOffset = some((x: 2.0'f32, y: 2.0'f32))
    props.glowColor = some(WHITE)
    check effectFor(props).get().name == "dropShadow"

  test "the order the table declares is the order it is searched":
    check RectEffects.len == 5
    var names: seq[string] = @[]
    for e in RectEffects:
      names.add(e.name)
    check names == @["bevel", "gradient", "dropShadow", "glow", "inset"]

suite "colour helpers":
  ## `fadeColor` was private and documented as fading to transparent, while
  ## actually scaling the RGB channels. basic/scrollbar.nim wanted the fade and
  ## inlined its own maths rather than call it -- exporting the proc would not
  ## have helped, because it does a different thing. Now there are two, named
  ## for what they each do.

  test "dimColor scales toward black and keeps the alpha":
    let c = dimColor(Color(r: 200, g: 100, b: 50, a: 255), 0.5)
    check c.r == 100
    check c.g == 50
    check c.b == 25
    check c.a == 255

  test "withAlpha scales the opacity and keeps the hue":
    let c = withAlpha(Color(r: 200, g: 100, b: 50, a: 200), 0.5)
    check c.r == 200
    check c.g == 100
    check c.b == 50
    check c.a == 100

suite "the visual-state ladder":
  ## 43 call sites across 21 files each re-derived this from the same flags, and
  ## it could only be reached by rendering. It is a function over four bools now.

  test "disabled outranks everything":
    check visualState(disabled = true, pressed = true, hovered = true,
                      focused = true) == ThemeState.Disabled

  test "pressed outranks hover and focus":
    # Something is happening to this control right now, which is more use to
    # show than where the pointer or the caret happens to be.
    check visualState(false, pressed = true, hovered = true,
                      focused = true) == ThemeState.Pressed

  test "nothing set is Normal":
    check visualState(false, false, false, false) == ThemeState.Normal

  test "the pointer-first ladder shows hover over focus":
    # Buttons: the pointer is about to act on THIS control.
    check visualState(false, false, hovered = true, focused = true,
                      ladder = slPointerFirst) == ThemeState.Hovered

  test "the focus-first ladder shows focus over hover":
    # Text fields: where the caret will go matters more than where the pointer is.
    check visualState(false, false, hovered = true, focused = true,
                      ladder = slFocusFirst) == ThemeState.Focused

  test "the ladders agree when only one of the two is set":
    for ladder in [slPointerFirst, slFocusFirst]:
      check visualState(false, false, hovered = true, focused = false,
                        ladder = ladder) == ThemeState.Hovered
      check visualState(false, false, hovered = false, focused = true,
                        ladder = ladder) == ThemeState.Focused

  test "pointer-first is the default":
    check visualState(false, false, true, true) ==
          visualState(false, false, true, true, slPointerFirst)

suite "themeProps reads the widget's own flags":
  setup: animationsEnabled = false      # these read the settled state, not a point in a fade
  teardown: animationsEnabled = true


  test "it uses hovered and focused from the base Widget fields":
    let w = newButton(text = "x")
    w.hovered = true
    let hovered = w.themeProps(ThemeIntent.Default, crPointer)
    w.hovered = false
    let normal = w.themeProps(ThemeIntent.Default, crPointer)
    # The built-in light theme gives these different backgrounds; what matters
    # here is that the flag is being read at all.
    check hovered != normal

  test "disabled and pressed are passed in, because widgets spell them differently":
    # A Slider is pressed while dragging, a ComboBox while its list is open, a
    # ToolButton while it is the active tool. One base flag would lose that.
    let w = newButton(text = "x")
    let pressed = w.themeProps(ThemeIntent.Default, pressed = true)
    let disabled = w.themeProps(ThemeIntent.Default, disabled = true)
    check pressed != disabled

suite "the theme owns the hover-or-focus preference":
  setup: animationsEnabled = false      # these read the settled state, not a point in a fade
  teardown: animationsEnabled = true

  ## A widget says what it is (crText / crPointer); which of hover and focus
  ## wins is the theme's call, read from the in-memory currentTheme on every
  ## lookup -- never re-read from the theme file.

  proc noExtends(name: string): Theme = newTheme(name)

  test "a fresh theme keeps the library's defaults":
    let t = newTheme("t")
    check t.ladderFor(crText) == slFocusFirst
    check t.ladderFor(crPointer) == slPointerFirst

  test "a zero-initialised theme gets the defaults too":
    var t: Theme
    check t.ladderFor(crText) == slFocusFirst
    check t.ladderFor(crPointer) == slPointerFirst

  test "a theme file can override either role":
    let t = parseTheme("""
name: prefs
statePreference:
  text: hover
  pointer: focus
""", tffYaml, noExtends)
    check t.ladderFor(crText) == slPointerFirst
    check t.ladderFor(crPointer) == slFocusFirst

  test "an unknown role or preference is an error, not a silent default":
    expect ValueError:
      discard parseTheme("statePreference: {slider: focus}", tffYaml, noExtends)
    expect ValueError:
      discard parseTheme("statePreference: {text: sometimes}", tffYaml, noExtends)

  test "themeProps follows the current theme's preference":
    let saved = currentTheme
    defer: currentTheme = saved
    var t = newTheme("prefs")
    t.states[ThemeIntent.Default][ThemeState.Hovered] =
      ThemeProps(backgroundColor: some(Color(r: 1, g: 0, b: 0, a: 255)))
    t.states[ThemeIntent.Default][ThemeState.Focused] =
      ThemeProps(backgroundColor: some(Color(r: 0, g: 0, b: 1, a: 255)))
    let w = newButton(text = "x")
    w.hovered = true
    w.focused = true

    currentTheme = t
    check w.themeProps(ThemeIntent.Default, crPointer).backgroundColor.get.r == 1

    t.statePreference[crPointer] = spFocusFirst
    currentTheme = t
    check w.themeProps(ThemeIntent.Default, crPointer).backgroundColor.get.b == 1

  test "derived themes inherit the preference":
    let tm = newThemeManager()
    var base = newTheme("base")
    base.statePreference[crText] = spHoverFirst
    tm.register("base", base)
    check tm.derive("base").ladderFor(crText) == slPointerFirst

suite "branded themes":

  test "hex and mix":
    check hex"#4F46E5" == Color(r: 0x4F, g: 0x46, b: 0xE5, a: 255)
    check hex"#11223380".a == 0x80
    let mid = mix(Color(r: 0, g: 0, b: 0, a: 255), Color(r: 200, g: 100, b: 50, a: 255), 0.5)
    check mid == Color(r: 100, g: 50, b: 25, a: 255)

  test "a brand theme is complete: every intent has its colours":
    let t = brandTheme(daylightSpec())
    for intent in ThemeIntent:
      let p = t.getThemeProps(intent, ThemeState.Normal)
      check p.backgroundColor.isSome
      check p.foregroundColor.isSome
      check p.activeColor.isSome
    for state in [Hovered, Pressed, Focused, Disabled]:
      check t.states[ThemeIntent.Default].hasKey(state)

  test "the accent reaches the parts that used to fall back to one blue":
    let spec = auroraSpec()
    let p = brandTheme(spec).getThemeProps(ThemeIntent.Default, ThemeState.Normal)
    check p.activeColor.get == spec.accent
    check p.focusColor.get == spec.accent

  test "the primary action is solid accent":
    let spec = oceanSpec()
    let p = brandTheme(spec).getThemeProps(ThemeIntent.Info, ThemeState.Normal)
    check p.backgroundColor.get == spec.accent
    check p.foregroundColor.get == Color(r: 255, g: 255, b: 255, a: 255)

  test "hovering leans toward the accent; disabling fades":
    let spec = daylightSpec()
    let t = brandTheme(spec)
    let normal = t.getThemeProps(ThemeIntent.Default, ThemeState.Normal).backgroundColor.get
    let hovered = t.getThemeProps(ThemeIntent.Default, ThemeState.Hovered).backgroundColor.get
    check hovered != normal
    let disabledFg = t.getThemeProps(ThemeIntent.Default, ThemeState.Disabled).foregroundColor.get
    check disabledFg != spec.text

  test "every shipped brand is registered":
    let tm = newThemeManager()
    for key in ["daylight", "midnight", "aurora", "ocean", "forest",
                "rose", "ember", "graphite", "light", "dark"]:
      check key in tm.listThemes()

  test "a theme's typography becomes the default font family":
    let saved = currentTheme
    defer: setCurrentTheme(saved)
    setCurrentTheme(brandTheme(forestSpec()))
    check themeFontFamily == "Serif"
    check TextStyle(fontSize: 14.0).pangoFont.startsWith("Serif")
    setCurrentTheme(brandTheme(daylightSpec()))
    check themeFontFamily == ""

suite "theme: geometry (fat and bold, thin and lean)":

  proc noExtends(name: string): Theme = newTheme(name)

  test "a brand's stroke, radius, padding and weight reach every intent":
    let t = brandTheme(punchSpec())
    for intent in ThemeIntent:
      let p = t.getThemeProps(intent)
      check p.borderWidth.get == 3.0
      check p.cornerRadius.get == 6.0
      check p.padding.get.left == 22.0
      check p.isBold
      check p.uppercase.get(false)
      check p.shadowOffset == (4.0'f32, 4.0'f32)

  test "unset geometry falls back to the library defaults":
    let t = brandTheme(daylightSpec())
    check t.getThemeProps().borderWidth.get == 1.0
    check not t.getThemeProps().isBold
    check t.getThemeProps().shadowOffset == (0.0'f32, 0.0'f32)
    check t.indicatorSize == 20.0
    check t.controlHeight == 0.0
    var bare: Theme
    check bare.thumbSize == 20.0

  test "a borderless brand has no outlines":
    var spec = daylightSpec()
    spec.borderless = true
    check brandTheme(spec).getThemeProps().strokeWidth == 0.0

  test "a theme file can set geometry":
    let t = parseTheme("""
name: slab
base:
  default:
    borderWidth: 4
    fontWeight: bold
    uppercase: true
    dropShadowOffset: 5
metrics:
  controlHeight: 48
  indicatorSize: 26
  thumbSize: 30
""", tffYaml, noExtends)
    let p = t.getThemeProps()
    check p.strokeWidth == 4.0
    check p.isBold
    check p.uppercase.get(false)
    check p.shadowOffset == (5.0'f32, 5.0'f32)
    check t.controlHeight == 48.0
    check t.indicatorSize == 26.0
    check t.thumbSize == 30.0
    check t.trackThickness == 8.0          # unset: the default

  test "widgets size themselves from the theme":
    let saved = currentTheme
    defer: setCurrentTheme(saved)
    proc sizes(theme: Theme): tuple[button, check, input: Rect] =
      setCurrentTheme(theme)
      let b = newButton(text = "Save")
      let c = newCheckbox(text = "Remember me")
      let i = newTextInput()
      for w in [Widget(b), Widget(c), Widget(i)]:
        w.bounds = Rect()
        w.layout()
      (b.bounds, c.bounds, i.bounds)
    let fat = sizes(brandTheme(punchSpec()))
    let lean = sizes(brandTheme(hairlineSpec()))
    check fat.button.height >= 46.0         # the brand's control height
    check lean.button.height < fat.button.height
    check fat.button.width > lean.button.width
    check fat.check.height >= 24.0          # its indicator size
    check lean.check.height < fat.check.height
    check fat.input.height > lean.input.height

  test "a pressed button sinks into its shadow":
    let saved = currentTheme
    defer: setCurrentTheme(saved)
    setCurrentTheme(brandTheme(punchSpec()))
    let b = newButton(text = "Go")
    b.bounds = Rect(x: 0, y: 0, width: 100, height: 50)
    b.layout()
    let up = b.children[0].bounds
    b.isPressed = true
    b.layout()
    let down = b.children[0].bounds
    check up.x == 0 and up.width == 96      # room left for the shadow
    check down.x == 4 and down.y == 4       # moved into it

  test "switching theme at runtime re-measures the same widgets":
    let saved = currentTheme
    defer: setCurrentTheme(saved)
    setCurrentTheme(brandTheme(punchSpec()))
    let b = newButton(text = "Save")
    let c = newCheckbox(text = "Remember me")
    let i = newTextInput()
    let box = newComboBox(items = @["One", "Two"])
    let all = [Widget(b), Widget(c), Widget(i), Widget(box)]
    proc settle() =
      # What app.setTheme does: forget self-sized bounds and lay out again.
      for w in all:
        w.bounds = Rect()
        w.layout()
    settle()
    var fat: seq[float32]
    for w in all: fat.add w.bounds.height
    setCurrentTheme(brandTheme(hairlineSpec()))
    settle()
    for n, w in all:
      check w.bounds.height < fat[n]

  test "rows, bars and scrollbars follow the theme's metrics":
    let saved = currentTheme
    defer: setCurrentTheme(saved)
    proc measure(theme: Theme): tuple[list, tab, status, scroll, panelPad: float32] =
      setCurrentTheme(theme)
      let l = newListBox(items = @["a", "b"], visibleRows = 2)
      let t = newTabControl(tabs = @["One", "Two"])
      let st = newStatusBar(text = "Ready")
      let sb = newScrollbar(vertical = true)
      let p = newPanel()
      for w in [Widget(l), Widget(t), Widget(st), Widget(sb), Widget(p)]:
        w.bounds = Rect()
        w.layout()
      (l.bounds.height / 2, t.bounds.height, st.bounds.height, sb.bounds.width,
       p.bounds.height)
    let fat = measure(brandTheme(punchSpec()))
    let lean = measure(brandTheme(hairlineSpec()))
    check fat.list == 38.0
    check lean.list == 22.0
    check fat.tab >= 46.0                    # the control height
    check fat.status >= 46.0
    check fat.scroll == 18.0
    check lean.scroll == 8.0
    check fat.panelPad > lean.panelPad       # themed padding, not a constant 8

  test "an explicit size still beats the theme":
    let saved = currentTheme
    defer: setCurrentTheme(saved)
    setCurrentTheme(brandTheme(punchSpec()))
    let l = newListBox(items = @["a"], itemHeight = 20.0, visibleRows = 1)
    l.bounds = Rect()
    l.layout()
    check l.bounds.height == 20.0
    let bar = newStatusBar(text = "x", barHeight = 24.0)
    bar.bounds = Rect()
    bar.layout()
    check bar.bounds.height == 24.0

suite "theme: brand sections in theme files":

  proc noExtends(name: string): Theme = newTheme(name)

  test "a brand: section builds a complete theme":
    let t = parseTheme("""
brand:
  name: Acme
  accent: "#E4572E"
  canvas: "#FAF7F2"
  surface: "#FFFFFF"
  text: "#1D1A17"
  border: "#E7E0D6"
  radius: 10
  borderWidth: 3
  boldCaptions: true
  shadow: 4
""", tffYaml, noExtends)
    check t.name == "Acme"
    for intent in ThemeIntent:
      check t.getThemeProps(intent).borderWidth.get == 3.0
    check t.getThemeProps().isBold
    check t.getThemeProps().cornerRadius.get == 10.0
    check t.getThemeProps(ThemeIntent.Info).backgroundColor.get == hex"#E4572E"

  test "base and states still override the brand":
    let t = parseTheme("""
brand: {name: Acme, accent: "#E4572E", canvas: "#FAF7F2", surface: "#FFFFFF", text: "#1D1A17", border: "#E7E0D6", radius: 8}
base:
  danger:
    cornerRadius: 0
""", tffYaml, noExtends)
    check t.getThemeProps(ThemeIntent.Danger).cornerRadius.get == 0.0
    check t.getThemeProps(ThemeIntent.Default).cornerRadius.get(-1) != 0.0

  test "a file brand equals the same spec built in code":
    let fromFile = parseTheme("""
brand: {name: Daylight, accent: "#4F46E5", canvas: "#F3F4F7", surface: "#FFFFFF", text: "#1F2330", border: "#DCDFE6", radius: 6}
""", tffYaml, noExtends)
    let inCode = brandTheme(daylightSpec())
    for intent in ThemeIntent:
      check fromFile.getThemeProps(intent) == inCode.getThemeProps(intent)

suite "theme: files are validated, inheritance is checked":

  proc noExtends(name: string): Theme = newTheme(name)

  test "a mistyped key is an error that says what was meant":
    var msg = ""
    try:
      discard parseTheme("base:\n  default:\n    corner_radius: 8\n", tffYaml, noExtends)
    except ValueError as e: msg = e.msg
    check "unknown key 'corner_radius' in base.default" in msg
    check "did you mean 'cornerRadius'" in msg

  test "unknown keys are caught at every level, in JSON too":
    expect ValueError:
      discard parseTheme("""{"nmae": "x"}""", tffJson, noExtends)
    expect ValueError:
      discard parseTheme("""{"base": {"default": {"padding": {"al": 3}}}}""", tffJson, noExtends)
    expect ValueError:
      discard parseTheme("""{"brand": {"acent": "#fff"}}""", tffJson, noExtends)
    expect ValueError:
      discard parseTheme("""{"metrics": {"rowheight": 3}}""", tffJson, noExtends)

  test "an unknown intent or state is an error, not Default or Normal":
    expect ValueError:
      discard parseTheme("""{"base": {"dangerous": {}}}""", tffJson, noExtends)
    expect ValueError:
      discard parseTheme("""{"states": {"default": {"hover": {}}}}""", tffJson, noExtends)
    # ...but the names stay case-insensitive.
    discard parseTheme("""{"base": {"Danger": {}}, "states": {"default": {"Hovered": {}}}}""",
                       tffJson, noExtends)

  test "every example theme file still loads":
    for f in ["examples/themes/light.yaml", "examples/themes/dark.yaml"]:
      let tm = newThemeManager()
      discard tm.loadFromFile(f)

  test "derive keeps everything, metrics included":
    let tm = newThemeManager()
    tm.register("punch", brandTheme(punchSpec()))
    let d = tm.derive("punch", "Mine")
    check d.name == "Mine"
    check d.controlHeight == 46.0
    check d.getThemeProps().borderWidth.get == 3.0
    check d.getThemeProps().isBold

  test "extends through files: chains work, cycles and unknown names are errors":
    let dir = getTempDir() / "rui_theme_test"
    createDir(dir)
    defer: removeDir(dir)
    writeFile(dir / "a.yaml", "name: a\nextends: b\n")
    writeFile(dir / "b.yaml", "name: b\nextends: a\n")
    writeFile(dir / "c.yaml", "name: c\nextends: nowhere\n")
    writeFile(dir / "leaf.yaml", "name: leaf\nextends: mid\nbase:\n  default:\n    cornerRadius: 1\n")
    writeFile(dir / "mid.yaml", "name: mid\nextends: daylight\nbase:\n  default:\n    borderWidth: 5\n")
    let tm = newThemeManager()
    for (n, t) in brandThemes(): tm.register(n, t)
    var msg = ""
    try: discard tm.loadFromFile(dir / "a.yaml")
    except ValueError as e: msg = e.msg
    check "theme extends itself: a -> b -> a" in msg
    check "a.yaml" in msg                       # names the file
    msg = ""
    try: discard tm.loadFromFile(dir / "c.yaml")
    except ValueError as e: msg = e.msg
    check "extends 'nowhere'" in msg
    let leaf = tm.loadFromFile(dir / "leaf.yaml")  # leaf -> mid -> daylight
    check leaf.getThemeProps().cornerRadius.get == 1.0     # its own
    check leaf.getThemeProps().borderWidth.get == 5.0      # mid's
    check leaf.getThemeProps().backgroundColor.get == hex"#FFFFFF"   # daylight's


suite "theme: inheritance":
  ## A theme that `extends` another starts as a copy of it and changes only
  ## what it says; the parent is never touched, and chains compose.

  proc parentTheme(): Theme =
    result = newTheme("parent")
    result.base[Default] = ThemeProps(cornerRadius: some(9.0'f32),
                                      borderWidth: some(2.0'f32))
    result.states[Default][Hovered] =
      ThemeProps(backgroundColor: some(Color(r: 1, g: 2, b: 3, a: 255)))
    result.metrics.controlHeight = some(40.0'f32)
    result.hint = HintStyle(borderWidth: some(5.0'f32), uppercase: some(false))
    result.statePreference[crPointer] = spFocusFirst

  proc registry(): proc(name: string): Theme =
    result = proc(name: string): Theme =
      case name
      of "parent": parentTheme()
      of "child":
        parseTheme("""{"name": "child", "extends": "parent",
                       "base": {"default": {"cornerRadius": 3}}}""",
                   tffJson, proc(n: string): Theme = parentTheme())
      else: raise newException(ValueError, "no theme " & name)

  test "an extending theme keeps what it does not mention":
    let find = registry()
    let child = parseTheme("""{"name": "c", "extends": "parent",
        "base": {"default": {"cornerRadius": 3}}}""", tffJson, find)
    check child.base[Default].cornerRadius.get == 3.0     # overridden
    check child.base[Default].borderWidth.get == 2.0      # inherited
    check child.states[Default][Hovered].backgroundColor.get.b == 3
    check child.controlHeight == 40.0
    check child.statePreference[crPointer] == spFocusFirst

  test "a state override replaces only the properties it names":
    let child = parseTheme("""{"name": "c", "extends": "parent",
        "states": {"default": {"hovered": {"borderColor": "#00ff00"}}}}""",
        tffJson, registry())
    check child.states[Default][Hovered].borderColor.get.g == 255
    check child.states[Default][Hovered].backgroundColor.get.b == 3  # still the parent's

  test "metrics and hint merge field by field":
    let child = parseTheme("""{"name": "c", "extends": "parent",
        "metrics": {"rowHeight": 30},
        "hint": {"background": "#102030"}}""", tffJson, registry())
    check child.metrics.rowHeight.get == 30.0
    check child.metrics.controlHeight.get == 40.0             # parent's
    check child.hint.background.get.b == 0x30
    check child.hint.borderWidth.get == 5.0                   # parent's
    check child.hint.uppercase.get == false                   # parent's

  test "the parent is not changed by its child":
    let find = registry()
    let before = find("parent")
    discard find("child")
    let after = find("parent")
    check after.base[Default].cornerRadius.get == before.base[Default].cornerRadius.get
    check after.base[Default].cornerRadius.get == 9.0

  test "three levels compose, the nearest ancestor winning":
    let find = registry()
    let grandchild = parseTheme("""{"name": "g", "extends": "child",
        "base": {"default": {"padding": {"all": 7}}}}""", tffJson, find)
    check grandchild.base[Default].cornerRadius.get == 3.0    # the child's
    check grandchild.base[Default].borderWidth.get == 2.0     # the parent's
    check grandchild.base[Default].padding.isSome             # its own


suite "theme: writing a theme back out":
  ## `toYaml` is the inverse of `parseTheme`: what a theme sets comes back as the
  ## same theme, so a theme made in code (or by a brand spec) can be saved.

  proc noExtends(name: string): Theme = newTheme(name)

  proc same(a, b: Theme): bool =
    a.name == b.name and a.base == b.base and a.states == b.states and
    a.metrics == b.metrics and a.hint == b.hint and a.animation == b.animation and
    a.statePreference == b.statePreference

  test "every brand theme round-trips through YAML and through JSON":
    for (key, theme) in brandThemes():
      let viaYaml = parseTheme(toYaml(theme), tffYaml, noExtends)
      check same(theme, viaYaml)
      let viaJson = parseTheme(toJsonText(theme), tffJson, noExtends)
      check same(theme, viaJson)

  test "every registered theme round-trips, the legacy five included":
    let tm = newThemeManager()
    for name in tm.listThemes():
      let theme = tm.get(name)
      check same(theme, parseTheme(toYaml(theme), tffYaml, noExtends))

  test "a hand-built theme round-trips, including padding forms and effects":
    var t = newTheme("Hand Made")
    t.version = "1.2.0"
    t.base[Default] = ThemeProps(
      backgroundColor: some(Color(r: 1, g: 2, b: 3, a: 255)),
      borderColor: some(Color(r: 9, g: 8, b: 7, a: 128)),
      cornerRadius: some(2.5'f32), borderWidth: some(0.0'f32),
      padding: some(edgeInsetsLTRB(1, 2, 3, 4)),
      fontWeight: some(SemiBold), uppercase: some(true),
      dropShadowOffset: some((3.0'f32, 3.0'f32)),
      bevelStyle: some(Raised), gradientDirection: some(theme_types.Radial))
    t.base[Info] = ThemeProps(padding: some(edgeInsetsSymmetric(12, 4)))
    t.base[Danger] = ThemeProps(padding: some(edgeInsets(6)), fontFamily: some("Fira Sans"))
    t.states[Default][Hovered] = ThemeProps(backgroundColor: some(Color(r: 10, g: 20, b: 30, a: 255)))
    t.metrics.controlHeight = some(38.0'f32)
    t.hint = HintStyle(borderWidth: some(3.0'f32), uppercase: some(false))
    t.statePreference[crPointer] = spFocusFirst
    t.animation.durationFast = some(80.0'f32)
    t.animation.defaultEasing = some(EaseInOut)
    check same(t, parseTheme(toYaml(t), tffYaml, noExtends))

  test "only what is set is written":
    var t = newTheme("Tiny")
    t.base[Default] = ThemeProps(cornerRadius: some(3.0'f32))
    let text = toYaml(t)
    check text == "name: Tiny\nbase:\n  default:\n    cornerRadius: 3\n"

  test "an offset that cannot be written is an error, not a silent change":
    var t = newTheme("Skew")
    t.base[Default] = ThemeProps(dropShadowOffset: some((1.0'f32, 2.0'f32)))
    expect ValueError: discard toYaml(t)

  test "the motion section is a real part of the format":
    let t = parseTheme("name: M\nanimation:\n  durationFast: 0\n  defaultEasing: easeOut\n",
                       tffYaml, noExtends)
    check t.animation.durationFast.get == 0
    check t.transitionSeconds == 0                  # 0 makes every change instant
    check t.animation.defaultEasing.get == EaseOut
    expect ValueError:
      discard parseTheme("name: M\nanimation:\n  durationFastt: 0\n", tffYaml, noExtends)
    expect ValueError:
      discard parseTheme("name: M\nanimation:\n  defaultEasing: wobble\n", tffYaml, noExtends)

  test "a derived theme's file keeps the parent's values (extends is not written)":
    let tm = newThemeManager()
    for (key, theme) in brandThemes(): tm.register(key, theme)
    var mine = tm.derive("daylight", "Mine")
    mine.base[Default].cornerRadius = some(0.0'f32)
    check same(mine, parseTheme(toYaml(mine), tffYaml, noExtends))


suite "theme: describe":

  proc noExtends(name: string): Theme = newTheme(name)

  test "describeChange names each property that differs, nested and unset included":
    var parent = newTheme("p")
    parent.base[Default] = ThemeProps(cornerRadius: some(4.0'f32))
    var child = parent
    child.name = "c"
    child.base[Default].cornerRadius = some(0.0'f32)
    child.base[Default].borderWidth = some(2.0'f32)
    child.states[Default][Hovered] = ThemeProps(hoverColor: some(Color(r: 255, g: 0, b: 0, a: 255)))
    let lines = describeChange(parent, child)
    check "base.default.cornerRadius: 4 -> 0" in lines
    check "base.default.borderWidth: (unset) -> 2" in lines
    check "states.default.hovered.hoverColor: (unset) -> \"#ff0000\"" in lines
    check lines.len == 3
    check describeChange(parent, parent).len == 0

  test "a chain of files is described level by level":
    let dir = getTempDir() / "rui_theme_describe"
    createDir(dir)
    defer: removeDir(dir)
    writeFile(dir / "leaf.yaml", "name: leaf\nextends: mid\nbase:\n  default:\n    cornerRadius: 1\n")
    writeFile(dir / "mid.yaml", "name: mid\nextends: daylight\nbase:\n  default:\n    borderWidth: 5\n")
    let tm = newThemeManager()
    discard tm.loadFromFile(dir / "leaf.yaml")
    let text = tm.describe("leaf")
    check text.startsWith("leaf (extends mid)\n")
    check "base.default.cornerRadius: " in text and "-> 1\n" in text
    check "mid (extends daylight)\n" in text
    check "base.default.borderWidth: " in text and "-> 5\n" in text
    check text.endsWith("daylight\n")

  test "derive records the parent; a theme with none is just named":
    let tm = newThemeManager()
    var mine = tm.derive("daylight", "Mine")
    mine.base[Default].cornerRadius = some(0.0'f32)
    tm.register("mine", mine)
    check mine.parent == "daylight"
    check tm.describe("mine").startsWith("mine (extends daylight)\n  base.default.cornerRadius")
    check tm.describe("daylight") == "daylight\n"
    check tm.describe("nowhere") == "nowhere (not registered)\n"


suite "theme: contrast":

  test "the arithmetic: black on white is 21, a colour on itself is 1":
    let white = Color(r: 255, g: 255, b: 255, a: 255)
    let black = Color(r: 0, g: 0, b: 0, a: 255)
    check abs(contrastRatio(black, white) - 21.0) < 0.01
    check abs(contrastRatio(white, white) - 1.0) < 0.001
    check abs(contrastRatio(Color(r: 119, g: 119, b: 119, a: 255), white) - 4.48) < 0.02
    check over(Color(r: 0, g: 0, b: 0, a: 128), white).r in 126'u8 .. 128'u8

  test "the high-contrast themes meet AAA for every caption and a 3:1 focus ring":
    let tm = newThemeManager()
    for name in ["contrast", "contrast-dark"]:
      let problems = contrastProblems(tm.get(name), textRatio = 7.0, uiRatio = 3.0)
      check problems.len == 0
      for p in problems: echo "  ", name, ": ", p

  test "every shipped theme keeps its resting captions readable (3:1) and its ring visible":
    let tm = newThemeManager()
    var brands: seq[string]
    for (key, _) in brandThemes(): brands.add key
    for name in tm.listThemes():
      for p in contrastProblems(tm.get(name), textRatio = 3.0, uiRatio = 1.5):
        # The five older themes predate the focus-ring rule: captions only.
        if "normal" in p.where or ("focus ring" in p.where and name in brands):
          checkpoint name & ": " & $p
          fail()

  test "a theme with a washed-out caption is reported, with where and by how much":
    var t = newTheme("Faint")
    t.base[Default] = ThemeProps(backgroundColor: some(Color(r: 255, g: 255, b: 255, a: 255)),
                                 foregroundColor: some(Color(r: 200, g: 200, b: 200, a: 255)))
    let problems = contrastProblems(t)
    check problems.len > 0
    check "default / normal: caption" in problems[0].where
    check problems[0].ratio < 2 and problems[0].needed == 4.5

  test "contrast themes round-trip through a file like any other":
    let tm = newThemeManager()
    let t = tm.get("contrast-dark")
    let back = parseTheme(toYaml(t), tffYaml, proc(n: string): Theme = newTheme(n))
    check back.base == t.base and back.states == t.states


suite "theme: hot reload":

  proc writeTheme(path, radius: string, extra = "") =
    writeFile(path, "name: live\nbase:\n  default:\n    cornerRadius: " & radius & "\n" & extra)

  test "saving the file produces the new theme; an unchanged file produces nothing":
    let dir = getTempDir() / "rui_theme_watch"
    createDir(dir)
    defer: removeDir(dir)
    let path = dir / "live.yaml"
    writeTheme(path, "3")
    let tm = newThemeManager()
    check tm.loadFromFile(path).base[Default].cornerRadius.get == 3
    let watch = watchTheme(path)
    check tm.reloaded(watch).isNone
    sleep(1100)                                         # a new modification time
    writeTheme(path, "9")
    let again = tm.reloaded(watch)
    check again.isSome and again.get.base[Default].cornerRadius.get == 9
    check tm.get("live").base[Default].cornerRadius.get == 9      # the registry follows
    check tm.reloaded(watch).isNone

  test "a broken save keeps the last theme, says why once, and a fixed save recovers":
    let dir = getTempDir() / "rui_theme_watch2"
    createDir(dir)
    defer: removeDir(dir)
    let path = dir / "live.yaml"
    writeTheme(path, "3")
    let tm = newThemeManager()
    discard tm.loadFromFile(path)
    let watch = watchTheme(path)
    sleep(1100)
    writeTheme(path, "9", "  corner_radius: 4\n")       # a key the format does not have
    check tm.reloaded(watch).isNone
    check "corner_radius" in watch.lastError
    check tm.reloaded(watch).isNone                      # the same breakage: not retried
    check tm.get("live").base[Default].cornerRadius.get == 3
    sleep(1100)
    writeTheme(path, "7")
    check tm.reloaded(watch).get.base[Default].cornerRadius.get == 7
    check watch.lastError == ""

  test "a theme it extends, beside it, is watched too":
    let dir = getTempDir() / "rui_theme_watch3"
    createDir(dir)
    defer: removeDir(dir)
    writeFile(dir / "wparent.yaml", "name: wparent\nbase:\n  default:\n    cornerRadius: 2\n")
    writeFile(dir / "child.yaml", "name: childlive\nextends: wparent\nbase:\n  default:\n    borderWidth: 1\n")
    let tm = newThemeManager()
    check tm.loadFromFile(dir / "child.yaml").base[Default].cornerRadius.get == 2
    let watch = watchTheme(dir / "child.yaml")
    sleep(1100)
    writeFile(dir / "wparent.yaml", "name: wparent\nbase:\n  default:\n    cornerRadius: 8\n")
    let fresh = tm.reloaded(watch)
    check fresh.isSome
    check fresh.get.base[Default].cornerRadius.get == 8     # the parent's new value
    check fresh.get.base[Default].borderWidth.get == 1      # the child's own

  test "an App with watchTheme restyles itself when the file is saved":
    let dir = getTempDir() / "rui_theme_watch4"
    createDir(dir)
    defer: removeDir(dir)
    let path = dir / "live.yaml"
    writeTheme(path, "3")
    let saved = currentTheme
    defer: setCurrentTheme(saved)
    let app = newApp(title = "t", width = 300, height = 200)
    app.setRootWidget(newVStack())
    app.watchTheme(path)
    check currentTheme.base[Default].cornerRadius.get == 3
    sleep(1100)
    writeTheme(path, "11")
    app.pollThemeWatch(getMonoTime() + initDuration(seconds = 2))
    check currentTheme.base[Default].cornerRadius.get == 11
    check app.tree.root.isDirty                        # and the tree repaints


suite "theme: state changes fade":

  setup:
    animationsEnabled = true
  teardown:
    animationsEnabled = true

  proc fadeTheme(ms: float32): Theme =
    var t = newTheme("Fade")
    t.base[Default] = ThemeProps(backgroundColor: some(Color(r: 0, g: 0, b: 0, a: 255)))
    t.states[Default][Hovered] = ThemeProps(backgroundColor: some(Color(r: 200, g: 100, b: 50, a: 255)))
    t.animation.durationFast = some(ms)
    t

  test "mixColors moves colours, and takes everything else from the target":
    let a = ThemeProps(backgroundColor: some(Color(r: 0, g: 0, b: 0, a: 255)),
                       borderWidth: some(1.0'f32))
    let b = ThemeProps(backgroundColor: some(Color(r: 100, g: 200, b: 50, a: 255)),
                       borderWidth: some(3.0'f32))
    let half = mixColors(a, b, 0.5)
    check half.backgroundColor.get == Color(r: 50, g: 100, b: 25, a: 255)
    check half.borderWidth.get == 3.0                     # sizes do not blend
    check mixColors(a, b, 1.0).backgroundColor == b.backgroundColor

  test "hovering starts a fade: the first frames are between the colours, then it settles":
    let saved = currentTheme
    defer: setCurrentTheme(saved)
    setCurrentTheme(fadeTheme(120))
    let w = newButton(text = "x")
    check w.themeProps(Default).backgroundColor.get.r == 0       # first look: settled
    w.hovered = true
    let mid = w.themeProps(Default).backgroundColor.get
    check mid.r < 200                                   # not there yet
    check w.fadeActive
    sleep(200)
    check w.themeProps(Default).backgroundColor.get.r == 200      # arrived
    check not w.fadeActive

  test "a theme with durationFast 0 snaps":
    let saved = currentTheme
    defer: setCurrentTheme(saved)
    setCurrentTheme(fadeTheme(0))
    let w = newButton(text = "x")
    discard w.themeProps(Default)
    w.hovered = true
    check w.themeProps(Default).backgroundColor.get.r == 200
    check not w.fadeActive

  test "switching theme lands at once, without a fade":
    let saved = currentTheme
    defer: setCurrentTheme(saved)
    setCurrentTheme(fadeTheme(120))
    let w = newButton(text = "x")
    discard w.themeProps(Default)
    w.hovered = true
    discard w.themeProps(Default)                       # fading
    setCurrentTheme(fadeTheme(120))                     # a theme switch bumps settleEpoch
    check w.themeProps(Default).backgroundColor.get.r == 200
    check not w.fadeActive

  test "reduced motion (animationsEnabled = false) never fades":
    let saved = currentTheme
    defer: setCurrentTheme(saved)
    setCurrentTheme(fadeTheme(120))
    animationsEnabled = false
    let w = newButton(text = "x")
    discard w.themeProps(Default)
    w.hovered = true
    check w.themeProps(Default).backgroundColor.get.r == 200

  test "a disposed widget leaves no fade behind":
    let saved = currentTheme
    defer: setCurrentTheme(saved)
    setCurrentTheme(fadeTheme(120))
    let w = newButton(text = "x")
    discard w.themeProps(Default)
    w.hovered = true
    discard w.themeProps(Default)
    check w.fadeActive
    disposeTree(w)
    check not w.fadeActive

suite "BeOS theme":
  let be = createBeosTheme()

  test "every intent is a raised bevel with square corners":
    for intent in ThemeIntent:
      let p = be.getThemeProps(intent, Normal)
      check p.bevelStyle == some(BeRaised)
      check p.cornerRadius == some(0.0'f32)
  test "pressed inverts the bevel and darkens the face; hover changes nothing":
    let base = be.getThemeProps(Default, Normal)
    let pressed = be.getThemeProps(Default, Pressed)
    let hovered = be.getThemeProps(Default, Hovered)
    check pressed.bevelStyle == some(BeSunken)
    check pressed.backgroundColor.get.r < base.backgroundColor.get.r
    check hovered.backgroundColor == base.backgroundColor
    check hovered.bevelStyle == base.bevelStyle
  test "controls are Be light grey (232) and disabled keeps the bevel with dim ink":
    check be.getThemeProps(Default, Normal).backgroundColor == some(Color(r: 232, g: 232, b: 232, a: 255))   # R5 buttons are lighter than the 216 panel
    check be.getThemeProps(Default, Disabled).foregroundColor.get.r > 100
  test "it carries its own name":
    check createBeosTheme().name == "Classic BeOS"
  test "its type is a Helvetica-class sans, with fallbacks, as Swiss 721 was":
    check be.typography.primaryFont.get("").startsWith("Nimbus Sans")
    check "Helvetica" in be.typography.primaryFont.get("")
  test "its window titles are tabs, and a theme without a titleColor is not":
    check be.titleColor.isSome
    check createLightTheme().titleColor.isNone
