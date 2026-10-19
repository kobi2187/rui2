## Is the app driven by a mouse or by fingers?
##
## One global, consulted by the widgets whose behaviour differs: with a mouse a
## press selects at once and a drag does something of its own; with a finger a
## drag on a list scrolls it, so a press can only mean "select" once it is clear
## it was a tap. Widgets ask `isTouch()`; they do not detect anything themselves.
##
## It starts as desktop (touch on Android), `RUI_INPUT=touch|desktop` overrides,
## and `setInputMode` is for the app. The raylib source also switches to touch the
## first time it sees two fingers down at once -- a mouse cannot do that -- and
## `RUI_INPUT=desktop` or `setInputMode(imDesktop)` pins it back.

import std/[os, strutils]

type InputMode* = enum imDesktop, imTouch

var
  inputMode = block:
    case getEnv("RUI_INPUT").toLowerAscii
    of "touch": imTouch
    of "desktop": imDesktop
    else:
      when defined(android): imTouch else: imDesktop
  modePinned = getEnv("RUI_INPUT").len > 0

proc currentInputMode*(): InputMode = inputMode
proc isTouch*(): bool = inputMode == imTouch

proc setInputMode*(mode: InputMode) =
  ## The app's choice; automatic detection no longer changes it.
  inputMode = mode
  modePinned = true

proc noteMultiTouch*() =
  ## Two fingers were seen: this is a touch screen. Ignored once pinned.
  if not modePinned: inputMode = imTouch

proc unpinInputMode*() =
  ## Back to automatic (tests).
  modePinned = false
  inputMode = imDesktop
