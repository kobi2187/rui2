## Widgets by name: every widget the yui table maps can be built from its name,
## its props set from JSON, and its handlers attached.

import std/[unittest, options, json]
import rui

suite "widget registry":

  test "every mapped widget is constructible by name":
    var missing: seq[string]
    for row in elementMap:
      if row.rui.len > 0 and newWidgetByName(row.rui).isNone: missing.add row.rui
    check missing.len == 0
    if missing.len > 0: echo "not registered: ", missing

  test "names ignore case and underscores":
    check blueprintFor("check_box").isSome
    check blueprintFor("CHECKBOX").isSome
    check blueprintFor("nonesuch").isNone

  test "props are coerced from json":
    let bp = blueprintFor("Slider").get
    let w = bp.create()
    check bp.setProp(w, "maxValue", %"240px")
    check Slider(w).maxValue == 240.0f32
    check not bp.setProp(w, "maxValue", %"wide")
    check not bp.setProp(w, "nonesuch", %1)

  test "enums by name, ignoring style":
    let bp = blueprintFor("Button").get
    let w = bp.create()
    check bp.setProp(w, "intent", %"info")
    check Button(w).intent == Info
    check not bp.setProp(w, "intent", %"sparkly")

  test "a seeding prop also sets its state":
    let bp = blueprintFor("Checkbox").get
    let w = bp.create()
    check bp.setProp(w, "initialChecked", %true)
    check Checkbox(w).checked
    check bp.setProp(w, "checked", %false)
    check not Checkbox(w).checked

  test "handlers receive their arguments as json":
    let bp = blueprintFor("Checkbox").get
    let w = bp.create()
    var seen: JsonNode
    check bp.attach(w, "on_toggle", proc (args: JsonNode) = seen = args)
    Checkbox(w).onToggle(true)
    check seen == %[true]
    check not bp.attach(w, "onNothing", proc (args: JsonNode) = discard)

  test "colours from hex":
    check parseHexColor("#fff").get.r == 255
    check parseHexColor("#102030").get.g == 0x20
    check parseHexColor("#10203040").get.a == 0x40
    check parseHexColor("blue").isNone
