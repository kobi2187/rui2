# State: `Link` and `Store`

Widgets show values; something has to own them. rui2 has two small pieces:

- **`Link[T]`** -- one value in a variable. Whoever is bound to it is told when
  it changes, and only then.
- **`Store`** -- a bag of Links addressed *by name*. Use it when the widgets are
  described by data (a `.yui` file, a settings page) and cannot name your Nim
  variables, or when many parts of the program share state.

Both live in `rui_core` (`link.nim`, `store.nim`) and are exported by `rui`.
`examples/gallery/gallery_ui.nim` uses a Store throughout.

## Link

```nim
let count = newLink(0)
count.value = count.value + 1                  # everything bound repaints

transaction:                                   # several writes, one notification
  count.value = 10
  name.value = "Ada"
```

`setOnChange(proc (old, new))` is the escape hatch for side effects.

**Things that depend on a value are updated by the handler that changes it.**
A temperature slider's handler sets the Celsius Link *and* the text Link that
shows both scales; there is no computed-value machinery to learn. A `proc
refresh()` that rewrites the dependent Links, called from each handler, is the
whole pattern -- see `examples/state/settings.nim`.

## Declaring state: `state:`

The usual way to write it:

```nim
state:
  count: int = 0
  name: string = ""
  volume = 0.5                  # the type is the value's: float
```

declares `store` (a `Store`) and the Links `count`, `name`, `volume`, each also
reachable by name (`store.get[:int]("count")`). `state(app):` calls the Store
`app`. It works anywhere a `let` does -- the top of a proc, or a module. The
canonical example is `examples/simple_counter_app.nim`.

## Store, spelled out

```nim
let store = newStore()
let name  = store.declare("name", "")          # a Link[string]
let count = store.declare("count", 0)

store.set("count", 3)                          # by name
echo store.get[:int]("count")                   # reading as the wrong type raises StoreError
echo store.format("Hello, {name} ({count})")   # fill {names} once
let greeting = store.interpolated("Hello, {name}")   # or a live Link[string]
```

The entries *are* Links, so everything above applies to them. `getText` /
`setText` read and write scalars as text without knowing their type (what a
loader needs); `names()` lists what is declared, in order; declaring a name twice
is an error. A name is a flat string: `settings.apiKey` is just a name that
contains a dot.

## Binding in `ui:`

A property that reads `link.value` follows it. That is all there is to it:

```nim
ui:
  Column(spacing = 8.0):
    TextInput(text = name.value, onChange = name.setter)    # shows name; typing writes it back
    Label(text = "Hello, " & name.value)                    # any Nim expression
    Slider(value = level.value, onChange = level.setter)
    Checkbox(text = "On", checked = on.value, onToggle = on.setter)
    ListBox(items = items.value)                            # a Link[seq[string]]
    Button(text = "Reset", onClick = proc () = name.value = "")
```

How it works: `ui:` finds the `x.value` reads in a property's expression (not in
closures) and puts the widget in each such Link's `dependentWidgets` set. Setting
`link.value = v` marks exactly those widgets dirty, and before their next layout
they re-evaluate the expression and assign the property. A handler such as
`onClick = proc () = count.value = count.value + 1` is a closure, so it is not
watched: it reads and writes Links when it runs.

State flows one way, into widgets. Writing a widget's value back is a handler you
write (`Link.setter` is the short form of `proc (v: T) = link.value = v`), so you
can see it and do more in it. `<->`, `<-` and `->` on a plain value are compile
errors that say so. The one arrow left is for big lists:
`ListView(items = -> source)` follows a `LinkSeq` or `RowSource` edit by edit
(see [sources.md](sources.md)).

## From a file

A `.yui` file's `state:` block becomes a Store; `loadYui(path, store, actions)`
declares what the file declares and binds its widgets to it (see
[yui.md](yui.md)). Your code reads and writes the same names:

```nim
let doc = loadYui("app.yui", store, actions)
store.set("count", 3)                                # the widgets follow
```

## Lists

For lists of rows use `LinkSeq[T]` (insert/remove/move notifications; a selection,
the focus and the scroll position follow edits) or a `RowSource` for big data --
see [sources.md](sources.md).

Tests: `tests/test_link.nim`, `tests/test_store.nim`, `tests/test_link_seq.nim`.
