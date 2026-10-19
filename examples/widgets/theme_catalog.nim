## Theme catalogue
##
## Every basic control in the states a theme has to draw -- normal, disabled,
## checked, selected, with and without text -- on one screen, so a theme can be
## judged control by control against a reference:
##
##   nim c -r -d:useGraphics examples/widgets/theme_catalog.nim [theme]
##
## The theme is `beos` unless one is named (daylight, midnight, ... see
## theme_gallery.nim for the list).

import rui
import std/os

let app = newApp("RUI2 - Theme catalogue", 1000, 760)
app.setTheme(if paramCount() >= 1: paramStr(1) else: "beos")

let root = ui:
  VStack(padding = 16.0):
    Row(spacing = 28.0, crossAxisAlignment = CrossAxisAlignment.start):
      VStack(spacing = 12.0):
        Label(text = "Buttons", bold = true)
        Button(text = "Default")
        Button(text = "Primary", intent = ThemeIntent.Info)
        Button(text = "Disabled", disabled = true)
        Label(text = "Check and radio", bold = true)
        Checkbox(text = "Checked", initialChecked = true)
        Checkbox(text = "Unchecked")
        Checkbox(text = "Disabled", disabled = true)
        RadioGroup(options = @["Monthly", "Yearly"], initialSelectedIndex = 1)
        Switch(text = "On", initialOn = true)
        Switch(text = "Off")
        Label(text = "Segmented", bold = true)
        SegmentedControl(options = @["Day", "Week", "Month"], initialSelectedIndex = 1)

      VStack(spacing = 12.0):
        Label(text = "Fields", bold = true)
        TextInput(initialText = "Ada Lovelace")
        TextInput(placeholder = "Placeholder")
        ComboBox(items = @["Starter", "Team", "Enterprise"], initialSelectedIndex = 1)
        NumberInput(initialValue = 42.0)
        Spinner(initialValue = 7.0, textLeft = "Count ")
        TextArea(initialText = "Multi-line text\nsecond line\nthird line\nfourth line\nfifth line\nsixth line\nseventh line\neighth line", placeholder = "Notes")
        Label(text = "Sliders and progress", bold = true)
        Slider(initialValue = 65.0, textLeft = "Volume")
        RangeSlider(initialLow = 20.0, initialHigh = 70.0)
        ProgressBar(initialValue = 65.0)
        ScrollBar(vertical = false, initialValue = 30.0, pageSize = 40.0)

      VStack(spacing = 12.0):
        Label(text = "Lists and tabs", bold = true)
        ListBox(items = @["Ada", "Grace", "Linus", "Margaret", "Edsger", "Barbara", "Donald", "Frances"], visibleRows = 4)
        ListView(items = @["Inbox", "Sent", "Drafts"], visibleRows = 3)
        TabControl(tabs = @["General", "Fonts", "Colors"])
        Expander(title = "Details")
        Label(text = "Labels", bold = true)
        Label(text = "Plain label")
        Hyperlink(text = "A hyperlink", url = "https://example.com")
        Separator()
        StatusBar(text = "Ready", rightText = "12 items")

let menus = newMenuBar(barHeight = 28.0)
let file = newMenu(title = "File", minWidth = 160.0)
file.addChild(newMenuItem(text = "New", shortcut = "Ctrl+N"))
file.addChild(newMenuItem(separator = true))
file.addChild(newMenuItem(text = "Quit", shortcut = "Ctrl+Q"))
menus.addChild(file)
let edit = newMenu(title = "Edit", minWidth = 160.0)
edit.addChild(newMenuItem(text = "Cut"))
edit.addChild(newMenuItem(text = "Copy"))
menus.addChild(edit)
root.addChild(menus)

app.setRootWidget(root)
app.run()
