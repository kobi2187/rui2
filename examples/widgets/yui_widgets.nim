## The yui vocabulary in rui2: Store, binding arrows, Card, Badge, Expander,
## Drawer, IndexedStack, SearchInput, and the spacing modifiers.
##
##   nim c -r -d:useGraphics examples/widgets/yui_widgets.nim [theme]

import rui
import std/os

let app = newApp("RUI2 - yui vocabulary", 760, 460)
app.setTheme(if paramCount() >= 1: paramStr(1) else: "daylight")

let store = newStore()
let name = store.declare("name", "Ada")
let unread = store.declare("unread", 3)
let page = store.declare("page", 0)
let dark = store.declare("dark", false)

var drawer: Drawer
let root = ui:
  Row(spacing = 0.0, crossAxisAlignment = CrossAxisAlignment.stretch):
    drawer = Drawer(width = 180):
      Padding(padding = EdgeInsets.all(14.0)):
        Column(spacing = 10.0, crossAxisAlignment = CrossAxisAlignment.start):
          Label(text = "Menu", bold = true)
          Row(spacing = 8.0):
            Label(text = "Inbox")
            Badge(text = -> "{unread}")
          Label(text = "Sent")
    Expanded():
      Column(spacing = 14.0, crossAxisAlignment = CrossAxisAlignment.start).margin(20):
        Label(text = -> "Hello, {name}!", fontSize = 22.0, bold = true)
        Row(spacing = 10.0):
          Button(text = "Menu", onClick = proc() = drawer.toggle())
          SearchInput(placeholder = "Search mail").size(220, 32)
          Switch(text = "Dark", on = -> dark, onToggle = dark.setter)
        TextInput(text = -> name, onChange = name.setter).size(220, 32)
        SegmentedControl(options = @["Card", "List"], initialSelectedIndex = 0,
                         onSelect = proc(i: int) = page.value = i)
        IndexedStack(index = -> page):
          Card(padding = 16):
            Column(spacing = 6.0, crossAxisAlignment = CrossAxisAlignment.start):
              Label(text = "Storage", bold = true)
              ProgressBar(initialValue = 62.0).size(240, 14)
          Label(text = "…the list view would go here")
        Expander(title = "Advanced", initialExpanded = false):
          Checkbox(text = "Verbose logging").margin("4px 0")

app.setRootWidget(root)
app.run()
