## Theme gallery
##
## Every shipped brand theme over the same screen, laid out entirely by layout
## primitives -- no widget here sets its own position. Pick a theme with the
## buttons along the top, or start on one:
##
##   nim c -r -d:useGraphics examples/widgets/theme_gallery.nim aurora
##
## Themes: daylight (light), midnight (dark), aurora, ocean, forest, rose,
## ember, graphite. Each is one `brandTheme(BrandSpec(...))` call -- see
## packages/rui_drawing/src/brand_themes.nim to make your own.

import rui
import std/os

let startTheme = if paramCount() >= 1: paramStr(1) else: "daylight"
let app = newApp("RUI2 - Theme gallery", 720, 620)

const brands = ["daylight", "midnight", "aurora", "ocean",
                "forest", "rose", "ember", "graphite"]

var title: Label
var switcher: Wrap
var volume: Slider
var meter: ProgressBar

let root = ui:
  VStack(spacing = 16.0, padding = 24.0):
    title = Label(text = "", fontSize = 24.0, bold = true)
    switcher = Wrap(spacing = 6.0, lineSpacing = 6.0)

    # A form: labels in a column as wide as the widest, inputs taking the rest.
    Grid(columns = @[fit(), star()], colSpacing = 12.0, rowSpacing = 10.0):
      Label(text = "Name")
      TextInput(placeholder = "Ada Lovelace")
      Label(text = "Email")
      TextInput(placeholder = "ada@example.com")
      Label(text = "Plan")
      ComboBox(items = @["Starter", "Team", "Enterprise"], initialSelectedIndex = 1)

    Separator()

    HStack(spacing = 24.0, crossAlign = CrossStart):
      VStack(spacing = 10.0):
        Checkbox(text = "Email me updates", initialChecked = true)
        Checkbox(text = "Remember this device")
        Checkbox(text = "Disabled option", disabled = true)
      RadioGroup(options = @["Monthly", "Yearly", "Lifetime"],
                 initialSelectedIndex = 1)
      VStack(spacing = 10.0).flex:
        volume = Slider(initialValue = 65.0, textLeft = "Volume")
        meter = ProgressBar(initialValue = 65.0)

    # Every intent, flowing onto as many lines as the window needs.
    Wrap(spacing = 8.0, lineSpacing = 8.0):
      Button(text = "Default")
      Button(text = "Primary", intent = ThemeIntent.Info)
      Button(text = "Success", intent = ThemeIntent.Success)
      Button(text = "Warning", intent = ThemeIntent.Warning)
      Button(text = "Delete", intent = ThemeIntent.Danger)
      Button(text = "Disabled", disabled = true)

    Spacer()
    HStack(mainAlign = MainEnd, spacing = 8.0):
      Button(text = "Cancel")
      Button(text = "Save changes", intent = ThemeIntent.Info)

proc show(name: string) =
  app.setTheme(name)
  title.text = "Theme: " & name

for brand in brands:
  let b = newButton(text = brand)
  let name = brand
  b.onClick = proc() = show(name)
  switcher.addChild(b)

volume.onChange = proc(v: float32) = meter.value = float(v)

show(startTheme)
app.setRootWidget(root)
app.run()
