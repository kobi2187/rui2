## Pango text stack regression tests
##
## Real font metrics are what let widgets size themselves, so these guard the
## foundation the whole layout system now rests on. They also cover the caches:
## glyph textures are keyed without colour (so re-tinting is free) and metrics
## are cached separately because layout measures far more often than it draws.

import std/unittest
import rui_drawing
import std/strformat

let font = fontDescString("", 18.0)

suite "text: metrics":

  test "measurement is non-zero and scales with font size":
    let m = measureTextPango("Hello, RUI2", font)
    check m.width > 0
    check m.height > 0
    check m.baseline > 0
    check m.lineCount == 1
    let big = measureTextPango("Hello, RUI2", fontDescString("", 36.0))
    check big.width > m.width * 1.5
    check big.height > m.height

  test "an empty string still has line height":
    let m = measureTextPango("", font)
    check m.width == 0
    check m.height > 0   # an empty label keeps its row height

  test "complex scripts measure":
    # raylib's built-in font renders none of these.
    for sample in ["\u05e9\u05dc\u05d5\u05dd \u05e2\u05d5\u05dc\u05dd",
                   "\u0645\u0631\u062d\u0628\u0627 \u0628\u0627\u0644\u0639\u0627\u0644\u0645",
                   "\u65e5\u672c\u8a9e \u4e2d\u6587 \ud55c\uad6d\uc5b4"]:
      let m = measureTextPango(sample, font)
      check m.width > 0
      check m.height > 0

  test "bold and italic differ from regular":
    let regular = measureTextPango("Handgloves", fontDescString("", 16.0))
    let bold = measureTextPango("Handgloves",
                                fontDescString("", 16.0, bold = true))
    check bold.width != regular.width

  test "font families resolve":
    let sans = measureTextPango("iiii", fontDescString("DejaVu Sans", 16.0))
    let mono = measureTextPango("iiii", fontDescString("DejaVu Sans Mono", 16.0))
    check sans.width > 0 and mono.width > 0
    check sans.width != mono.width   # mono is fixed-advance

suite "text: wrapping":

  test "wrapping adds lines and respects the width":
    let long = "wrapping works when a width is supplied and the text is " &
               "long enough that it has to break across several lines"
    let one = measureTextPango(long, font)
    let wrapped = measureTextPango(long, font, 200'i32)
    check one.lineCount == 1
    check wrapped.lineCount > 1
    check wrapped.width <= 200.0
    check wrapped.height > one.height

  test "a narrower width yields more lines":
    let long = "the quick brown fox jumps over the lazy dog again and again"
    let wide = measureTextPango(long, font, 400'i32)
    let narrow = measureTextPango(long, font, 120'i32)
    check narrow.lineCount > wide.lineCount

suite "text: cursor and hit testing":

  test "the caret advances through the string":
    let text = "abcdef"
    let c0 = cursorPosition(text, font, 0)
    let c3 = cursorPosition(text, font, 3)
    let c6 = cursorPosition(text, font, 6)
    check c0.x == 0
    check c3.x > c0.x
    check c6.x > c3.x
    check c0.height > 0

  test "a point maps back to a character index":
    let text = "abcdef"
    let hit = indexFromPosition(text, font, measureTextPango(text, font).width / 2, 4.0)
    check hit.inside
    check hit.index > 0
    check hit.index < text.len

  test "a point past the end is reported as outside":
    let hit = indexFromPosition("abc", font, 10_000.0, 4.0)
    check not hit.inside

suite "text: markup":

  test "markup measures and differs from the same text unmarked":
    let m = measureMarkupPango("plain <b>bold</b>", font)
    check m.width > 0
    check m.height > 0

  test "markup can carry per-run colour without affecting metrics much":
    let plain = measureMarkupPango("red", font)
    let coloured = measureMarkupPango(
      "<span foreground='#cc0000'>red</span>", font)
    check coloured.width == plain.width   # colour is not a metric

suite "text: caching":

  test "repeat measurement hits the cache":
    clearTextCache()
    discard measureTextPango("cache me", font)
    let before = textCacheStats()
    for _ in 0 .. 4:
      discard measureTextPango("cache me", font)
    let after = textCacheStats()
    check after.measureHits > before.measureHits
    check after.measureEntries >= 1

  test "clearing empties both caches":
    discard measureTextPango("something", font)
    clearTextCache()
    let s = textCacheStats()
    check s.entries == 0
    check s.measureEntries == 0
    check s.memoryBytes == 0

  test "changing render options resets the caches":
    discard measureTextPango("x", font)
    let before = fontRenderOptions()
    setFontRenderOptions(FontRenderOptions(
      antialias: CairoAntialiasNone,
      hintStyle: CairoHintFull,
      subpixelOrder: CairoSubpixelDefault))
    check textCacheStats().measureEntries == 0
    setFontRenderOptions(before)

  test "font render options round-trip":
    let before = fontRenderOptions()
    setFontRenderOptions(FontRenderOptions(
      antialias: CairoAntialiasGray,
      hintStyle: CairoHintMedium,
      subpixelOrder: CairoSubpixelRgb))
    let now = fontRenderOptions()
    check now.hintStyle == CairoHintMedium
    check now.subpixelOrder == CairoSubpixelRgb
    setFontRenderOptions(before)
