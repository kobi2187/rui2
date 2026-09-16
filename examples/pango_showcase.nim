## Pango text showcase
## ====================
##
## Exercises the Pango-backed text stack: real font metrics, weights and styles,
## complex-script shaping, bidirectional text, and word wrapping — alongside
## widgets that size themselves to their content.
##
##   nim c -r -d:useGraphics examples/pango_showcase.nim
##
## Every widget carries a stringId, so `tools/ui_test.sh` can drive this same
## binary through the scripting protocol.

import rui
import std/[options, os]

type ShowcaseStore = ref object of Store
  clicks: int

var store = ShowcaseStore(clicks: 0)

let app = newApp("RUI2 - Pango text showcase", 760, 740)

proc named[T](w: T, id: string): T =
  w.stringId = id
  w

# --- headings -------------------------------------------------------------
let title = newLabel(
  text = "Typography with Pango",
  fontSize = 26.0, bold = true
).named("title")

let subtitle = newLabel(
  text = "Real metrics, hinting and shaping — not a scaled bitmap font",
  fontSize = 14.0, italic = true,
  color = Color(r: 90, g: 90, b: 100, a: 255)
).named("subtitle")

# --- weights and styles ---------------------------------------------------
let regular = newLabel(text = "Regular 16 · Handgloves", fontSize = 16.0).named("regular")
let bold    = newLabel(text = "Bold 16 · Handgloves", fontSize = 16.0, bold = true).named("bold")
let italic  = newLabel(text = "Italic 16 · Handgloves", fontSize = 16.0, italic = true).named("italic")
let serif   = newLabel(text = "Serif 16 · Handgloves", fontSize = 16.0,
                       fontFamily = "DejaVu Serif").named("serif")
let mono    = newLabel(text = "Mono 16 · x = (a*b)/c;", fontSize = 16.0,
                       fontFamily = "DejaVu Sans Mono").named("mono")

# --- complex scripts ------------------------------------------------------
# Hebrew and Arabic are right-to-left and Arabic is cursive: the glyphs change
# shape depending on their neighbours. raylib's built-in font renders neither.
let hebrew = newLabel(text = "עברית · שלום עולם", fontSize = 18.0).named("hebrew")
let arabic = newLabel(text = "العربية · مرحبا بالعالم", fontSize = 18.0).named("arabic")
let cjk    = newLabel(text = "日本語 · 中文 · 한국어", fontSize = 18.0).named("cjk")
let mixed  = newLabel(text = "Mixed שלום world 你好 ligature: fi ffl",
                      fontSize = 16.0).named("mixed")

# --- markup: per-run colour and weight inside a single label --------------
let markup = newLabel(
  text = "Markup: <b>bold</b>, <i>italic</i>, " &
         "<span foreground='#c0392b'>red</span>, " &
         "<span foreground='#2980b9' size='larger'>large blue</span>, " &
         "H<sub>2</sub>O and x<sup>2</sup>",
  fontSize = 16.0, markup = true
).named("markup")

# --- wrapping -------------------------------------------------------------
let para = newLabel(
  text = "This paragraph is wrapped by Pango itself rather than by splitting " &
         "on spaces, so line breaking respects the font's real advance widths " &
         "and works for scripts that do not separate words with spaces.",
  fontSize = 14.0, wrap = true,
  color = Color(r: 60, g: 60, b: 70, a: 255)
).named("paragraph")

# --- interactive ----------------------------------------------------------
let counter = newLabel(text = "Clicks: 0", fontSize = 16.0).named("counter")

let clickButton = newButton(text = "Click me").named("clickButton")
clickButton.onClick = proc() =
  store.clicks += 1
  counter.text = "Clicks: " & $store.clicks
  counter.isDirty = true
  counter.layoutDirty = true

let quitButton = newButton(text = "Quit", intent = ThemeIntent.Danger).named("quitButton")
quitButton.onClick = proc() = app.shouldClose = true

let buttonRow = newHStack(spacing = 10.0).named("buttonRow")
buttonRow.addChild(clickButton)
buttonRow.addChild(quitButton)

let agree = newCheckbox(text = "Ligatures and kerning enabled",
                        initialChecked = true).named("agree")
let progress = newProgressBar(initialValue = 72.0, maxValue = 100.0).named("progress")

# --- assemble -------------------------------------------------------------
let root = newVStack(spacing = 9.0, padding = 22.0).named("root")
for w in [Widget(title), Widget(subtitle),
          Widget(regular), Widget(bold), Widget(italic), Widget(serif), Widget(mono),
          Widget(hebrew), Widget(arabic), Widget(cjk), Widget(mixed),
          Widget(markup),
          Widget(para),
          Widget(counter), Widget(buttonRow),
          Widget(agree), Widget(progress)]:
  root.addChild(w)

app.setRootWidget(root)
app.setStore(store)

let scriptDir = getAppDir() / "script"
app.enableScripting(scriptDir)
app.setScriptPollInterval(0.05)

app.start()
