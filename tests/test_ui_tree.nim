## `ui:` — building a widget tree by writing its shape
##
## Sugar over the generated constructors and nothing else, so every case here
## has an equivalent written the plain way.

import std/unittest
import rui

suite "the shape it builds":

  test "a single widget is just its constructor":
    let w = ui: Label(text = "hello", fontSize = 14.0)
    check w.getTypeName() == "Label"
    check Label(w).text == "hello"

  test "a body becomes children, in order":
    let root = ui:
      VStack(spacing = 10.0):
        Label(text = "first", fontSize = 14.0)
        Label(text = "second", fontSize = 14.0)
        Button(text = "third")

    check root.children.len == 3
    check Label(root.children[0]).text == "first"
    check Label(root.children[1]).text == "second"
    check Button(root.children[2]).text == "third"

  test "it is exactly what the plain constructors build":
    let sugared = ui:
      VStack(spacing = 10.0):
        Label(text = "hello", fontSize = 14.0)

    let plain = newVStack(spacing = 10.0)
    plain.addChild(newLabel(text = "hello", fontSize = 14.0))

    check VStack(sugared).spacing == VStack(plain).spacing
    check sugared.children.len == plain.children.len
    check Label(sugared.children[0]).text == Label(plain.children[0]).text

  test "addChild's bookkeeping still happens":
    # Sugar over addChild, not around it: the parent link and the dirty flags
    # are what hit-testing and event bubbling rely on.
    let root = ui:
      VStack():
        Label(text = "x", fontSize = 14.0)
    check root.children[0].parent == root
    check root.layoutDirty

  test "nesting goes as deep as you write it":
    let root = ui:
      VStack(spacing = 4.0):
        HStack(spacing = 2.0):
          Label(text = "a", fontSize = 14.0)
          VStack():
            Label(text = "b", fontSize = 14.0)
        Label(text = "c", fontSize = 14.0)

    check root.children.len == 2
    let row = root.children[0]
    check row.children.len == 2
    check row.children[1].children.len == 1
    check Label(row.children[1].children[0]).text == "b"

  test "a container with no arguments needs no parentheses content":
    let root = ui:
      ZStack():
        Label(text = "x", fontSize = 14.0)
    check root.children.len == 1

suite "naming a child":

  test "let names a widget for the rest of the tree":
    let root = ui:
      VStack():
        let first = Button(text = "Go")
        Label(text = first.text & " again", fontSize = 14.0)

    check root.children.len == 2
    check Label(root.children[1]).text == "Go again"

  test "assignment names it for outside the tree":
    # `ui:` is an expression, so a `let` inside it cannot escape. Declaring the
    # variable first is how a handler written after the tree reaches a widget
    # inside it -- and the assignment still adds the child.
    var go: Button
    var fired = 0
    let root = ui:
      VStack():
        go = Button(text = "Go")
        Label(text = "after", fontSize = 14.0)

    go.onClick = proc() = inc fired
    check root.children.len == 2
    check root.children[0] == Widget(go)
    go.onClick()
    check fired == 1

suite "control flow inside a body":

  test "a loop adds a child per iteration":
    let root = ui:
      VStack():
        for i in 1 .. 3:
          Button(text = "b" & $i)

    check root.children.len == 3
    check Button(root.children[2]).text == "b3"

  test "an if includes a widget conditionally":
    let showExtra = true
    let root = ui:
      VStack():
        Label(text = "always", fontSize = 14.0)
        if showExtra:
          Label(text = "sometimes", fontSize = 14.0)

    check root.children.len == 2

  test "and excludes it when false":
    let showExtra = false
    let root = ui:
      VStack():
        Label(text = "always", fontSize = 14.0)
        if showExtra:
          Label(text = "sometimes", fontSize = 14.0)

    check root.children.len == 1

  test "both branches of an if-else work":
    let useButton = false
    let root = ui:
      VStack():
        if useButton:
          Button(text = "b")
        else:
          Label(text = "l", fontSize = 14.0)

    check root.children.len == 1
    check root.children[0].getTypeName() == "Label"

  test "a loop over a seq builds a row each":
    let names = @["one", "two"]
    let root = ui:
      VStack():
        for n in names:
          HStack():
            Label(text = n, fontSize = 14.0)

    check root.children.len == 2
    check Label(root.children[1].children[0]).text == "two"

suite "statements that are not widgets":

  test "plain code passes through":
    var seen = 0
    let root = ui:
      VStack():
        Label(text = "a", fontSize = 14.0)
        inc seen
        Label(text = "b", fontSize = 14.0)

    check seen == 1
    check root.children.len == 2

  test "a lowercase call is not mistaken for a widget":
    # The capital is the whole test for "is this a widget", which is what keeps
    # `echo x` or `inc count` out of the tree.
    var log: seq[string] = @[]
    proc note(s: string) = log.add(s)
    let root = ui:
      VStack():
        note("building")
        Label(text = "a", fontSize = 14.0)

    check log == @["building"]
    check root.children.len == 1
