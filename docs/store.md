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

State flows one way: **from state to the widget**, with `->`. To get a widget's
value back into state you write the handler yourself -- `Link.setter` is the
short form of `proc (v: T) = link.value = v`:

```nim
ui:
  Column(spacing = 8.0):
    TextInput(text = -> name, onChange = name.setter)      # show name; typing writes it back
    Label(text = -> "Hello, {name}")                        # a string with {links} follows all of them
    Slider(value = -> level, onChange = level.setter)
    Checkbox(text = "On", checked = -> on, onToggle = on.setter)
    ListBox(items = -> items)                               # a Link[seq[string]] (or a LinkSeq / RowSource)
    Button(text = "Reset", onClick = proc () = name.value = "")
```

There is no two-way arrow: the write-back is an ordinary closure you can see,
and can do more in (validate, log, write two Links in a `transaction`).
`<->` and `<-` are compile errors that say so.

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
