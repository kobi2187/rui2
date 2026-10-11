## yui_names: the element table stays true to the widgets, and the small
## value formats round-trip.

import std/[unittest, options, macros]
import rui

macro everyMappedWidgetExists(): untyped =
  ## A table row naming a widget that is not there is a compile error.
  result = newStmtList()
  var names: seq[string]
  for row in elementMap:
    if row.rui.len > 0: names.add row.rui
    if row.fallback.len > 0: names.add row.fallback
  for name in ruiOnly: names.add name
  for name in names:
    let ctor = ident("new" & name)
    let message = "yui_names: no constructor new" & name
    result.add quote do:
      when not declared(`ctor`):
        {.error: `message`.}

everyMappedWidgetExists()

suite "element table":

  test "kinds and widget names agree":
    for row in elementMap:
      if row.kind == mapGap: check row.rui == ""
      else: check row.rui != ""

  test "yui names are unique and lower-case":
    var seen: seq[string]
    for row in elementMap:
      check row.yui notin seen
      check row.yui == row.yui.toLowerAscii
      seen.add row.yui

  test "lookups":
    check yuiElement("Button").get.rui == "Button"
    check yuiElement("pane").get.rui == "SplitView"
    check yuiNameFor("SplitView").get == "pane"
    check yuiNameFor("ScrollView").get == "scroll"       # first row wins over `viewport`
    check yuiNameFor("Plot").isNone
    check isRuiOnly("Plot")
    check yuiElement("nonsense").isNone

  test "clashes are flagged, gaps fall back where a stand-in is honest":
    check yuiElement("spinner").get.kind == mapClash
    check yuiElement("table").get.kind == mapClash
    check widgetFor("spinner").get == "NumberInput"
    check widgetFor("stack").get == "IndexedStack"
    check widgetFor("icon").get == "IconButton"          # a gap with a stand-in
    check widgetFor("dialog").isNone                     # a gap without one
    check widgetFor("autocomplete").get == "ComboBox"

suite "element keys":

  test "type, size and quoted content":
    let k = parseYuiKey("button 120x40 \"Save changes\"")
    check k.kind == "button" and k.hasSize
    check k.width == 120 and k.height == 40
    check k.content == "Save changes"

  test "no size, no content":
    check parseYuiKey("row").kind == "row"
    check not parseYuiKey("row").hasSize
    check parseYuiKey("label \"Hi\"").content == "Hi"

  test "text that merely contains an x is content, not a size":
    let k = parseYuiKey("label next")
    check not k.hasSize and k.content == "next"
    check not parseYuiKey("label box 3").hasSize

  test "round trip":
    for key in ["button 120x40 \"Save\"", "label \"Hello, {name}\"", "row",
                "grid 3x2", "label \"12x4\"", "label \"say \\\"hi\\\"\""]:
      check formatYuiKey(parseYuiKey(key)) == key

suite "value formats":

  test "css insets":
    check parseCssInsets("16px").get == EdgeInsets.all(16)
    check parseCssInsets("8px 16px").get ==
          EdgeInsets.symmetric(horizontal = 16, vertical = 8)
    check parseCssInsets("1 2 3").get == EdgeInsets.fromLTRB(2, 1, 2, 3)
    check parseCssInsets("1px 2px 3px 4px").get == EdgeInsets.fromLTRB(4, 1, 2, 3)
    check parseCssInsets("").isNone
    check parseCssInsets("1 2 3 4 5").isNone
    check parseCssInsets("wide").isNone
    check parseCssInsets("-4px").isNone

  test "insets format as the shortest shorthand and parse back":
    for e in [EdgeInsets.all(16), EdgeInsets.symmetric(horizontal = 12, vertical = 4),
              EdgeInsets.fromLTRB(1, 2, 3, 4), EdgeInsets.all(8.5)]:
      check parseCssInsets(formatCssInsets(e)).get == e
    check formatCssInsets(EdgeInsets.all(16)) == "16px"

  test "width and height":
    check parseYuiDim("240px").get == YuiDim(kind: dimFixed, px: 240)
    check parseYuiDim("fill").get.kind == dimFill
    check parseYuiDim("auto").get.kind == dimAuto
    check parseYuiDim("big").isNone

  test "align and justify use our enum names, in any spelling":
    check parseJustify("spaceBetween").get == MainAxisAlignment.spaceBetween
    check parseJustify("space-between").get == MainAxisAlignment.spaceBetween
    check parseJustify("END").get == MainAxisAlignment.`end`
    check parseAlign("stretch").get == CrossAxisAlignment.stretch
    check parseAlign("spaceBetween").isNone               # that is justify's
    for a in MainAxisAlignment: check parseJustify($a).get == a
    for a in CrossAxisAlignment: check parseAlign($a).get == a

  test "grow":
    check parseYuiGrow("true").get == 1
    check parseYuiGrow("2").get == 2
    check parseYuiGrow("false").get == 0
    check parseYuiGrow("lots").isNone
    check formatYuiGrow(1.5) == "1.5"

  test "bind":
    check parseYuiBind("<-> username").get ==
          YuiBinding(direction: bindTwoWay, path: "username")
    check parseYuiBind("-> display").get.direction == bindToWidget
    check parseYuiBind("<- \"tasks[{i}].done\"").get.path == "tasks[{i}].done"
    check parseYuiBind("username").isNone
    check parseYuiBind("<->").isNone
    for text in ["<-> a.b", "-> x", "<- \"tasks[{i}].done\""]:
      check formatYuiBind(parseYuiBind(text).get) == text

  test "actions":
    check parseYuiAction("save/0").get == YuiAction(name: "save", arity: 0)
    check parseYuiAction("select/1").get.arity == 1
    check parseYuiAction("save").isNone
    check parseYuiAction("/1").isNone
    check parseYuiAction("a b/1").isNone
    check formatYuiAction(YuiAction(name: "go", arity: 2)) == "go/2"

  test "event names":
    check ruiEventName("on_click") == "onClick"
    check ruiEventName("on_value_change") == "onValueChange"
    check ruiEventName("padding") == ""
    check yuiEventName("onValueChange") == "on_value_change"
    check yuiEventName("online") == ""
