## Text rendering: the caches and drawing calls every widget uses
## ===============================================================
##
## The layout engine underneath is chosen in text_engine.nim: Pango on the
## desktop (text_engine_pango.nim), stb_truetype on Android or with
## `-d:ruiTextStb` (text_engine_stb.nim). Everything below the engine line --
## measuring through two cache generations, the colour-independent glyph
## texture cache, drawing -- is shared. The names keep "Pango" from when it was
## the only engine.
##
## Replaces raylib's built-in bitmap font with real font rasterisation.
##
## Lineage
## -------
## This merges two earlier efforts. The tree used to carry `modules/pango_text/`
## (pangowrapper / pango_helpers / text_render / text_cache), which had a sound
## design — an LRU texture cache with a memory budget, Cairo font options for
## antialiasing and hinting, and a cursor/hit-test API for editable text — but
## was never wired up: it imported a `pangolib_binding/` sibling directory that
## is not part of the repository, so none of it ran. Stage A deleted it.
##
## What survives here is that design, running against the self-contained
## `pango_binding` FFI, with three changes:
##
## 1. **Colour-independent glyph cache.** Cairo rasterises to an A8 coverage
##    mask, uploaded as a *white* RGBA texture and drawn with raylib's `tint`
##    supplying the colour. The old cache keyed on colour as well as text, so a
##    label re-tinted for hover, disabled or a theme switch re-rasterised. Here
##    the key is (text, font, wrap width) and re-tinting is free.
## 2. **No manual texture freeing.** The old cache called UnloadTexture through
##    `{.emit.}` to get at a proc naylib keeps private. Under naylib's RAII that
##    double-frees, because the Texture's own `=destroy` unloads it too.
##    Dropping the cache entry is now sufficient.
## 3. **Premultiplied alpha is undone** on the ARGB32 path. Cairo's ARGB32 is
##    premultiplied; the old `extractARGB` copied the bytes straight out, which
##    darkens every partially transparent pixel.

import std/[tables, hashes, math, unicode, options]
import std/times as stdtimes  # raylib also exports stdtimes.getTime()
import raylib
import text_types
import text_engine
import perf
import std/monotimes

export text_types
export moveCaretVisually, softBreaks, cursorPosition, indexFromPosition, paragraphDir

type
  CacheKey = object
    text: string
    font: string
    wrapWidth: int32   ## -1 for "no wrapping"
    markup: bool
    dir: TextDir

  CachedGlyphs = object
    texture: Texture2D
    width, height: float32
    baseline: float32
    lastUsed: stdtimes.Time
    memoryBytes: int

  TextureCacheStats* = object
    entries*: int
    memoryBytes*: int
    hits*, misses*: int
    measureEntries*: int
    measureHits*, measureMisses*: int

proc hash(k: CacheKey): Hash =
  var h: Hash = 0
  h = h !& hash(k.text)
  h = h !& hash(k.font)
  h = h !& hash(k.wrapWidth)
  h = h !& hash(k.markup)
  !$h

# ---------------------------------------------------------------------------
# Module state
# ---------------------------------------------------------------------------
var
  cache: Table[CacheKey, CachedGlyphs]
  cacheMemoryBytes = 0
  cacheHits, cacheMisses = 0

  # Measurement is far cheaper than rasterisation but runs far more often --
  # every widget measures itself on every layout pass -- so it gets its own
  # small cache. (The deleted text_cache.nim split these the same way; here the
  # split lives below the TextStyle layer so there is no import cycle.)
  #
  # Two generations rather than one table that is wiped when full: a layout
  # pass walks every string in the UI in the same order each time, and a
  # wipe-when-full cache is worthless against that once the UI has more
  # strings than the cap -- every lookup misses, because the entry was
  # cleared just before its turn came round again. Here a full `measureCache`
  # becomes `measureOld` (the previous contents are dropped), and a hit in the
  # old generation is promoted, so what is in use survives and only what has
  # gone untouched for a whole generation is dropped.
  measureCache: Table[CacheKey, TextMeasure]
  measureOld: Table[CacheKey, TextMeasure]
  measureHits, measureMisses = 0
  maxMeasureEntries* = 32768
    ## Per generation. About 100 bytes an entry, so a few MB at most, and a
    ## 10,000-widget UI fits comfortably.

  maxCacheEntries* = 1000
    ## Entry ceiling, matching the old text_cache default.
  maxCacheMemoryMB* = 100
    ## GPU memory ceiling for cached glyph textures, in megabytes.

  renderOptions = FontRenderOptions(
    antialias: CairoAntialiasGray,
    hintStyle: CairoHintSlight,
    subpixelOrder: CairoSubpixelDefault
  )

