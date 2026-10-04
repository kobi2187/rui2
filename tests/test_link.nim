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

suite "Link: transaction":

  test "values are visible inside, announcements wait for the end":
    let a = newLink(1)
    var fired = 0
    a.setOnChange(proc(o, n: int) = inc fired)
    transaction:
      a.set(2)
      check a.get() == 2
      check fired == 0
    check fired == 1

  test "several sets to one link announce once, from the first old value":
    let a = newLink(1)
    var seen: seq[(int, int)]
    a.setOnChange(proc(o, n: int) = seen.add (o, n))
    transaction:
      a.set(2)
      a.set(3)
      a.set(4)
    check seen == @[(1, 4)]

  test "setting a link back to where it began announces nothing":
    let a = newLink(1)
    var fired = 0
    a.setOnChange(proc(o, n: int) = inc fired)
    transaction:
      a.set(2)
      a.set(1)
    check fired == 0

  test "dependents are marked once the block closes":
    let a = newLink(0)
    let w = newLabel(text = "x", fontSize = 14.0)
    a.addDependent(w)
    w.layoutDirty = false
    transaction:
      a.set(5)
      check not w.layoutDirty
    check w.layoutDirty

  test "blocks nest, and only the outermost announces":
    let a = newLink(0)
    var fired = 0
    a.setOnChange(proc(o, n: int) = inc fired)
    transaction:
      transaction:
        a.set(1)
      check fired == 0
      a.set(2)
    check fired == 1

  test "an exception still closes the transaction":
    let a = newLink(0)
    var fired = 0
    a.setOnChange(proc(o, n: int) = inc fired)
    try:
      transaction:
        a.set(1)
        raise newException(ValueError, "boom")
    except ValueError: discard
    check fired == 1
    a.set(2)                                  # and announcing works again
    check fired == 2

suite "Link: derive":

  test "follows its source":
    let first = newLink("Ada")
    let greeting = derive(first, proc(s: string): string = "Hello, " & s)
    check greeting.get() == "Hello, Ada"
    first.set("Grace")
    check greeting.get() == "Hello, Grace"

  test "two sources, and chaining":
    let a = newLink(2)
    let b = newLink(3)
    let sum = derive(a, b, proc(x, y: int): int = x + y)
    let doubled = derive(sum, proc(x: int): int = x * 2)
    check doubled.get() == 10
    a.set(10)
    check sum.get() == 13 and doubled.get() == 26

  test "three sources":
    let a = newLink(1)
    let b = newLink(2)
    let c = newLink(3)
    let total = derive(a, b, c, proc(x, y, z: int): int = x + y + z)
    c.set(10)
    check total.get() == 13

  test "only its own dependents are dirtied, and only on a real change":
    let n = newLink(3)
    let parity = derive(n, proc(x: int): bool = x mod 2 == 1)
    let w = newLabel(text = "x", fontSize = 14.0)
    parity.addDependent(w)
    w.layoutDirty = false
    n.set(5)                                  # still odd: result unchanged
    check not w.layoutDirty
    n.set(6)
    check w.layoutDirty

  test "a transaction recomputes it once, from the final values":
    let a = newLink(1)
    let b = newLink(1)
    var runs = 0
    let sum = derive(a, b, proc(x, y: int): int =
      inc runs
      x + y)
    runs = 0
    transaction:
      a.set(5)
      b.set(7)
    check sum.get() == 12
    check runs == 2          # one per source's announcement, never a stale pair
    var seen = 0
    sum.setOnChange(proc(o, n: int) = inc seen)
    transaction:
      a.set(6)
      b.set(8)
    check seen == 1          # the derived link announced a single change
