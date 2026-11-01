# The `ui:` DSL

`ui:` builds a widget tree by writing its shape. You indent the tree the way it
looks on screen:

```nim
import rui

let root = ui:
  Column(spacing = 12.0):
    Label(text = "Sign in", fontSize = 22.0, heading = true)
    TextInput(placeholder = "Email")
    Row(spacing = 8.0):
      Button(text = "Cancel")
      Button(text = "Continue", intent = ThemeIntent.Info)
```

It is only sugar. `Label(text = "x")` becomes `newLabel(text = "x")`, and an
indented block becomes `addChild` calls. Nothing else happens, so anything
written with `ui:` can be written with the constructors. You can also switch to
plain code in the middle of a tree. The macro is in
`packages/rui_core/src/ui_tree.nim`, and its tests are `tests/test_ui_tree.nim`
and `tests/test_dsl_sugar.nim`.

## Rules

1. **A capitalised call is a widget.** `Foo(args)` becomes `newFoo(args)` and is
   added to the enclosing widget. The capital letter is the whole test, so
   `echo x` or `inc count` is never taken for a widget.
2. **An indented block holds the children.** `Column(): ...` adds each widget in
   the block to the column, in order.
3. **`name = Foo(...)` keeps a handle.** It builds the widget, adds it to the
   tree, and assigns it to `name`. Declare the variable before the tree when
   code outside the tree needs it. `let name = Foo(...)` inside the tree names it
   for the rest of the tree only.
4. **Any other statement runs as written.** This covers `for`, `while`, `if`,
   `case`, `when` and `block`, and any widget built inside one goes to the same
   parent. Plain statements such as `echo` or a variable pass through.
5. **Modifiers chain.** `Canvas().frame(height = 260)` and `TextArea().flex`
   apply the modifier after the widget is built. A child block written after a
   chain belongs to the widget at the bottom of the chain:
   `VStack(spacing = 4.0).frame(width = 200):` followed by the children.

The tree must have exactly one top-level widget. `ui:` is an expression that
returns that widget.

## Keeping handles: `name =`

```nim
var email: TextInput
var go: Button

let root = ui:
  Column(spacing = 8.0):
    email = TextInput(placeholder = "Email")
    go = Button(text = "Continue", intent = ThemeIntent.Info)

go.onClick = proc() = echo "signing in ", email.text
```

A typed handle (`TextInput`, `Button`) gives you the widget's own fields:
`email.text`, `go.onClick`. If you assign a prop from outside, the widget
redraws itself. If you change one in place (`list.items.add x`), call
`markDirtyToRoot()` afterwards.

## Loops and conditions

```nim
let people = @["Ada", "Grace", "Edsger"]
let admin = true

let root = ui:
  Column(spacing = 4.0):
    for name in people:
      Label(text = name)                 # one Label per person
    if admin:
      Button(text = "Manage users")      # only when the condition holds
    else:
      Label(text = "Read only")
    case people.len
    of 0: Label(text = "Nobody yet")
    else: Label(text = $people.len & " people")
```

These run once, while the tree is built. To show a list that changes over
time, use a list widget fed by a source (see "Following data" below), rather
than rebuilding the tree.

## Modifiers

These go after the call. Each returns the widget, except `margin` and
`padding`, which return a wrapper.

| Modifier | What it does |
|---|---|
| `.frame(width = 200, height = 40)` | a fixed size on either axis (0 leaves that axis free) |
| `.size(200, 40)` | the same as `.frame` with both |
| `.flex` / `.flex(2)` | takes a share of the spare room in a Row or Column |
| `.margin(8)`, `.margin("8px 16px")` | wraps the widget in a Padding; later modifiers apply to the wrapper |
| `.padding(...)` | the same as `margin` |
| `.named("save")` | an id, for tests, scripts and `byId` |
| `.shortcut("Ctrl+S")` | a key chord that presses it, shown by the help overlay |
| `.hint("Saves the file")` | text the help overlay shows beside it |
| `.onKey(proc(k: KeyboardKey): bool = ...)` | a handler for keys the widget left unused |

