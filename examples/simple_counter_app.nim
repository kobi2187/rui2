## Simple Counter — canonical RUI2 example
##
## Shows the real, working API: construct widgets with `newX(...)`, assemble the
## tree with `addChild`, hold state in `Link[T]`, then run the app.
##
## (An ergonomic block-children DSL — `VStack(spacing = 10): ...` — is a roadmap
## item; see STATUS.md. Today you build the tree explicitly, and widget actions
## are `Option[proc]`, so callbacks are wrapped in `some(...)`.)

import rui
import std/[strformat, options]

# 1. Reactive state lives in Link[T]
type AppStore = object
  counter: Link[int]

var store = AppStore(counter: newLink(0))

# 2. The widget tree is an ordinary proc returning a Widget
proc buildUI(): Widget =
  let root = newVStack(spacing = 10, padding = 16)

  root.addChild(newLabel(text = "RUI2 Counter Demo", fontSize = 20))
  root.addChild(newLabel(text = &"Count: {store.counter.get()}"))

  let row = newHStack(spacing = 8)
  row.addChild(newButton(text = "-", onClick = some(proc() {.closure.} =
    store.counter.set(store.counter.get() - 1))))
  row.addChild(newButton(text = "+", onClick = some(proc() {.closure.} =
    store.counter.set(store.counter.get() + 1))))
  root.addChild(row)

  result = root

# 3. Create the app, set the root widget, run
when isMainModule:
  let app = newApp(title = "Counter", width = 400, height = 300)
  app.setRootWidget(buildUI())
  app.run()
