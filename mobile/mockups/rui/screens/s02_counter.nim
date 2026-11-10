## 02 counter -- the Flutter starter app: an app bar, a count, a FAB.
## Flutter twin: mobile/mockups/flutter/lib/screens/s02_counter.dart
import rui

proc counterScreen*(): Widget =
  state:
    count: int = 0
  ui:
    Stack(fit = StackFit.expand):
      Column(crossAxisAlignment = CrossAxisAlignment.stretch):
        AppBar(title = "Counter")
        Expanded():
          Center():
            Column(spacing = 8.0, mainAxisSize = MainAxisSize.min,
                   crossAxisAlignment = CrossAxisAlignment.center):
              Label(text = "You have pushed the button this many times:", fontSize = 14.0)
              Label(text = $count.value, fontSize = 45.0)
      Positioned(right = 16.0, bottom = 16.0):
        FloatingActionButton(icon = "+", onClick = proc() = count.value = count.value + 1)
