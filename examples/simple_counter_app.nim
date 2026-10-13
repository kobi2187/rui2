## Simple Counter — canonical RUI2 example
##
## State is declared in a `state:` block (a `Store` and one typed `Link` per
## entry), the tree is written with `ui:`, and the label is bound to the state
## with `->`: change the Link and the label repaints. Handlers are plain closures.
## See docs/store.md.
##
## Everything `ui:` does could be written with the generated constructors and
## `addChild` — see examples/widgets/ for trees built that way. It is sugar you
## can stop using in the middle of a tree without rewriting the rest.

import rui

proc buildUI*(): Widget =
  state:
    count: int = 0

  ui:
    VStack(spacing = 10.0, padding = 16.0):
      Label(text = "RUI2 Counter Demo", fontSize = 20.0)
      Label(text = "Count: " & $count.value, fontSize = 14.0)
      HStack(spacing = 8.0):
        Button(text = "-", onClick = proc() = count.value = count.value - 1)
        Button(text = "+", onClick = proc() = count.value = count.value + 1)

when isMainModule:
  let app = newApp(title = "Counter", width = 400, height = 300)
  app.setRootWidget(buildUI())
  app.run()
