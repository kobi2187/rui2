## Tutorial 2 -- a form: state, handlers, layout.
##
##   nim c -r -d:useGraphics examples/tutorial/form.nim

import rui

# The form's state, declared in one block. Typing writes it; the widgets show it.
state:
  name: string = ""
  email: string = ""
  incomplete: bool = true       # the button is disabled while this is true
  welcome: string = ""

proc validate() =
  incomplete.value = not (name.value.len > 0 and '@' in email.value)

let root = ui:
  Padding(padding = EdgeInsets.all(24.0)):
    Column(spacing = 12.0, crossAxisAlignment = CrossAxisAlignment.stretch):
      Label(text = "Sign up", fontSize = 24.0, bold = true)

      # A Table sizes its first column to its labels and gives the rest to the
      # inputs -- the usual form layout, with no widths written down.
      Table(columnWidths = @[IntrinsicColumnWidth(), FlexColumnWidth()],
            columnSpacing = 12.0, rowSpacing = 10.0):
        TableRow():
          Label(text = "Name")
          TextInput(placeholder = "Ada Lovelace", text = -> name,
                    onChange = proc(t: string) =
                      name.value = t
                      validate())
        TableRow():
          Label(text = "Email")
          TextInput(placeholder = "ada@example.com", text = -> email,
                    onChange = proc(t: string) =
                      email.value = t
                      validate())
        TableRow():
          Label(text = "Plan")
          ComboBox(items = @["Starter", "Team", "Enterprise"], initialSelectedIndex = 0)

      Checkbox(text = "Email me updates", initialChecked = true)

      Row(mainAxisAlignment = MainAxisAlignment.end):
        Button(text = "Create account", intent = ThemeIntent.Info,
               disabled = -> incomplete,
               onClick = proc() = welcome.value = "Welcome, " & name.value & "!")
      Label(text = -> welcome, fontSize = 14.0)

let app = newApp("Sign up", 520, 420)
app.setRootWidget(root)
app.run()
