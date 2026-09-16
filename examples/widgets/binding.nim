## Link[T] data binding
##
## One-way binding: a Link holds direct references to its dependent widgets,
## so setting it marks exactly those - not the whole tree - and each bound
## widget pulls the new value in before the next layout.
##
##   nim c -r -d:useGraphics examples/widgets/binding.nim
##
## Widgets carry stringIds, so tools/ui_test.sh can drive this too.

import rui
import std/[options, os]

let app = newApp("RUI2 - Link[T] data binding", 520, 400)

proc named[T](x: T, id: string): T =
  x.stringId = id
  x

let root = newVStack(spacing = 12.0, padding = 20.0).named("root")

let count = newLink(0)
let name = newLink("world")

# Three widgets, one link. Setting `count` updates all three.
let big = newLabel(text = "", fontSize = 28.0, bold = true).named("big")
count.bindTo(big, proc(v: int) = big.text = $v)

let words = newLabel(text = "", fontSize = 15.0).named("words")
count.bindTo(words, proc(v: int) =
  words.text = (if v == 1: "1 click" else: $v & " clicks"))

let bar = newProgressBar(initialValue = 0.0, maxValue = 20.0).named("bar")
count.bindTo(bar, proc(v: int) = bar.value = float(v))

let greeting = newLabel(text = "", fontSize = 16.0).named("greeting")
name.bindTo(greeting, proc(v: string) = greeting.text = "Hello, " & v & "!")

for w in [Widget(big), Widget(words), Widget(bar), Widget(greeting)]:
  root.addChild(w)

let row = newHStack(spacing = 10.0).named("row")
let inc = newButton(text = "Increment").named("inc")
inc.onClick = proc() = count.set(count.get() + 1)
let reset = newButton(text = "Reset").named("reset")
reset.onClick = proc() = count.set(0)
let rename = newButton(text = "Rename").named("rename")
rename.onClick = proc() =
  name.set(if name.get() == "world": "RUI2" else: "world")
for b in [inc, reset, rename]:
  row.addChild(b)
root.addChild(row)

app.setRootWidget(root)
let scriptDir = getAppDir() / "script"
app.enableScripting(scriptDir)
app.setScriptPollInterval(0.05)
app.start()
