## The examples in docs/ui_dsl.md, compiled and checked, so the guide cannot
## drift from what `ui:` does.

import std/unittest
import rui

proc newSidebar(title: string): Widget =
  result = newColumn(spacing = 6.0)
  result.addChild newLabel(text = title, heading = true)

suite "docs/ui_dsl.md":
  test "the first tree, and the same tree as plain code":
    let root = ui:
      Column(spacing = 12.0):
        Label(text = "Sign in", fontSize = 22.0, heading = true)
        TextInput(placeholder = "Email")
        Row(spacing = 8.0):
          Button(text = "Cancel")
          Button(text = "Continue", intent = ThemeIntent.Info)
    check root.children.len == 3
    check root.children[2].children.len == 2
    check Label(root.children[0]).heading

  test "name = keeps a handle":
    var email: TextInput
    var go: Button
    let root = ui:
      Column(spacing = 8.0):
        email = TextInput(placeholder = "Email")
        go = Button(text = "Continue", intent = ThemeIntent.Info)
    check root.children[0] == email and root.children[1] == go

  test "loops and conditions":
    let people = @["Ada", "Grace", "Edsger"]
    let admin = true
    let root = ui:
      Column(spacing = 4.0):
        for name in people:
          Label(text = name)
        if admin:
          Button(text = "Manage users")
        else:
          Label(text = "Read only")
        case people.len
        of 0: Label(text = "Nobody yet")
        else: Label(text = $people.len & " people")
    check root.children.len == 5
    check Label(root.children[4]).text == "3 people"

  test "modifiers":
    let root = ui:
      Row(spacing = 8.0):
        TextInput(placeholder = "Search").flex
        Button(text = "Go").shortcut("Enter").named("search.go")
    check root.children[1].stringId == "search.go"

  test "bindings follow their links":
    let count = newLink(0)
    let name = newLink("Ada")
    let root = ui:
      Column(spacing = 8.0):
        Label(text = "Hello, " & name.value & " -- " & $count.value & " clicks")
        TextInput(text = name.value, onChange = name.setter)
        Button(text = "+1", onClick = proc() = count.value = count.value + 1)
    let label = Label(root.children[0])
    check label.text == "Hello, Ada -- 0 clicks"
    Button(root.children[2]).onClick()
    label.onRefresh()
    check label.text == "Hello, Ada -- 1 clicks"

  test "-> follows a LinkSeq":
    let todos = newLinkSeq[string]()
    let root = ui:
      Column():
        ListView(items = -> todos)
    todos.add "Write docs"
    check root.children.len == 1

  test "Embed puts a widget built elsewhere into the tree":
    let table = newDataTable(columns = @[DataColumn(id: "name", title: "Name", width: 160),
                                         DataColumn(id: "team", title: "Team", width: 120)])
    table.onActivate = proc(row: int) = echo "open row ", row
    let tabs = newTabControl(tabs = @["Summary", "Details"])
    tabs.addChild newLabel(text = "Summary page")
    tabs.addChild newLabel(text = "Details page")
    let root = ui:
      Column(spacing = 8.0):
        Label(text = "People", heading = true)
        Embed(table).flex
        Embed(tabs)
    check root.children[1] == table and root.children[2] == tabs

  test "a component of your own is a newX proc, child block included":
    let root = ui:
      Row():
        Sidebar(title = "Files"):
          Label(text = "a.txt")
          Label(text = "b.txt")
        Label(text = "Main area").flex
    check root.children[0].children.len == 3     # its title, then the two files
