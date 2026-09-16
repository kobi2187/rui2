## Theme switching
##
## Themes resolve (intent x state) through one global pointer, so switching
## is a single assignment - every widget picks the new palette up on relayout.
##
##   nim c -r -d:useGraphics examples/widgets/theming.nim
##
## Widgets carry stringIds, so tools/ui_test.sh can drive this too.

import rui
import std/[options, os]

let app = newApp("RUI2 - Theme switching", 520, 420)

proc named[T](x: T, id: string): T =
  x.stringId = id
  x

let root = newVStack(spacing = 12.0, padding = 20.0).named("root")

let current = newLabel(text = "", fontSize = 16.0).named("current")
root.addChild(current)

let samples = newVStack(spacing = 8.0).named("samples")
for (caption, intent, id) in [("Default", ThemeIntent.Default, "sDefault"),
                              ("Info", ThemeIntent.Info, "sInfo"),
                              ("Success", ThemeIntent.Success, "sSuccess"),
                              ("Warning", ThemeIntent.Warning, "sWarning"),
                              ("Danger", ThemeIntent.Danger, "sDanger")]:
  samples.addChild(newButton(text = caption, intent = intent).named(id))
root.addChild(samples)

proc showTheme(name: string) =
  app.setTheme(name)
  current.text = "Theme: " & name
  current.isDirty = true
  current.layoutDirty = true

let switcher = newHStack(spacing = 10.0).named("switcher")
for name in ["light", "dark"]:
  let themeName = name
  let b = newButton(text = "Use " & name).named("use_" & name)
  b.onClick = proc() = showTheme(themeName)
  switcher.addChild(b)
root.addChild(switcher)

showTheme("light")

app.setRootWidget(root)
let scriptDir = getAppDir() / "script"
app.enableScripting(scriptDir)
app.setScriptPollInterval(0.05)
app.start()
