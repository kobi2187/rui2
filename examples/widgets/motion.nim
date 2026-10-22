## Layout that moves: the context in front, the rest out of the way.
##
## An Accordion keeps one section open: open another and the open one folds
## to its header while the sections slide into their new places. The Drawer
## slides the navigation in and out, and the content gives way. A Column with
## `.animateLayout()` eases its children whenever it reflows ("Grow" below).
##
## All of it snaps instead when the user's preferences say `motion: reduced`
## (or `off`), the same switch every animation in RUI2 listens to.
##
##   nim c -r -d:useGraphics examples/widgets/motion.nim [theme]

import rui
import std/os

let app = newApp("RUI2 - Layout motion", 760, 520)
app.setTheme(if paramCount() >= 1: paramStr(1) else: "daylight")

let mail = @["Ada: the review is in", "Grace: lunch on Thursday?",
             "Alan: about the test failures", "Linus: patch v3", "Barbara: slides"]

var drawer: Drawer
var sections: Accordion
var growing: Label
let root = ui:
  Row(spacing = 0.0, crossAxisAlignment = CrossAxisAlignment.stretch):
    drawer = Drawer(width = 170).named("drawer"):
      Column(spacing = 8.0, crossAxisAlignment = CrossAxisAlignment.start,
             padding = EdgeInsets.all(14.0)):
        Label(text = "Places", bold = true)
        Button(text = "Inbox", onClick = proc() = sections.open(0)).named("goInbox")
        Button(text = "Calendar", onClick = proc() = sections.open(1)).named("goCalendar")
        Button(text = "Notes", onClick = proc() = sections.open(2)).named("goNotes")
    Expanded():
      Column(spacing = 10.0, crossAxisAlignment = CrossAxisAlignment.stretch,
             padding = EdgeInsets.all(16.0)):
        Row(spacing = 8.0):
          Button(text = "Menu", onClick = proc() = drawer.toggle()).named("menu")
          Button(text = "Grow", onClick = proc() =
            growing.sizeRequest.height = (if growing.sizeRequest.height > 30: 24.0'f32 else: 70.0'f32)
            growing.layoutDirty = true
            growing.markDirtyToRoot()).named("grow")
        Column(spacing = 6.0, crossAxisAlignment = CrossAxisAlignment.stretch).animateLayout().named("moving"):
          growing = Label(text = "A Column with animateLayout(): the line under me moves").frame(height = 24).named("growing")
          Label(text = "...when the one above grows").named("follower")
        Expanded():
          sections = Accordion(spacing = 4.0).named("sections"):
            Expander(title = "Inbox").named("inbox"):
              ListBox(items = mail).flex().named("mail")
            Expander(title = "Calendar", initialExpanded = false).named("calendar"):
              Label(text = "Nothing today. Tomorrow: the 10:00 review.").named("today")
            Expander(title = "Notes", initialExpanded = false).named("notes"):
              TextArea(initialText = "Open a section and the others fold away.").flex().named("noteText")

app.setRootWidget(root)
# No enableScripting here: a scripted app settles every animation at once, so
# a script reads final values -- and this one is about the motion.
app.start()
