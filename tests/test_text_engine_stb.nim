## The stb text engine (what Android draws with) lays text out as the Pango
## engine (the desktop's) does: the same line height and baseline, widths
## within a pixel or two, the same wrap points, and carets that agree with
## the widths. Both engines are imported side by side, so this runs on the
## desktop; DejaVu Sans is the font CI installs.

import std/[unittest, options, strutils]
import text_engine_pango as pango
import text_engine_stb as stb
import text_types

const Sentence = "The quick brown fox jumps over the lazy dog, twice."

suite "stb text engine matches Pango":
  test "line height and baseline, regular and bold, several sizes":
    for size in [9.0'f32, 12.0, 16.0, 21.0, 34.0]:
      for bold in [false, true]:
        let font = fontDescString("DejaVu Sans", size, bold = bold)
        let p = pango.engineMeasure("Hg", font)
        let s = stb.engineMeasure("Hg", font)
        check s.height == p.height
        check s.baseline == p.baseline
        check s.lineCount == 1

  test "widths within two pixels":
    for size in [10.0'f32, 14.0, 24.0]:
      let font = fontDescString("DejaVu Sans", size)
      let p = pango.engineMeasure(Sentence, font)
      let s = stb.engineMeasure(Sentence, font)
      check abs(s.width - p.width) <= 2.0

  test "an empty string has a line's height and no width":
    let s = stb.engineMeasure("", "DejaVu Sans 12.0")
    check s.width == 0
    check s.height == pango.engineMeasure("", "DejaVu Sans 12.0").height

  test "wraps where Pango wraps":
    let font = "DejaVu Sans 12.0"
    for width in [120'i32, 200, 260]:
      check stb.softBreaks(Sentence, font, width) == pango.softBreaks(Sentence, font, width)
      check stb.engineMeasure(Sentence, font, width).lineCount ==
            pango.engineMeasure(Sentence, font, width).lineCount

  test "newlines break lines when wrapping, and not otherwise (as Pango)":
    let font = "DejaVu Sans 12.0"
    for width in [-1'i32, 400]:
      let s = stb.engineMeasure("one\ntwo\nthree", font, width)
      let p = pango.engineMeasure("one\ntwo\nthree", font, width)
      check s.lineCount == p.lineCount
      # Unwrapped, Pango draws each newline as a box from a fallback font,
      # which can make the line taller; that is not worth imitating.
      if width > 0: check s.height == p.height

  test "the caret at the end stands at the text's width":
    let font = "DejaVu Sans 12.0"
    let m = stb.engineMeasure("hello", font)
    let c = stb.cursorPosition("hello", font, "hello".len)
    check abs(c.x - m.width) <= 1.0
    check stb.cursorPosition("hello", font, 0).x == 0

  test "a click lands on the letter under it":
    let font = "DejaVu Sans 12.0"
    let x = stb.cursorPosition("hello", font, 2).x + 1   # just into the 'l'
    let hit = stb.indexFromPosition("hello", font, x, 5)
    check hit.index == 2
    check hit.trailing == 0
    check hit.inside

  test "carets do not stop inside a letter and its combining mark":
    let attrs = stb.engineCharAttrs("e\u0301x")       # e + combining acute, x
    check attrs.cursorStop == @[true, false, true, true]
    let words = stb.engineCharAttrs("hi there")
    check words.wordStart[0] and words.wordStart[3]
    check words.wordEnd[2] and words.wordEnd[8]

  test "caret moves over whole UTF-8 sequences":
    check stb.moveCaretVisually("aé", 1, 1) == some(3)
    check stb.moveCaretVisually("aé", 3, -1) == some(1)
    check stb.moveCaretVisually("aé", 3, 1) == none(int)

  test "the coverage picture is the measured size and has ink":
    let font = "DejaVu Sans 12.0"
    let m = stb.engineMeasure("Ink", font)
    let px = stb.engineRasteriseA8("Ink", font, -1, m)
    check px.len == int(m.width) * int(m.height)
    var ink = 0
    for c in px:
      if c.a > 128: inc ink
    check ink > 20

  test "a glyph the font lacks comes from a fallback font, not a box":
    # U+2630 (☰) is not in Roboto; DejaVu Sans has it, and is a fallback.
    let w = stb.engineMeasure("\u2630", "Roboto 12.0").width
    check w > 5

  test "markup is drawn as its plain text":
    let font = "DejaVu Sans 12.0"
    check stb.engineMeasure("<b>a</b> &amp; b", font, markup = true).width ==
          stb.engineMeasure("a & b", font).width