```nim
let root = ui:
  Row(spacing = 8.0):
    TextInput(placeholder = "Search").flex
    Button(text = "Go").shortcut("Enter").named("search.go")
```

## Bindings: showing state

A property that reads `link.value` follows the Link. When the Link changes, the
widget evaluates the expression again and redraws:

```nim
let count = newLink(0)
let name = newLink("Ada")

let root = ui:
  Column(spacing = 8.0):
    Label(text = "Hello, " & name.value & " -- " & $count.value & " clicks")
    TextInput(text = name.value, onChange = name.setter)   # writes back
    Button(text = "+1", onClick = proc() = count.value = count.value + 1)
```

- **Reading** `x.value` in a property registers the widget with `x`. If one
  expression reads several Links, it follows all of them.
- **Writing back** goes through a handler: `onChange = name.setter`, or any
  closure. Handlers are not watched; reading a Link inside one does not bind
  anything.

## Following data: `-> source`

A list or table can follow a collection edit by edit, instead of being
rebuilt:

```nim
let todos = newLinkSeq[string]()
let root = ui:
  Column():
    ListView(items = -> todos)        # a LinkSeq: adds and removes show up
todos.add "Write docs"
```

`DataTable(rows = -> source)` does the same with a RowSource, whose rows are
fetched as they scroll into view (`examples/widgets/bigdata.nim`).

## Embed: widgets built elsewhere

`Embed(w)` puts a widget you already hold into the tree. This is for a widget
built by code before the tree, reused, or configured in ways the DSL can't
express in one call:

```nim
let table = newDataTable(columns = @[DataColumn(id: "name", title: "Name", width: 160),
                                     DataColumn(id: "team", title: "Team", width: 120)])
table.onActivate = proc(row: int) = echo "open row ", row

let tabs = newTabControl(tabs = @["Summary", "Details"])
tabs.addChild newLabel(text = "Summary page")     # one child per tab
tabs.addChild newLabel(text = "Details page")

let root = ui:
  Column(spacing = 8.0):
    Label(text = "People", heading = true)
    Embed(table).flex
    Embed(tabs)
```

`Embed(w)` is `newEmbed(w)`, which returns `w` itself, so modifiers and a child
block apply to `w`. The theme gallery builds its header's theme picker this way
(`examples/gallery/gallery_ui.nim`), as does the counter inside
`examples/shaped/skin_app.nim`.

## Your own components

A component is an ordinary proc called `newSomething` that returns a widget.
`ui:` turns `Something(...)` into a call to it, so it fits into trees like any
built-in widget, child block included:

```nim
proc newSidebar(title: string): Widget =
  result = newColumn(spacing = 6.0)
  result.addChild newLabel(text = title, heading = true)

let root = ui:
  Row():
    Sidebar(title = "Files"):        # newSidebar(title = "Files")
      Label(text = "a.txt")          # added to the column it returned
      Label(text = "b.txt")
    Label(text = "Main area").flex
```

When the component needs state, events or its own drawing, make it a widget
with `defineWidget` / `definePrimitive` instead. It then gets a `newX`
constructor the same way, with one keyword argument per prop.

## The tree as plain code

The first example, without the macro:

```nim
let root = newColumn(spacing = 12.0)
root.addChild newLabel(text = "Sign in", fontSize = 22.0, heading = true)
root.addChild newTextInput(placeholder = "Email")
let row = newRow(spacing = 8.0)
row.addChild newButton(text = "Cancel")
row.addChild newButton(text = "Continue", intent = ThemeIntent.Info)
root.addChild row
```

The two forms mix freely: a proc can build part of a tree in plain code and
hand it to `ui:` with `Embed`, or the other way round.

## Where next

- [tutorial.md](tutorial.md): three small apps built with `ui:`.
- [layout.md](layout.md): how Row, Column, Stack and friends measure and arrange.
- [store.md](store.md): Links, LinkSeqs and app state.
- [yui.md](yui.md): the same trees written as YAML files, loaded at run time.
