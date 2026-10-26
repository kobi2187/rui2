## The names everyone writes bare -- a theme intent's `Info`, `Warning`,
## `Success` -- mean one thing each (issue #54). Two of rui_drawing's enums
## used to share them (AlertLevel's Info, ValidationState's Warning and
## Success), and every use then had to spell its type out or fail to compile
## as ambiguous. If a new enum brings a clash back, this file stops compiling.

import std/unittest
import rui

suite "bare enum names are unambiguous":
  test "Info, Warning, Success and Danger are the theme's intents":
    let names = [Info, Warning, Success, Danger]      # no type given: must resolve
    check names[0] is ThemeIntent
    check $names[1] == "Warning"

  test "the indicator enums keep their own, prefixed names":
    check alInfo is AlertLevel and alCritical is AlertLevel
    check vsWarning is ValidationState and vsSuccess is ValidationState
    check alertLevelFor(mbError) == alCritical
