## Editable-line semantics — caret, selection, insertion, deletion
##
## This logic lived inside TextInput's on_char and on_key_down handlers, where
## the only way to check that typing over a selection replaced it was to open a
## window and type. Three of those branches spelled out the same
## "replace the selected range" arithmetic.

import std/[unittest, unicode]
import input/text_buffer

suite "selection":

  test "a fresh buffer has no selection":
    let b = initTextBuffer("hello")
    check not b.hasSelection

  test "an empty selection is not a selection":
    # A plain click sets both ends to the caret. That must not make the next
    # keystroke delete anything.
    var b = initTextBuffer("hello")
    b.placeCursor(3)
    check b.selStart == 3
    check b.selEnd == 3
    check not b.hasSelection

  test "a backwards drag reads the same as a forwards one":
    var back = initTextBuffer("hello")
    back.placeCursor(4)
    back.dragTo(1)
    check back.selectionRange() == (1, 4)

    var fwd = initTextBuffer("hello")
    fwd.placeCursor(1)
    fwd.dragTo(4)
    check fwd.selectionRange() == (1, 4)

  test "a click without a drag leaves nothing selected":
    var b = initTextBuffer("hello")
    b.placeCursor(2)
    b.endDrag()
    check b.selStart == -1
    check not b.hasSelection

  test "a real drag survives the mouse-up":
    var b = initTextBuffer("hello")
    b.placeCursor(1)
    b.dragTo(4)
    b.endDrag()
    check b.hasSelection
    check b.selectionRange() == (1, 4)

  test "clicks are clamped to the text":
    var b = initTextBuffer("hi")
    b.placeCursor(99)
    check b.cursor == 2
    b.placeCursor(-5)
    check b.cursor == 0

suite "insertion":

  test "typing at the caret":
    var b = initTextBuffer("helo", cursor = 3)
    check b.insert("l")
    check b.text == "hello"
    check b.cursor == 4

  test "typing over a selection replaces it":
    var b = initTextBuffer("hello world")
    b.placeCursor(0)
    b.dragTo(5)
    check b.insert("bye")
    check b.text == "bye world"
    check b.cursor == 3
    check not b.hasSelection

  test "maxLength refuses the keystroke":
    var b = initTextBuffer("abcd", cursor = 4)
    check not b.insert("e", maxLength = 4)
    check b.text == "abcd"

  test "replacing a selection works even in a full field":
    # The limit is checked after the selection is removed, or you could never
    # correct a mistake at the end of a maxLength field.
    var b = initTextBuffer("abcd")
    b.placeCursor(0)
    b.dragTo(4)
    check b.insert("z", maxLength = 4)
    check b.text == "z"

  test "unlimited is the default":
    var b = initTextBuffer("abcd", cursor = 4)
    check b.insert("e")
    check b.text == "abcde"

suite "deletion":

  test "backspace takes the character before the caret":
    var b = initTextBuffer("hello", cursor = 5)
    check b.backspace()
    check b.text == "hell"
    check b.cursor == 4

  test "backspace at the start does nothing and says so":
    var b = initTextBuffer("hello", cursor = 0)
    check not b.backspace()
    check b.text == "hello"

  test "backspace over a selection takes the selection":
    var b = initTextBuffer("hello world")
    b.placeCursor(5)
    b.dragTo(11)
    check b.backspace()
    check b.text == "hello"
    check b.cursor == 5

  test "delete takes the character after the caret":
    var b = initTextBuffer("hello", cursor = 0)
    check b.deleteForward()
    check b.text == "ello"
    check b.cursor == 0

  test "delete at the end does nothing":
    var b = initTextBuffer("hello", cursor = 5)
    check not b.deleteForward()

  test "delete over a selection takes the selection":
    var b = initTextBuffer("hello world")
    b.placeCursor(0)
    b.dragTo(6)
    check b.deleteForward()
    check b.text == "world"

suite "caret movement":

  test "a plain move collapses the selection":
    var b = initTextBuffer("hello")
    b.placeCursor(0)
    b.dragTo(3)
    b.moveCursor(4, extend = false)
    check b.cursor == 4
    check not b.hasSelection

  test "shift-move extends from the existing anchor":
    # Shift-arrow twice must grow one selection, not start a new one each time.
    var b = initTextBuffer("hello", cursor = 1)
    b.moveCursor(2, extend = true)
    b.moveCursor(3, extend = true)
    check b.selectionRange() == (1, 3)

  test "shift-move backwards past the anchor still selects":
    var b = initTextBuffer("hello", cursor = 3)
    b.moveCursor(1, extend = true)
    check b.selectionRange() == (1, 3)

  test "movement is clamped to the text":
    var b = initTextBuffer("hi", cursor = 0)
    b.moveCursor(-1, extend = false)
    check b.cursor == 0
    b.moveCursor(99, extend = false)
    check b.cursor == 2

  test "select all covers the text and parks the caret at the end":
    var b = initTextBuffer("hello")
    b.selectAll()
    check b.selectionRange() == (0, 5)
    check b.cursor == 5
    check b.hasSelection

suite "UTF-8: a character is not a byte":
  ## Typing used to be printable ASCII only, because `GuiEvent.char` was one
  ## byte. With codepoints coming in, every caret step has to skip whole
  ## characters or it splits them and leaves invalid UTF-8 behind.

  test "boundaries step over multi-byte characters":
    const s = "aéש€😀b"            # 1, 2, 2, 3, 4, 1 bytes
    check nextBoundary(s, 0) == 1
    check nextBoundary(s, 1) == 3
    check nextBoundary(s, 3) == 5
    check nextBoundary(s, 5) == 8
    check nextBoundary(s, 8) == 12
    check nextBoundary(s, 12) == 13
    check nextBoundary(s, 13) == 13   # clamped at the end
    check prevBoundary(s, 13) == 12
    check prevBoundary(s, 12) == 8
    check prevBoundary(s, 8) == 5
    check prevBoundary(s, 1) == 0
    check prevBoundary(s, 0) == 0     # clamped at the start

  test "backspace takes a whole character":
    var b = initTextBuffer("héllo", cursor = 3)   # after "hé"
    check b.backspace()
    check b.text == "hllo"
    check b.cursor == 1

  test "delete takes a whole character":
    var b = initTextBuffer("a😀b", cursor = 1)
    check b.deleteForward()
    check b.text == "ab"

  test "inserting a codepoint advances past all its bytes":
    var b = initTextBuffer("ab", cursor = 1)
    check b.insert("€")
    check b.text == "a€b"
    check b.cursor == 4

  test "maxLength counts characters, not bytes":
    var b = initTextBuffer("שלו", cursor = 6)     # 3 characters, 6 bytes
    check b.insert("ם", maxLength = 4)
    check b.text == "שלום"
    check not b.insert("!", maxLength = 4)

  test "control characters are not typeable":
    check not isTypeable(Rune(0x08))    # backspace
    check not isTypeable(Rune(0x7F))    # DEL
    check not isTypeable(Rune(0x85))    # C1 next-line
    check isTypeable(Rune(ord('a')))
    check isTypeable(Rune(0x05E9))      # ש
    check isTypeable(Rune(0x1F600))     # 😀
