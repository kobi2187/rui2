## The example apps in examples/state/, driven like a user would: type, click,
## drag, and read what the bound labels say. They exercise `state:`, `->`, handlers
## and `derive` end to end.

import std/unittest
import rui
import ui_harness
from raylib import KeyboardKey, End, Home, Enter
import ../examples/state/greeter as greeterApp
import ../examples/state/temperature as tempApp
import ../examples/state/settings as settingsApp
import ../examples/state/shopping as shoppingApp

proc text(root: Widget, id: string): string = Label(root.byId(id)).text

suite "greeter":
  test "typing, the switch and Clear all reach the greeting":
    let root = greeterApp.buildUI()
    let r = newRig(root, 400, 300)
    check root.text("greeting") == "Hello, Ada!"
    let name = TextInput(root.byId("name"))
    r.click(name)
    r.key(End)
    for _ in 1 .. 3: r.key(KeyboardKey.Backspace)
    r.typeText("Bob")
    check root.text("greeting") == "Hello, Bob!"
    r.click(root.byId("shout"))
    check root.text("greeting") == "HELLO, BOB!"
    r.click(root.byId("clear"))
    check name.text == ""                                  # the Link wrote back to the field
    check root.text("greeting") == "HELLO, STRANGER!"

suite "temperature":
  test "the slider drives Celsius and the derived Fahrenheit":
    let root = tempApp.buildUI()
    let r = newRig(root, 400, 300)
    check root.text("summary") == "20 °C  =  68 °F"
    r.focus(root.byId("celsius"))
    r.key(End)
    check root.text("summary") == "100 °C  =  212 °F"
    r.key(Home)
    check root.text("summary") == "-40 °C  =  -40 °F"

suite "settings":
  test "controls share state; Reset restores everything in one go":
    let root = settingsApp.buildUI()
    let r = newRig(root, 460, 400)
    check root.text("summary") == "guest: notifications on, volume 40"
    r.click(root.byId("notifications"))
    check root.text("summary") == "guest: notifications off, volume 40"
    r.focus(root.byId("volume"))
    r.key(End)
    check root.text("summary") == "guest: notifications off, volume 100"
    r.click(root.byId("sounds"))
    check Checkbox(root.byId("sounds")).checked
    r.click(root.byId("reset"))
    check root.text("summary") == "guest: notifications on, volume 40"
    check not Checkbox(root.byId("sounds")).checked
    check Checkbox(root.byId("notifications")).checked

suite "shopping":
  test "Enter and Add append, empty adds nothing, Clear empties":
    let root = shoppingApp.buildUI()
    let r = newRig(root, 400, 460)
    let list = ListBox(root.byId("list"))
    check root.text("count") == "0 item(s)"
    r.click(root.byId("add"))
    check list.items.len == 0
    r.click(root.byId("draft"))
    r.typeText("milk")
    r.key(Enter)
    check list.items == @["milk"]
    check TextInput(root.byId("draft")).text == ""         # cleared by the app
    r.typeText("eggs")
    r.click(root.byId("add"))
    check list.items == @["milk", "eggs"]
    check root.text("count") == "2 item(s)"
    r.click(root.byId("clear"))
    check list.items.len == 0
    check root.text("count") == "0 item(s)"
