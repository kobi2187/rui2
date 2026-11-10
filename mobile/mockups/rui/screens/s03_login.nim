## 03 login -- a form: two fields, a checkbox, a full-width button, a link.
## Flutter twin: mobile/mockups/flutter/lib/screens/s03_login.dart
import rui

proc loginScreen*(): Widget =
  ui:
    Column(crossAxisAlignment = CrossAxisAlignment.stretch):
      AppBar(title = "Sign in")
      Padding(padding = EdgeInsets.all(24.0)):
        Column(spacing = 16.0, crossAxisAlignment = CrossAxisAlignment.stretch):
          Label(text = "Welcome back", fontSize = 24.0)
          TextInput(placeholder = "Email")
          PasswordInput(placeholder = "Password")
          Checkbox(text = "Remember me", initialChecked = true)
          Button(text = "Sign in", intent = ThemeIntent.Info)
          Center():
            Hyperlink(text = "Forgot password?")
