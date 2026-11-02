## The UI's global state has one index (rui_core ui_state.nim) and one reset:
## after `resetUi`, no popups, overlays, timers, captures or frozen pages are
## left, and the theme is the default.

import std/[unittest, options, monotimes, times]
import rui

suite "the UI's global state, and one reset":
  test "resetUi clears every piece":
    let w = newLabel(text = "x")
    let menu = newLabel(text = "menu")
    showOverlay(menu)
    openPopup(menu, menu, proc() = discard)
    capturePointer(w)
    w.repaintAfter(5.0)
    w.every(1.0, proc() = discard)
    lastInput = getMonoTime() - userIdleAfter - initDuration(seconds = 1)
    setCurrentTheme(brandTheme(aquaSpec()))
    check overlays().len == 1 and anyPopupOpen() and pointerCapture() == w
    check nextRepaint().isSome and userAway()

    resetUi()
    check overlays().len == 0
    check not anyPopupOpen()
    check pointerCapture() == nil
    check nextRepaint().isNone
    check not userAway()
    check currentTheme.name == "Default"
