## 04 inbox -- app bar, a list of conversations, a FAB, bottom navigation.
## Flutter twin: mobile/mockups/flutter/lib/screens/s04_inbox.dart
import rui

const people = [
  ("Ada Lovelace", "Notes on the analytical engine"),
  ("Alan Turing", "Re: computable numbers"),
  ("Grace Hopper", "Found a moth in relay 70"),
  ("Edsger Dijkstra", "Goto considered harmful"),
  ("Barbara Liskov", "Substitution, revisited"),
  ("Donald Knuth", "Volume 4B is out"),
]

proc inboxScreen*(): Widget =
  ui:
    Stack(fit = StackFit.expand):
      Column(crossAxisAlignment = CrossAxisAlignment.stretch):
        AppBar(title = "Inbox", leading = "☰")
        Expanded():
          ScrollView():
            Column(crossAxisAlignment = CrossAxisAlignment.stretch):
              for (name, line) in people:
                Padding(padding = EdgeInsets.symmetric(horizontal = 16.0, vertical = 8.0)):
                  Row(spacing = 16.0, crossAxisAlignment = CrossAxisAlignment.center):
                    Avatar(name = name, size = 40.0)
                    Expanded():
                      Column(spacing = 2.0, crossAxisAlignment = CrossAxisAlignment.stretch):
                        Label(text = name, fontSize = 16.0)
                        Label(text = line, fontSize = 14.0)
        BottomNav(items = @[navItem("✉", "Mail", badge = 3), navItem("☺", "Contacts"),
                            navItem("⚙", "Settings")])
      Positioned(right = 16.0, bottom = 96.0):
        FloatingActionButton(icon = "✎")
