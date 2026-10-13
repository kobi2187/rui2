## `ui:` sugar that matches yui: spacing modifiers, `.size`, binding arrows,
## and `{name}` interpolation.

import std/unittest
import rui

suite "spacing modifiers":

  test "margin wraps the widget and later modifiers apply to the wrapper":
    let root = ui:
      Row():
        Button(text = "A").margin(8)
        Button(text = "B").margin("4px 12px").flex
    let a = root.children[0]
    check a of Padding
    check Padding(a).padding == EdgeInsets.all(8)
    check a.children[0] of Button
    let b = Padding(root.children[1])
    check b.padding == EdgeInsets.symmetric(horizontal = 12, vertical = 4)
    check b.flexGrow == 1

  test "a margin makes the box bigger by the insets":
    let plain = newButton(text = "A")
    let padded = newButton(text = "A").margin(10)
    check padded.measure(unbounded()).width ==
          plain.measure(unbounded()).width + 20

  test "bad CSS is an error, not zero":
    expect ValueError: discard newButton(text = "A").margin("lots")

  test "size is frame":
    let b = newButton(text = "A").size(120, 40)
    check b.sizeRequest == Size(width: 120, height: 40)

suite "binding: a property that reads link.value":

  test "a property reading link.value follows the link":
    let name = newLink("Ada")
    let root = ui:
      Column():
        Label(text = name.value)
    let label = Label(root.children[0])
    check label.text == "Ada"
    name.value = "Bob"
    label.onRefresh()
    check label.text == "Bob"

  test "a handler writes the widget's value back":
    let name = newLink("Ada")
    let root = ui:
      Column():
        TextInput(text = name.value, onChange = name.setter)
    let input = TextInput(root.children[0])
    check input.text == "Ada"
    input.onChange("Zed")                  # the user typed: the handler wrote it back
    check name.value == "Zed"
    name.value = "Yan"
    input.onRefresh()
    check input.text == "Yan"

  test "a checkbox writes back through onToggle":
    let on = newLink(false)
    let root = ui:
      Column():
        Checkbox(text = "x", checked = on.value, onToggle = on.setter)
    let box = Checkbox(root.children[0])
    box.onToggle(true)
    check on.value
    on.value = false
    box.onRefresh()
    check not box.checked

  test "the widget is in the Link's dependentWidgets; a handler that reads the Link is not a dependency":
    let a = newLink("x")
    let b = newLink(0)
    let root = ui:
      Column():
        Label(text = a.value & "!")
        Button(text = "go", onClick = proc () = b.value = b.value + 1)
    check Widget(root.children[0]) in a.dependentWidgets
    check b.dependentWidgets.len == 0

  test "two expressions reading the same Link register the widget once, and one Link per read":
    let first = newLink("Ada")
    let n = newLink(2)
    let root = ui:
      Column():
        Label(text = first.value & " (" & $n.value & ")")
    let label = Label(root.children[0])
    check label in first.dependentWidgets and label in n.dependentWidgets
    n.value = 3
    label.onRefresh()
    check label.text == "Ada (3)"

  test "the two-way arrows are gone, with a message saying what to write instead":
    check not compiles(ui(Column(): TextInput(text = <-> newLink(""))))

  test "an existing handler still runs":
    let name = newLink("")
    var heard = ""
    let root = ui:
      Column():
        TextInput(text = name.value, onChange = proc(s: string) = heard = s)
    TextInput(root.children[0]).onChange("hi")
    check heard == "hi"

  test "-> \"... {link} ...\" interpolates and follows every link":
    let first = newLink("Ada")
    let n = newLink(2)
    let root = ui:
      Column():
        Label(text = "Hello, " & $first.value & " (" & $n.value & ")")
    let label = Label(root.children[0])
    check label.text == "Hello, Ada (2)"
    n.value = 3
    label.onRefresh()
    check label.text == "Hello, Ada (3)"
    first.value = "Bob"
    label.onRefresh()
    check label.text == "Hello, Bob (3)"

suite "widgets yui asks for":

  test "Card pads its child by the theme":
    let card = ui:
      Card(padding = 10):
        Label(text = "x")
    let inner = card.children[0].measure(unbounded())
    check card.measure(unbounded()) ==
          Size(width: inner.width + 20, height: inner.height + 20)

  test "Badge is at least a circle":
    let one = newBadge(text = "3")
    let size = one.measure(unbounded())
    check size.width >= size.height
    check newBadge(text = "99+").measure(unbounded()).width > size.width

  test "IndexedStack shows one child and is as big as the biggest":
    let stack = ui:
      IndexedStack(index = 1):
        SizedBox(width = 30, height = 10)
        SizedBox(width = 50, height = 40)
    stack.bounds = Rect(x: 0, y: 0, width: 0, height: 0)
    stack.layoutPass()
    check stack.children[0].visible == false
    check stack.children[1].visible
    check stack.bounds.width == 50 and stack.bounds.height == 40
    IndexedStack(stack).index = 0
    stack.layoutDirty = true
    stack.layoutPass()
    check stack.children[0].visible and not stack.children[1].visible

  test "Expander hides its content and takes no room when collapsed":
    let open = ui:
      Expander(title = "More"):
        SizedBox(width = 80, height = 50)
    let shut = ui:
      Expander(title = "More", initialExpanded = false):
        SizedBox(width = 80, height = 50)
    let hOpen = open.measure(unbounded()).height
    open.bounds = Rect(x: 0, y: 0, width: 0, height: 0)
    open.layoutPass()
    shut.bounds = Rect(x: 0, y: 0, width: 0, height: 0)
    shut.layoutPass()
    check shut.children[0].visible == false
    check shut.bounds.height < open.bounds.height
    check open.bounds.height - shut.bounds.height >= 50
    discard hOpen

  test "Drawer takes its width when open and none when closed":
    let drawer = ui:
      Drawer(width = 200, initialOpen = false):
        Label(text = "Menu")
    check drawer.measure(unbounded()).width == 0
    Drawer(drawer).setOpen(true)
    inc layoutPassNumber                    # a new frame
    check drawer.measure(unbounded()).width == 200

  test "SearchInput is a one-line TextInput":
    let search = newSearchInput()
    check search.placeholder == "Search"
    check not search.multiline
