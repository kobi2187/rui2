## Theme gallery
##
## Every shipped brand theme over the same screen, laid out entirely by layout
## primitives -- no widget here sets its own position. Pick a theme from the
## dropdown at the top, or start on one:
##
##   nim c -r -d:useGraphics examples/widgets/theme_gallery.nim aurora
##
## Themes: daylight (light), midnight (dark), aurora, ocean, forest, rose,
## ember, graphite, beos (BeOS R4: bevels, square, grey) -- and at the two extremes of geometry, punch (fat, bold,
## shadowed) and hairline (thin and lean). Then popular palettes and design
## systems, translated: nord, dracula, solarized, gruvbox, catppuccin, one-dark,
## tokyo-night, material, fluent, adwaita, cupertino. Each is one
## `brandTheme(BrandSpec(...))` call -- see
## packages/rui_drawing/src/brand_themes.nim to make your own.

import rui
import std/os

let startTheme = if paramCount() >= 1: paramStr(1) else: "daylight"
let app = newApp("RUI2 - Theme gallery", 760, 740)

var names = @["daylight", "midnight", "aurora", "ocean",
              "forest", "rose", "ember", "graphite", "punch", "hairline", "beos"]
for (key, _) in popularThemes(): names.add key

var title: Label
var switcher: ComboBox
var volume: Slider
var meter: ProgressBar

let root = ui:
  VStack(spacing = 16.0, padding = 24.0):
    Row(spacing = 12.0):
      Expanded():
        title = Label(text = "", fontSize = 24.0, bold = true)
      switcher = ComboBox(items = names, initialSelectedIndex = 0)

    # A form: labels in a column as wide as the widest, inputs taking the rest.
    Table(columnWidths = @[IntrinsicColumnWidth(), FlexColumnWidth()],
          columnSpacing = 12.0, rowSpacing = 10.0):
      TableRow():
        Label(text = "Name")
        TextInput(placeholder = "Ada Lovelace")
      TableRow():
        Label(text = "Email")
        TextInput(placeholder = "ada@example.com")
      TableRow():
        Label(text = "Plan")
        ComboBox(items = @["Starter", "Team", "Enterprise"], initialSelectedIndex = 1)

    Separator()

    Row(spacing = 24.0, crossAxisAlignment = CrossAxisAlignment.start):
      VStack(spacing = 10.0):
        Checkbox(text = "Email me updates", initialChecked = true)
        Checkbox(text = "Remember this device")
        Checkbox(text = "Disabled option", disabled = true)
      RadioGroup(options = @["Monthly", "Yearly", "Lifetime"],
                 initialSelectedIndex = 1)
      Expanded():
        Column(spacing = 10.0, crossAxisAlignment = CrossAxisAlignment.stretch):
          volume = Slider(initialValue = 65.0, textLeft = "Volume")
          meter = ProgressBar(initialValue = 65.0)

    # Every intent, flowing onto as many lines as the window needs.
    Wrap(spacing = 8.0, runSpacing = 8.0):
      Button(text = "Default")
      Button(text = "Primary", intent = ThemeIntent.Info)
      Button(text = "Success", intent = ThemeIntent.Success)
      Button(text = "Warning", intent = ThemeIntent.Warning)
      Button(text = "Delete", intent = ThemeIntent.Danger)
      Button(text = "Disabled", disabled = true)

    Spacer()
    Row(mainAxisAlignment = MainAxisAlignment.end, spacing = 8.0):
      Button(text = "Cancel")
      Button(text = "Save changes", intent = ThemeIntent.Info)

proc show(name: string) =
  app.setTheme(name)
  title.text = "Theme: " & name

switcher.onSelect = proc(i: int) = show(names[i])

volume.onChange = proc(v: float32) = meter.value = float(v)

show(startTheme)
switcher.selectedIndex = max(0, names.find(startTheme))
app.setRootWidget(root)
app.run()
