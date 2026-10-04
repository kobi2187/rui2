## The caret moves over, and Backspace/Delete remove, what a person calls a
## character -- a grapheme cluster -- not a codepoint.

import std/unittest
import rui
import input/text_buffer

const
  Accent = "é"                      # e + combining acute: one letter on screen
  ThumbsUp = "\u{1F44D}\u{1F3FD}"         # thumbs up + skin tone
  Family = "\u{1F468}‍\u{1F469}‍\u{1F467}"   # joined by zero-width joiners
  FlagIL = "\u{1F1EE}\u{1F1F1}"           # two regional indicators
  FlagFR = "\u{1F1EB}\u{1F1F7}"
  Shin = "שָׁ"             # Hebrew shin + dots: one letter

proc stops(text: string): seq[int] =
  ## Every caret position moving right from the start.
  var i = 0
  result.add 0
  while i < text.len:
    i = nextBoundary(text, i)
    result.add i

suite "caret stops":

  test "ASCII is one byte a step, and CRLF is one step":
    check stops("abc") == @[0, 1, 2, 3]
    check stops("a\r\nb") == @[0, 1, 3, 4]
    check prevBoundary("a\r\nb", 3) == 1

  test "a letter and its combining accent are one step":
    check Accent.len == 3
    check stops(Accent) == @[0, 3]
    check prevBoundary(Accent, 3) == 0

  test "an emoji with a skin tone is one step":
    check stops(ThumbsUp) == @[0, ThumbsUp.len]
    check prevBoundary(ThumbsUp, ThumbsUp.len) == 0

  test "a family (zero-width joiners) is one step":
    check stops(Family) == @[0, Family.len]

  test "a flag is one step; two flags are two":
    check stops(FlagIL) == @[0, FlagIL.len]
    check stops(FlagIL & FlagFR) == @[0, FlagIL.len, FlagIL.len + FlagFR.len]

  test "Hebrew letter and its points are one step":
    check stops(Shin) == @[0, Shin.len]

  test "clusters among ordinary characters":
    let text = "a" & ThumbsUp & "b"
    check stops(text) == @[0, 1, 1 + ThumbsUp.len, 2 + ThumbsUp.len]
    check prevBoundary(text, 2 + ThumbsUp.len) == 1 + ThumbsUp.len
    check prevBoundary(text, 1 + ThumbsUp.len) == 1

  test "a byte offset inside a cluster snaps to a stop, never splits it":
    let text = "a" & Family & "b"
    for inside in 2 ..< 1 + Family.len:
      check prevBoundary(text, inside) in [0, 1]
      check nextBoundary(text, inside) in [1 + Family.len, 2 + Family.len]

  test "an empty string and the ends are safe":
    check nextBoundary("", 0) == 0
    check prevBoundary("", 0) == 0
    check nextBoundary(ThumbsUp, ThumbsUp.len) == ThumbsUp.len
    check prevBoundary(ThumbsUp, 0) == 0

suite "editing by cluster":

  test "Backspace removes a whole emoji, joined or not":
    for emoji in [ThumbsUp, Family, FlagIL]:
      var b = initTextBuffer("hi" & emoji, cursor = 2 + emoji.len)
      check b.backspace()
      check b.text == "hi"
      check b.cursor == 2

  test "Delete removes a whole cluster too":
    var b = initTextBuffer(FlagFR & "x", cursor = 0)
    check b.deleteForward()
    check b.text == "x"

  test "Backspace after a Latin accent takes the whole letter, as Pango's rules say":
    var b = initTextBuffer("caf" & Accent, cursor = ("caf" & Accent).len)
    check b.backspace()
    check b.text == "caf"

  test "...but in Thai it takes only the vowel mark, leaving the consonant":
    const KoKai = "\u0E01"
    const Vowel = "\u0E34"
    var b = initTextBuffer(KoKai & Vowel, cursor = (KoKai & Vowel).len)
    check b.backspace()
    check b.text == KoKai

  test "arrow keys and shift-selection move by cluster":
    var b = initTextBuffer("a" & ThumbsUp & "b", cursor = 1)
    b.moveCursor(nextBoundary(b.text, b.cursor), extend = true)
    check b.selectedText == ThumbsUp
    b.moveCursor(0, extend = false)
    b.moveCursor(nextBoundary(b.text, 0), extend = false)
    b.moveCursor(nextBoundary(b.text, b.cursor), extend = false)
    check b.cursor == 1 + ThumbsUp.len

  test "typing a cluster, then Backspace, round-trips":
    var b = initTextBuffer("")
    check b.insert(Family)
    check b.cursor == Family.len
    check b.backspace()
    check b.text == "" and b.cursor == 0
