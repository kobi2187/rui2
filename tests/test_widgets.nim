## Per-widget regression tests
##
## Every widget the library ships, exercised the same way: it constructs with
## sane defaults, its `initialX` props seed the matching state, it sizes itself,
## and it answers the scripting bridge.
##
## The `initialX` check matters — the DSL used to set every state field to
## default(T) unconditionally, so `initialChecked = true` built an unchecked
## checkbox and `initialValue = 62` built an empty progress bar.

import std/unittest
import rui
import std/[options, json]

template checkSizes(w: Widget) =
  ## Every widget must be able to give itself a size.
  w.layout()
  check w.bounds.width >= 0
  check w.bounds.height >= 0

template checkScriptable(w: Widget, expectedType: string) =
  ## Every DSL widget gets a generated scripting bridge.
  let state = w.getScriptableState()
  check state["type"].getStr() == expectedType
  check state.hasKey("visible")
  check state.hasKey("bounds")
  let res = w.handleScriptAction("read", newJObject())
  check res["success"].getBool()

suite "primitives":

  test "Label":
    let w = newLabel(text = "hello", fontSize = 18.0)
    check w.text == "hello"
    check w.fontSize == 18.0
    w.checkSizes()
    check w.bounds.width > 0
    check w.bounds.height > 0
    w.checkScriptable("Label")

  test "Label styling props":
    let bold = newLabel(text = "x", fontSize = 14.0, bold = true)
    let plain = newLabel(text = "x", fontSize = 14.0)
    bold.layout()
    plain.layout()
    check bold.bold
    check bold.bounds.width >= plain.bounds.width

  test "Rectangle":
    let w = newRectangle(color = RED, cornerRadius = 6.0, filled = true)
    check w.filled
    check w.cornerRadius == 6.0
    w.bounds = Rect(x: 0, y: 0, width: 40, height: 20)
    w.checkSizes()
    w.checkScriptable("Rectangle")

  test "Circle":
    let w = newCircle(color = BLUE, filled = true)
    w.bounds = Rect(x: 0, y: 0, width: 30, height: 30)
    w.checkSizes()
    w.checkScriptable("Circle")

