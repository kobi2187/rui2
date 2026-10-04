## FocusScope -- a container the keyboard treats as one stop.
##
## Flutter's name for the same idea. Tab (or whatever is bound to `nextGroup`)
## moves *onto* a scope and lands on one of its widgets; the within-group keys
## (the arrows, by default) then step through its widgets, and Tab moves on to
## the next stop outside it. That is what keeps a twenty-row list, a toolbar
## or a group of radio buttons from being twenty Tab stops.
##
## ```nim
## ui:
##   Column():
##     FocusScope():
##       Button(text = "Cut")
##       Button(text = "Copy")
##       Button(text = "Paste")
##     TextInput()
## ```
##
## The child fills the scope, like Padding with no padding. Scopes nest.

import rui_core

defineWidget(FocusScope):
  init:
    widget.focusGroup = true

  layout:
    wrapChild(widget)
