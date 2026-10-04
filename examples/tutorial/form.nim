## Tutorial 2 -- a form: inputs, a derived value, layout.
##
##   nim c -r -d:useGraphics examples/tutorial/form.nim

import rui

# One Link per field, and a value derived from them: it recomputes whenever
# either changes, and tells its own dependents only when its answer does.
let name = newLink("")
let email = newLink("")
let valid = derive(name, email, proc(n, e: string): bool =
  n.len > 0 and '@' in e)

var nameInput, emailInput: TextInput
var submit: Button
var message: Label

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
          nameInput = TextInput(placeholder = "Ada Lovelace")
        TableRow():
          Label(text = "Email")
          emailInput = TextInput(placeholder = "ada@example.com")
        TableRow():
          Label(text = "Plan")
          ComboBox(items = @["Starter", "Team", "Enterprise"], initialSelectedIndex = 0)

      Checkbox(text = "Email me updates", initialChecked = true)

      Row(mainAxisAlignment = MainAxisAlignment.end):
        submit = Button(text = "Create account", intent = ThemeIntent.Info,
                        onClick = proc() = message.text = "Welcome, " & name.get() & "!")
      message = Label(text = "", fontSize = 14.0)

# Inputs write to their links; the button follows `valid`.
nameInput.onChange = proc(t: string) = name.set(t)
emailInput.onChange = proc(t: string) = email.set(t)
valid.bindTo(submit, proc(ok: bool) = submit.disabled = not ok)

let app = newApp("Sign up", 520, 420)
app.setRootWidget(root)
app.run()