suite "basic widgets":

  test "Button":
    let w = newButton(text = "Save")
    check w.text == "Save"
    check not w.disabled
    w.checkSizes()
    check w.bounds.width > 0 and w.bounds.height > 0
    w.checkScriptable("Button")

  test "Button click through the scripting bridge":
    let w = newButton(text = "Go")
    var fired = 0
    w.onClick = some(proc() {.closure.} = inc fired)
    let res = w.handleScriptAction("click", newJObject())
    check res["success"].getBool()
    check fired == 1

  test "Button intent is carried":
    let w = newButton(text = "Delete", intent = ThemeIntent.Danger)
    check w.intent == ThemeIntent.Danger
    check w.getScriptableState()["intent"].getStr() == "Danger"

  test "Checkbox seeds state from initialChecked":
    check newCheckbox(text = "a", initialChecked = true).checked
    check not newCheckbox(text = "a", initialChecked = false).checked

  test "Checkbox sizes and scripts":
    let w = newCheckbox(text = "Remember me", initialChecked = false)
    w.checkSizes()
    check w.bounds.height > 0
    check w.bounds.width > 0
    w.checkScriptable("Checkbox")
    discard w.handleScriptAction("toggle", newJObject())
    check w.checked

  test "RadioButton":
    let w = newRadioButton(text = "Option A", value = "a", selectedValue = "a")
    check w.value == "a"
    w.checkSizes()
    w.checkScriptable("RadioButton")

  test "ProgressBar seeds state from initialValue":
    let w = newProgressBar(initialValue = 62.0, maxValue = 100.0)
    check w.value == 62.0
    check w.maxValue == 100.0
    w.checkSizes()
    check w.bounds.height > 0
    w.checkScriptable("ProgressBar")

  test "ProgressBar accepts a scripted write":
    let w = newProgressBar(initialValue = 0.0, maxValue = 100.0)
    let res = w.handleScriptAction("write", %*{"field": "value", "value": 42})
    check res["success"].getBool()
    check w.value == 42.0

  test "Slider seeds state from initialValue":
    let w = newSlider(initialValue = 25.0'f32, minValue = 0.0'f32,
                      maxValue = 100.0'f32)
    check w.value == 25.0'f32
    w.checkSizes()
    check w.bounds.width > 0
    w.checkScriptable("Slider")

  test "Hyperlink":
    let w = newHyperlink(text = "example", url = "https://example.com")
    check w.url == "https://example.com"
    check not w.visited
    w.checkSizes()
    check w.bounds.width > 0
    w.checkScriptable("Hyperlink")

  test "ImageWidget tolerates a missing file":
    # No GL context here, so it must not blow up merely being constructed and
    # laid out; loading is deferred to render.
    let w = newImageWidget(imagePath = "does-not-exist.png",
                           width = 64.0, height = 64.0)
    check w.imagePath == "does-not-exist.png"
    w.bounds = Rect(x: 0, y: 0, width: 64, height: 64)
    w.checkSizes()
    w.checkScriptable("ImageWidget")

suite "containers":

  test "VStack":
    let w = newVStack(spacing = 6.0, padding = 3.0)
    check w.spacing == 6.0
    check w.padding == 3.0
    w.addChild(newLabel(text = "a", fontSize = 14.0))
    w.checkSizes()
    w.checkScriptable("VStack")

  test "HStack":
    let w = newHStack(spacing = 4.0)
    w.addChild(newLabel(text = "a", fontSize = 14.0))
    w.addChild(newLabel(text = "b", fontSize = 14.0))
    w.checkSizes()
    check w.children.len == 2
    w.checkScriptable("HStack")

  test "ZStack layers its children":
    let w = newZStack()
    w.bounds = Rect(x: 0, y: 0, width: 100, height: 100)
    let back = newRectangle(color = BLACK, filled = true)
    let front = newRectangle(color = WHITE, filled = true)
    w.addChild(back)
    w.addChild(front)
    w.layout()
    # Both occupy the same cell rather than being stacked apart.
    check back.bounds.x == front.bounds.x
    check back.bounds.y == front.bounds.y
    w.checkScriptable("ZStack")

  test "ScrollView":
    let w = newScrollView()
    w.bounds = Rect(x: 0, y: 0, width: 200, height: 100)
    w.addChild(newLabel(text = "content", fontSize = 14.0))
    w.checkSizes()
    w.checkScriptable("ScrollView")

suite "scripting bridge, generically":

  test "every widget reports its own type name":
    let widgets: seq[(Widget, string)] = @[
      (Widget(newLabel(text = "x", fontSize = 14.0)), "Label"),
      (Widget(newButton(text = "x")), "Button"),
      (Widget(newCheckbox(text = "x")), "Checkbox"),
      (Widget(newRadioButton(text = "x")), "RadioButton"),
      (Widget(newProgressBar()), "ProgressBar"),
      (Widget(newSlider()), "Slider"),
      (Widget(newHyperlink(text = "x")), "Hyperlink"),
      (Widget(newVStack()), "VStack"),
      (Widget(newHStack()), "HStack"),
      (Widget(newZStack()), "ZStack"),
      (Widget(newScrollView()), "ScrollView"),
      (Widget(newRectangle()), "Rectangle"),
      (Widget(newCircle()), "Circle"),
    ]
    for (w, name) in widgets:
      check w.getTypeName() == name
      check w.getScriptableState()["type"].getStr() == name

  test "an unknown action is refused, not silently accepted":
    let w = newLabel(text = "x", fontSize = 14.0)
    let res = w.handleScriptAction("frobnicate", newJObject())
    check not res["success"].getBool()
    check res.hasKey("error")

  test "blockReading hides content":
    let w = newLabel(text = "secret", fontSize = 14.0)
    check w.getScriptableState().hasKey("text")
    w.blockReading = true
    check not w.getScriptableState().hasKey("text")
    let res = w.handleScriptAction("getText", newJObject())
    check not res["success"].getBool()

suite "the DSL init section":
  ## `init:` is parsed into WidgetSections.initBody and was then used by
  ## nothing, so every init block in the library was silently dead code -- the
  ## same failure as TextInput's `input:` and `on_click:` sections, which the
  ## DSL also parsed and ignored.

  test "MenuBar starts with no menu open":
    # Its init sets activeMenuIndex and hoverIndex to -1. Without init running
    # they defaulted to 0, so a fresh MenuBar believed menu 0 was already open
    # and painted its title as selected.
    let bar = newMenuBar()
    check bar.activeMenuIndex == -1
    check bar.hoverIndex == -1

  test "MenuBar sorts its dropdowns on top":
    # Dropdowns must paint over whatever follows them in the child list.
    let bar = newMenuBar()
    check bar.hasOverlay

  test "init runs after the initialX props have seeded state":
    # Ordering matters: init is where a widget corrects or extends what the
    # seeding convention set, so it has to come last.
    let w = newCheckbox(text = "x", initialChecked = true)
    check w.checked

# ---------------------------------------------------------------------------
# A widget written by hand, with no DSL involved.
#
# This is the point of splitting the scripting bridge out of the macro: the
# descriptor is ordinary data. A `ref object of Widget` that builds one gets
# the same verb set -- read, write, invoke, the action aliases, the error
# shapes -- by calling the same proc the generated method calls.
# ---------------------------------------------------------------------------

type Gauge = ref object of Widget
  level: float32
  onCalibrate: Option[proc()]

let GaugeScript = ScriptDescriptor(
  typeName: "Gauge",
  defaultField: "level",
  fields: @[scriptField("level", proc (w: Widget, v: JsonNode): bool {.closure.} =
                                   scriptAssign(Gauge(w).level, v))],
  actions: @[scriptAction(@["oncalibrate", "calibrate"],
                          proc (w: Widget): bool {.closure.} =
                            fireAction(Gauge(w).onCalibrate))])

method getTypeName(widget: Gauge): string = "Gauge"

method handleScriptAction(widget: Gauge, action: string,
                          params: JsonNode): JsonNode =
  dispatchScriptAction(widget, GaugeScript, action, params)

suite "a hand-written widget scripts the same way":
  proc newGauge(): Gauge =
    result = Gauge(level: 0.0)
    result.enabled = true
    result.visible = true

  test "write reaches the default field with no field name given":
    let g = newGauge()
    let res = g.handleScriptAction("write", %*{"value": 0.75})
    check res["success"].getBool()
    check g.level == 0.75'f32

  test "a write marks the widget dirty, as the generated bridge does":
    let g = newGauge()
    g.isDirty = false
    g.layoutDirty = false
    discard g.handleScriptAction("set", %*{"field": "level", "value": 1})
    check g.isDirty
    check g.layoutDirty

  test "a value the field cannot hold is refused":
    let g = newGauge()
    let res = g.handleScriptAction("write", %*{"value": "not a number"})
    check not res["success"].getBool()

  test "an action fires under its on-less alias":
    var fired = 0
    let g = newGauge()
    g.onCalibrate = some(proc() {.closure.} = inc fired)
    check g.handleScriptAction("calibrate", newJObject())["success"].getBool()
    check fired == 1

  test "an action with nothing attached is not an error":
    let g = newGauge()
    let res = g.handleScriptAction("calibrate", newJObject())
    check res["success"].getBool()
    check res["note"].getStr() == "no handler attached"

  test "a disabled widget refuses its actions":
    let g = newGauge()
    g.enabled = false
    check not g.handleScriptAction("calibrate", newJObject())["success"].getBool()

  test "an unknown action is refused":
    let g = newGauge()
    check not g.handleScriptAction("explode", newJObject())["success"].getBool()

  test "toggle is refused on a widget with nothing to check":
    let g = newGauge()
    check not g.handleScriptAction("toggle", newJObject())["success"].getBool()

suite "json coercion, which the file protocol leans on":
  ## The scripting protocol carries text, not typed json, so `write 1` and
  ## `write true` arrive as strings. If these coercions were strict, nothing
  ## written from a script file would land.

  test "a checkbox accepts the spellings a script actually sends":
    for spelling in ["true", "1", "yes", "on", "TRUE", "Yes"]:
      check asBool(%spelling) == some(true)
    for spelling in ["false", "0", "no", "off", "anything else"]:
      check asBool(%spelling) == some(false)

  test "numbers survive the trip through text":
    check asInteger(%"42") == some(42.BiggestInt)
    check asNumber(%"0.5") == some(0.5)
    check asInteger(%3.7) == some(3.BiggestInt)

  test "text that is not a number is refused rather than read as zero":
    check asInteger(%"twelve").isNone
    check asNumber(%"").isNone

  test "anything at all can be read as text":
    check asText(%"plain") == "plain"
    check asText(%42) == "42"
    check asText(%*{"a": 1}) == """{"a":1}"""
