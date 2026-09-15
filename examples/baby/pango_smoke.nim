## Smoke test for the Pango text stack: metrics, caching, cursor geometry,
## hit testing, markup, and font rendering options.

import rui_drawing
import std/strformat

let font = fontDescString("", 18.0)

block metrics:
  let m = measureTextPango("Hello, RUI2", font)
  echo &"measure       w={m.width} h={m.height} baseline={m.baseline} lines={m.lineCount}"
  let m2 = measureTextPango("Hello, RUI2", fontDescString("", 36.0))
  echo &"same at 36pt  w={m2.width} h={m2.height}"
  doAssert m2.width > m.width * 1.5, "size should scale metrics"

block bidi:
  let m = measureTextPango("שלום עולם مرحبا 你好", font)
  echo &"bidi/CJK      w={m.width} h={m.height}"
  doAssert m.width > 0

block wrapping:
  let long = "wrapping works when a width is supplied and the text is long enough to need it"
  let one = measureTextPango(long, font)
  let wrapped = measureTextPango(long, font, 200'i32)
  echo &"unwrapped     w={one.width} lines={one.lineCount}"
  echo &"wrapped@200   w={wrapped.width} lines={wrapped.lineCount}"
  doAssert wrapped.lineCount > one.lineCount

block cursor:
  let text = "abcdef"
  let c0 = cursorPosition(text, font, 0)
  let c3 = cursorPosition(text, font, 3)
  echo &"caret@0       x={c0.x} h={c0.height}"
  echo &"caret@3       x={c3.x} h={c3.height}"
  doAssert c3.x > c0.x, "caret should advance"
  doAssert c0.height > 0

block hittest:
  let text = "abcdef"
  let mid = measureTextPango(text, font).width / 2
  let hit = indexFromPosition(text, font, mid, 4.0)
  echo &"hit@mid       index={hit.index} trailing={hit.trailing} inside={hit.inside}"
  doAssert hit.inside
  doAssert hit.index > 0 and hit.index < text.len

block markup:
  let m = measureMarkupPango("plain <b>bold</b> <span foreground='#cc0000'>red</span>", font)
  echo &"markup        w={m.width} h={m.height}"
  doAssert m.width > 0

block options:
  let before = fontRenderOptions()
  setFontRenderOptions(FontRenderOptions(
    antialias: CairoAntialiasNone,
    hintStyle: CairoHintFull,
    subpixelOrder: CairoSubpixelDefault))
  let aliased = measureTextPango("Hello, RUI2", font)
  echo &"no-antialias  w={aliased.width}"
  setFontRenderOptions(before)

block cachestats:
  # setFontRenderOptions() above deliberately clears both caches, so warm the
  # measurement cache again before asserting on hit counts.
  for _ in 0 .. 2:
    discard measureTextPango("cache me", font)
  let s = textCacheStats()
  echo &"cache         glyphs={s.entries} mem={s.memoryBytes}B " &
       &"measures={s.measureEntries} hits={s.measureHits} misses={s.measureMisses}"
  doAssert s.measureHits > 0, "repeat measurements should hit the cache"

echo "all pango smoke checks passed"