proc setFontRenderOptions*(opts: FontRenderOptions) =
  ## Change antialiasing / hinting. Clears both caches, since every cached
  ## texture and metric was produced under the previous settings.
  renderOptions = opts
  engineSetOptions(opts)
  cache.clear()
  cacheMemoryBytes = 0
  measureCache.clear()
  measureOld.clear()

proc fontRenderOptions*(): FontRenderOptions = renderOptions

# ---------------------------------------------------------------------------
# Measurement
# ---------------------------------------------------------------------------
proc measure*(text: string, font: string, wrapWidth: int32 = -1,
              markup = false, dir = tdAuto): TextMeasure =
  ## Cached text metrics.
  let key = CacheKey(text: text, font: font, wrapWidth: wrapWidth,
                     markup: markup, dir: dir)
  if key in measureCache:
    inc measureHits
    return measureCache[key]

  if measureOld.len > 0 and key in measureOld:
    inc measureHits
    result = measureOld[key]
  else:
    inc measureMisses
    perfCount(pcMeasureMiss)
    perfTime(phTextMeasure):
      result = engineMeasure(text, font, wrapWidth, markup, dir)

  if measureCache.len >= maxMeasureEntries:
    swap(measureOld, measureCache)     # the old generation is dropped
    measureCache.clear()
  measureCache[key] = result

# ---------------------------------------------------------------------------
# Characters, clusters and where a caret may stand
# ---------------------------------------------------------------------------
# What a person calls a character is not a codepoint: "e" + a combining accent,
# a thumbs-up + a skin-tone modifier, a family joined by zero-width joiners and
# a flag made of two regional indicators are each one thing to move over and
# delete. Pango knows the Unicode rules (UAX #29) and the per-script exceptions,
# so the editing code asks it rather than carrying tables of its own.

var
  attrsText: string
  attrsCache: CharAttrs

proc charAttrs*(text: string): CharAttrs =
  ## Cluster information for `text`. The last answer is kept: typing asks about
  ## the same string several times per key.
  if attrsCache.byteAt.len > 0 and attrsText == text:
    return attrsCache
  result = engineCharAttrs(text)
  attrsText = text
  attrsCache = result

proc hasRtl*(text: string): bool =
  ## Whether `text` has anything written right to left (Hebrew, Arabic, Syriac,
  ## Thaana and their presentation forms, or an explicit direction mark). Text
  ## without any needs no visual-order handling at all.
  var i = 0
  while i < text.len:
    let c = ord(text[i])
    if c < 0xD6:
      inc i                                    # ASCII and Latin-1: never RTL
      continue
    var r: Rune
    fastRuneAt(text, i, r)
    let cp = int(r)
    if cp in 0x0590 .. 0x08FF or cp in 0xFB1D .. 0xFDFF or cp in 0xFE70 .. 0xFEFF or
       cp in 0x200F .. 0x200F or cp in 0x202B .. 0x202E or cp in 0x2067 .. 0x2067 or
       cp in 0x10800 .. 0x10FFF or cp in 0x1E800 .. 0x1EFFF:
      return true

# ---------------------------------------------------------------------------
# LRU cache (design carried over from the deleted text_cache.nim)
# ---------------------------------------------------------------------------
proc maxCacheBytes(): int = maxCacheMemoryMB * 1024 * 1024

proc evictOldest() =
  # Iterate keys, not pairs: `pairs` yields the value by copy, and CachedGlyphs
  # holds a naylib Texture whose `=copy` is {.error.}. (This compiles under
  # `nim check` but fails a real build, so it is easy to miss.)
  var oldestKey: CacheKey
  var oldest = stdtimes.getTime()
  var found = false
  for k in cache.keys:
    let used = cache[k].lastUsed
    if not found or used < oldest:
      oldest = used
      oldestKey = k
      found = true
  if found:
    # No manual unload: dropping the entry runs naylib's destructor, which is
    # what frees the GPU texture.
    cacheMemoryBytes -= cache[oldestKey].memoryBytes
    cache.del(oldestKey)

proc evictIfNeeded(newBytes: int) =
  while cache.len > 0 and
        (cache.len >= maxCacheEntries or
         cacheMemoryBytes + newBytes > maxCacheBytes()):
    evictOldest()

