## Link[T] reactive binding regression tests
##
## Link is one-way: a value holds direct references to the widgets that depend
## on it, and setting it marks exactly those widgets — not the whole tree.
##
## The gap these tests pin down is that marking a widget dirty was never enough
## on its own. A Label holds a plain `string`, not a `Link[string]`, so a dirty
## Label re-rendered the text it was built with. `bindTo` installs a refresh
## hook that pulls the current value in before layout.

import std/unittest
import rui
import std/options

suite "Link: value semantics":

  test "get and set round-trip":
    let l = newLink(3)
    check l.get() == 3
    l.set(7)
    check l.get() == 7
    check l.value == 7

  test "onChange fires with old and new values":
    let l = newLink("a")
    var seenOld, seenNew: string
    l.setOnChange(proc(o, n: string) =
      seenOld = o
      seenNew = n)
    l.set("b")
    check seenOld == "a"
    check seenNew == "b"

  test "setting the same value is a no-op":
    let l = newLink(1)
    var fired = 0
    l.setOnChange(proc(o, n: int) = inc fired)
    l.set(1)
    check fired == 0
    l.set(2)
    check fired == 1

suite "Link: dependency tracking":

  test "addDependent registers, removeDependent unregisters":
    let l = newLink(0)
    let w = newLabel(text = "x", fontSize = 14.0)
    check l.dependentCount == 0
    l.addDependent(w)
    check l.dependentCount == 1
    check l.hasDependent(w)
    l.removeDependent(w)
    check l.dependentCount == 0

  test "setting marks only dependents, not the whole tree":
    let root = newVStack()
    let bound = newLabel(text = "bound", fontSize = 14.0)
    let other = newLabel(text = "other", fontSize = 14.0)
    root.addChild(bound)
    root.addChild(other)

    let l = newLink(0)
    l.addDependent(bound)

    for w in [Widget(root), Widget(bound), Widget(other)]:
      w.isDirty = false
      w.layoutDirty = false

    l.set(1)

    check bound.isDirty
    check bound.layoutDirty
    check root.isDirty          # ancestor line, so the repaint reaches screen
    check not other.isDirty     # sibling keeps its cached texture

  test "one link can drive several widgets":
    let l = newLink(0)
    let a = newLabel(text = "a", fontSize = 14.0)
    let b = newLabel(text = "b", fontSize = 14.0)
    l.addDependent(a)
    l.addDependent(b)
    a.isDirty = false
    b.isDirty = false
    l.set(5)
    check a.isDirty and b.isDirty

suite "Link: bindTo actually changes what the widget shows":

  test "binding seeds the widget immediately":
    let count = newLink(41)
    let label = newLabel(text = "placeholder", fontSize = 14.0)
    count.bindTo(label, proc(v: int) = label.text = "Count: " & $v)
    check label.text == "Count: 41"

  test "setting the link updates the widget through the layout pass":
    let root = newVStack()
    root.bounds = Rect(x: 0, y: 0, width: 200, height: 200)
    let count = newLink(0)
    let label = newLabel(text = "", fontSize = 14.0)
    root.addChild(label)
    count.bindTo(label, proc(v: int) = label.text = "Count: " & $v)

    root.layoutPass()
    check label.text == "Count: 0"

    count.set(3)
    root.layoutPass()
    check label.text == "Count: 3"

  test "a bound label re-measures when the value grows":
    # Free-standing, so the label keeps its natural width. (Inside a stack the
    # container assigns the cross-axis size, so width would not change.)
    let name = newLink("hi")
    let label = newLabel(text = "", fontSize = 16.0)
    name.bindTo(label, proc(v: string) = label.text = v)
    label.layoutPass()
    let narrow = label.bounds.width

    name.set("a considerably longer value than before")
    label.layoutPass()
    check label.bounds.width > narrow

  test "two links can drive one widget":
    let root = newVStack()
    root.bounds = Rect(x: 0, y: 0, width: 300, height: 100)
    let first = newLink("A")
    let second = newLink("B")
    let label = newLabel(text = "", fontSize = 14.0)
    root.addChild(label)

    var a, b: string
    first.bindTo(label, proc(v: string) = a = v; label.text = a & b)
    second.bindTo(label, proc(v: string) = b = v; label.text = a & b)

    root.layoutPass()
    check label.text == "AB"

    second.set("Z")
    root.layoutPass()
    check label.text == "AZ"

  test "unbind stops further updates":
    let root = newVStack()
    root.bounds = Rect(x: 0, y: 0, width: 200, height: 100)
    let l = newLink(1)
    let label = newLabel(text = "", fontSize = 14.0)
    root.addChild(label)
    l.bindTo(label, proc(v: int) = label.text = $v)
    root.layoutPass()
    check label.text == "1"

    l.unbind(label)
    l.set(2)
    # No longer a dependent, so nothing marks it dirty and layout skips it.
    root.layoutPass()
    check label.text == "1"

  test "binding a value type other than string or int":
    let root = newVStack()
    root.bounds = Rect(x: 0, y: 0, width: 300, height: 100)
    let ratio = newLink(0.25'f64)
    let bar = newProgressBar(initialValue = 0.0, maxValue = 1.0)
    root.addChild(bar)
    ratio.bindTo(bar, proc(v: float64) = bar.value = v)
    root.layoutPass()
    check bar.value == 0.25
    ratio.set(0.9)
    root.layoutPass()
    check bar.value == 0.9
