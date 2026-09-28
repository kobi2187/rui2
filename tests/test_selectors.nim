## Scripting selectors: addressing widgets by id, path, wildcard and type
##
## The selector language is how a test script names the widget it acts on, so
## a selector that silently matches nothing turns into a test that silently
## asserts nothing. Type segments ("Button", "form/Label") parsed for a long
## time and always came back empty; these pin down that they now match.

import std/[unittest, sequtils]
import rui
import rui_scripting

proc named(w: Widget, id: string): Widget =
  w.stringId = id
  w

proc ids(ws: seq[Widget]): seq[string] =
  for w in ws: result.add w.stringId

proc sampleTree(): Widget =
  let root = Widget(newVStack()).named("root")
  let form = Widget(newVStack()).named("form")
  form.addChild(Widget(newLabel(text = "Name")).named("nameLabel"))
  form.addChild(Widget(newButton(text = "OK")).named("ok"))
  let row = Widget(newHStack()).named("row")
  row.addChild(Widget(newButton(text = "Cancel")).named("cancel"))
  form.addChild(row)
  root.addChild(form)
  root.addChild(Widget(newLabel(text = "Status")).named("status"))
  root

suite "selectors: ids and paths":
  let root = sampleTree()

  test "a bare id is found anywhere":
    check resolvePath(root, "cancel").ids == @["cancel"]

  test "a path walks from the root":
    check resolvePath(root, "root/form/ok").ids == @["ok"]
    check resolvePath(root, "form/row/cancel").ids == @["cancel"]

  test "* is one level, ** is any depth":
    check resolvePath(root, "form/*").ids == @["nameLabel", "ok", "row"]
    check resolvePath(root, "form/**/cancel").ids == @["cancel"]

suite "selectors: type names":
  let root = sampleTree()

  test "a bare type finds every widget of that type":
    check resolvePath(root, "Button").ids == @["ok", "cancel"]

  test "a composite's own children are part of the tree":
    # A Button draws its caption with a Label child, so "Label" finds those
    # too. Scope the path when only the top-level ones are wanted.
    let labels = resolvePath(root, "Label")
    check labels.len == 4
    check labels.ids.filterIt(it.len > 0) == @["nameLabel", "status"]
    check resolvePath(root, "root/Label").ids == @["status"]

  test "a bare type includes the root when it matches":
    check resolvePath(root, "VStack").ids == @["root", "form"]

  test "a type segment in a path matches direct children only":
    check resolvePath(root, "form/Button").ids == @["ok"]
    check resolvePath(root, "form/**/Button").ids == @["ok", "cancel"]

  test "a root-level type segment consumes the root":
    check resolvePath(root, "VStack/Label").ids == @["status"]

  test "an unknown type matches nothing":
    check resolvePath(root, "Slider").len == 0
