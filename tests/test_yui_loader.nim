## loadYui: a .yui document becomes a widget tree, state, bindings and handlers.

import std/[unittest, json, tables, options, strutils]
import rui

proc refresh(w: Widget) =
  ## Bound values reach a widget in its refresh hook, which the frame runs
  ## before layout.
  if w.onRefresh != nil: w.onRefresh()

proc kinds(w: Widget): seq[string] =
  for c in w.children: result.add c.getTypeName()

suite "loadYui":

  test "a column of widgets":
    let doc = loadYuiText("""
app: "Demo"
view:
  - column:
      spacing: 8
      children:
        - label "Hello"
        - button "Save"
""")
    check doc.title == "Demo"
    check doc.warnings.len == 0
    check doc.root.getTypeName() == "Column"
    check doc.root.kinds == @["Label", "Button"]
    check Flex(doc.root).spacing == 8.0f32

  test "state is a store; bind <-> follows both ways":
    let doc = loadYuiText("""
state:
  name: "Ada"
  agreed: false
  volume: 3
view:
  - column:
      children:
        - input: {bind <-> name, placeholder: "Your name"}
        - checkbox "I agree": {bind <-> agreed}
        - slider: {bind <-> volume, min: 0, max: 10}
""")
    check doc.warnings.len == 0
    let store = doc.store
    let input = TextArea(doc.root.children[0])
    check input.text == "Ada"
    check input.placeholder == "Your name"
    store.set("name", "Grace")
    input.refresh()
    check input.text == "Grace"
    input.onChange("Hopper")
    check get[string](store, "name") == "Hopper"
    let box = Checkbox(doc.root.children[1])
    check box.text == "I agree"
    box.onToggle(true)
    check get[bool](store, "agreed")
    store.set("agreed", false)
    box.refresh()
    check not box.checked
    let slider = Slider(doc.root.children[2])
    check slider.maxValue == 10.0f32
    check slider.value == 3.0f32

  test "interpolation and visible: \"{!flag}\"":
    let doc = loadYuiText("""
state:
  name: "Ada"
  busy: false
view:
  - column:
      children:
        - label "Hello, {name}!"
        - button "Go": {visible: "{!busy}"}
""")
    check doc.warnings == newSeq[string]()
    let label = TextArea(doc.root.children[0])
    check label.text == "Hello, Ada!"
    doc.store.set("name", "Bob")
    label.refresh()
    check label.text == "Hello, Bob!"
    check doc.root.children[1].visible
    doc.store.set("busy", true)
    doc.root.children[1].refresh()
    check not doc.root.children[1].visible

  test "actions are looked up by name/arity":
    var actions: YuiActions
    var calls: seq[string]
    actions["save/0"] = proc (args: JsonNode) = calls.add "save " & $args
    let doc = loadYuiText("""
view:
  - button "Save": {on_click: save/0, size: 120x40}
actions: [save/0]
""", actions = actions)
    check doc.warnings.len == 0
    let button = Button(doc.root)
    button.onClick()
    check calls == @["save []"]
    check button.sizeRequest.width == 120.0f32
    check button.sizeRequest.height == 40.0f32

  test "tabs, grid, padding and margin":
    let doc = loadYuiText("""
view:
  - tab:
      children:
        - tab "General":
            children:
              - label "One"
              - label "Two"
        - tab "Advanced":
            children:
              - grid 3x2:
                  padding: 8px 16px
                  children:
                    - label "A"
""")
    check doc.warnings.len == 0
    let tabs = TabControl(doc.root)
    check tabs.tabs == @["General", "Advanced"]
    check tabs.children.len == 2
    check tabs.children[0].children.len == 2
    check tabs.children[1].getTypeName() == "Padding"

  test "problems are warnings with a path, and the rest still loads":
    let doc = loadYuiText("""
state:
  items: [1, 2]
view:
  - column:
      children:
        - frobnicate "x"
        - button "Go": {on_click: nothing/0, colour: red, intent: sparkly}
        - label "Hi": {font: Big, bind <-> missing}
        - spinner
""")
    check doc.root.children.len == 3
    let all = doc.warnings.join("\n")
    check "unknown element 'frobnicate'" in all
    check "no handler registered for action 'nothing/0'" in all
    check "unknown property 'colour'" in all
    check "'sparkly' does not fit intent" in all
    check "'font' is not mapped" in all
    check "'missing' is not declared" in all
    check "'items' is not declared" in all

  test "a document with no view, or not YAML, raises":
    expect YuiLoadError: discard loadYuiText("app: x")
    expect YuiLoadError: discard loadYuiText("view: [")
    expect YuiLoadError: discard loadYui("/nonexistent/file.yui")
