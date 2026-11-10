## 01 hello -- one line of text and one button, centred.
## Flutter twin: mobile/mockups/flutter/lib/screens/s01_hello.dart
import rui

proc helloScreen*(): Widget =
  ui:
    Center():
      Column(spacing = 16.0, mainAxisSize = MainAxisSize.min,
             crossAxisAlignment = CrossAxisAlignment.center):
        Label(text = "Hello, RUI", fontSize = 28.0)
        Button(text = "Tap me", intent = ThemeIntent.Info)