proc getGlyphs(text, font: string, wrapWidth: int32,
               markup: bool, dir = tdAuto): ptr CachedGlyphs =
  let key = CacheKey(text: text, font: font, wrapWidth: wrapWidth,
                     markup: markup, dir: dir)
  if key in cache:
    inc cacheHits
    perfCount(pcTextHit)
    cache[key].lastUsed = stdtimes.getTime()
    return addr cache[key]

  inc cacheMisses
  perfCount(pcTextMiss)
  let m = measure(text, font, wrapWidth, markup, dir)
  let rasterStart = when perfOn: getMonoTime() else: default(MonoTime)
  let w = max(1'i32, m.width.int32)
  let h = max(1'i32, m.height.int32)

  let pixels = if markup: engineRasteriseArgb32(text, font, wrapWidth, m)
               else: engineRasteriseA8(text, font, wrapWidth, m, dir)

  let bytes = w.int * h.int * 4
  evictIfNeeded(bytes)

  let tex = loadTextureFromData(pixels, w, h)
  # Glyphs are drawn at their native size, so point sampling preserves the
  # edges exactly as Pango antialiased them rather than blurring them again.
  setTextureFilter(tex, TextureFilter.Point)

  cache[key] = CachedGlyphs(texture: tex, width: m.width, height: m.height,
                            baseline: m.baseline, lastUsed: stdtimes.getTime(),
                            memoryBytes: bytes)
  cacheMemoryBytes += bytes
  when perfOn: perfAdd(phTextRaster, (getMonoTime() - rasterStart).inNanoseconds)
  addr cache[key]

# ---------------------------------------------------------------------------
# Public drawing API
# ---------------------------------------------------------------------------
proc drawTextPango*(text: string, x, y: float32, font: string,
                    color: Color, wrapWidth: int32 = -1) =
  ## Draw `text` with its top-left corner at (x, y).
  ##
  ## The position is snapped to whole pixels. The glyph texture is sampled with
  ## a Point filter at 1:1 scale, so drawing it at a fractional offset makes the
  ## sampler drop or duplicate whole columns -- visible as hairline gaps through
  ## letters and a stray sliver at the edges, most obvious on centred text where
  ## the x lands on a half pixel.
  if text.len == 0:
    return
  let g = getGlyphs(text, font, wrapWidth, markup = false)
  drawTexture(g.texture, Vector2(x: round(x), y: round(y)), color)

proc drawTextPangoClipped*(text: string, x, y: float32, font: string,
                           color: Color, clip: Rectangle, dir = tdAuto) =
  ## `drawTextPango`, showing only the part that falls inside `clip`.
  ##
  ## For scrolled text. Clipping is done by source rectangle rather than
  ## scissor, for the reason drawRenderTexturePart gives: raylib's scissor
  ## computes its rectangle from the *screen* height, which is wrong inside a
  ## widget's render texture.
  if text.len == 0:
    return
  let g = getGlyphs(text, font, -1'i32, markup = false, dir)
  let dx = round(x)
  let dy = round(y)
  let left = max(dx, clip.x)
  let top = max(dy, clip.y)
  let right = min(dx + g.width, clip.x + clip.width)
  let bottom = min(dy + g.height, clip.y + clip.height)
  if right <= left or bottom <= top:
    return
  drawTexture(g.texture,
              Rectangle(x: left - dx, y: top - dy,
                        width: right - left, height: bottom - top),
              Rectangle(x: left, y: top, width: right - left, height: bottom - top),
              Vector2(x: 0, y: 0), 0.0, color)

proc drawMarkupPango*(markup: string, x, y: float32, font: string,
                      wrapWidth: int32 = -1) =
  ## Draw Pango markup — per-run colours, weights and sizes inside one string,
  ## e.g. `"plain <b>bold</b> <span foreground='#c00'>red</span>"`.
  ## Colours come from the markup, so no tint is applied.
  if markup.len == 0:
    return
  let g = getGlyphs(markup, font, wrapWidth, markup = true)
  drawTexture(g.texture, Vector2(x: round(x), y: round(y)), White)

proc measureTextPango*(text: string, font: string,
                       wrapWidth: int32 = -1, dir = tdAuto): TextMeasure =
  measure(text, font, wrapWidth, dir = dir)

proc measureMarkupPango*(markup: string, font: string,
                         wrapWidth: int32 = -1): TextMeasure =
  measure(markup, font, wrapWidth, markup = true)

proc clearTextCache*() =
  ## Drop every cached glyph texture and metric. naylib's destructors release
  ## the GPU memory as the entries go away.
  cache.clear()
  cacheMemoryBytes = 0
  measureCache.clear()
  measureOld.clear()

proc textCacheStats*(): TextureCacheStats =
  TextureCacheStats(entries: cache.len, memoryBytes: cacheMemoryBytes,
                    hits: cacheHits, misses: cacheMisses,
                    measureEntries: measureCache.len + measureOld.len,
                    measureHits: measureHits, measureMisses: measureMisses)

proc textCacheLen*(): int = cache.len
