## Simple Counter — canonical RUI2 example
##
## State lives in a `Link[T]`, the tree is written with `ui:`, handlers are
## plain closures.
##
## Everything `ui:` does could be written with the generated constructors and
## `addChild` — see examples/widgets/ for trees built that way. It is sugar you
## can stop using in the middle of a tree without rewriting the rest.

import rui
import std/strformat

# 1. Reactive state lives in Link[T]
type AppStore = object
  counter: Link[int]

var store = AppStore(counter: newLink(0))

# 2. The widget tree is an ordinary proc returning a Widget
proc buildUI(): Widget =
  # `countLabel` is declared here rather than inside the tree because the
  # binding below needs it: `ui:` is an expression, so a name introduced inside
  # it does not escape.
  var countLabel: Label

  result = ui:
    VStack(spacing = 10.0, padding = 16.0):
      Label(text = "RUI2 Counter Demo", fontSize = 20.0)
      countLabel = Label(text = "", fontSize = 14.0)
      HStack(spacing = 8.0):
        Button(text = "-", onClick = proc() =
          store.counter.set(store.counter.get() - 1))
        Button(text = "+", onClick = proc() =
          store.counter.set(store.counter.get() + 1))

  # 3. Bind the label to the link, so pressing a button repaints the count
  store.counter.bindTo(countLabel, proc(v: int) =
    countLabel.text = &"Count: {v}")

# 4. Create the app, set the root widget, run
when isMainModule:
  let app = newApp(title = "Counter", width = 400, height = 300)
  app.setRootWidget(buildUI())
  app.run()
