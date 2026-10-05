## Pango-backed text rendering
## ===========================
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
import pango_binding

export fontDescString
export CairoAntialias, CairoSubpixelOrder, CairoHintStyle

type
  TextDir* = enum
    ## The base direction a run of text is laid out in. `tdAuto` lets Pango
    ## take it from the text's first strong character -- right for a whole
    ## paragraph, wrong for one wrapped line of it, which must keep its
    ## paragraph's direction.
    tdAuto, tdLtr, tdRtl

  TextMeasure* = object
    width*: float32
    height*: float32
    baseline*: float32
    lineCount*: int

  CursorPos* = object
    ## Caret geometry for a byte index, in pixels relative to the layout origin.
    x*, y*: float32
    height*: float32

  HitResult* = object
    index*: int      ## byte index into the text
    trailing*: int   ## 0 = leading edge of the glyph, >0 = trailing
    inside*: bool    ## false when the point fell outside the layout

  FontRenderOptions* = object
    ## Cairo font options. Carried over from the deleted `pango_helpers`, which
    ## mapped these but never got to apply them to a live context.
    antialias*: CairoAntialias
    hintStyle*: CairoHintStyle
    subpixelOrder*: CairoSubpixelOrder

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
  measureSurface: CairoSurface
  measureCtx: CairoContext
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
  cache.clear()
  cacheMemoryBytes = 0
  measureCache.clear()
  measureOld.clear()

proc fontRenderOptions*(): FontRenderOptions = renderOptions

proc ensureMeasureCtx() =
  if measureCtx.pointer.isNil:
    measureSurface = cairoImageSurfaceCreate(CairoFormatA8, 1, 1)
    measureCtx = cairoCreate(measureSurface)

proc applyFontOptions(layout: PangoLayout) =
  let opts = cairoFontOptionsCreate()
  cairoFontOptionsSetAntialias(opts, renderOptions.antialias)
  cairoFontOptionsSetHintStyle(opts, renderOptions.hintStyle)
  cairoFontOptionsSetSubpixelOrder(opts, renderOptions.subpixelOrder)
  pangoCairoContextSetFontOptions(pangoLayoutGetContext(layout), opts)
  cairoFontOptionsDestroy(opts)
  pangoLayoutContextChanged(layout)

template withLayoutDir(font: string, wrapWidth: int32, markup: bool,
                       ctx: CairoContext, content: string, dir: TextDir,
                       body: untyped) =
  ## Build a configured PangoLayout named `layout`, run `body`, then free it.
  var layout {.inject.} = pangoCairoCreateLayout(ctx)
  applyFontOptions(layout)

  let desc = pangoFontDescriptionFromString(font.cstring)
  pangoLayoutSetFontDescription(layout, desc)
  pangoFontDescriptionFree(desc)

  # Let Pango pick the base direction from the text itself, so a Hebrew or
  # Arabic string lays out right-to-left without the caller saying so --
  # unless the caller knows better (a wrapped line keeps its paragraph's).
  if dir == tdAuto:
    pangoLayoutSetAutoDir(layout, 1)
  else:
    pangoLayoutSetAutoDir(layout, 0)
    pangoContextSetBaseDir(pangoLayoutGetContext(layout),
                           (if dir == tdRtl: 1.cint else: 0.cint))
    pangoLayoutContextChanged(layout)

  if wrapWidth > 0:
    pangoLayoutSetWidth(layout, wrapWidth * PANGO_SCALE)
    pangoLayoutSetWrap(layout, PangoWrapWordChar)
  else:
    pangoLayoutSetWidth(layout, -1)
    pangoLayoutSetSingleParagraphMode(layout, 1)

  if markup:
    pangoLayoutSetMarkup(layout, content.cstring, content.len.cint)
  else:
    pangoLayoutSetText(layout, content.cstring, content.len.cint)

  body
  gObjectUnref(layout.pointer)

template withLayout(font: string, wrapWidth: int32, markup: bool,
                    ctx: CairoContext, content: string, body: untyped) =
  withLayoutDir(font, wrapWidth, markup, ctx, content, tdAuto, body)


# ---------------------------------------------------------------------------
# Measurement
# ---------------------------------------------------------------------------
proc measureUncached(text: string, font: string, wrapWidth: int32 = -1,
                     markup = false, dir = tdAuto): TextMeasure =
  ## Real text metrics from the layout engine.
  ensureMeasureCtx()

  # An empty string still occupies a line, so measure a space to get the font's
  # line height: empty labels and inputs keep their row height.
  let content = if text.len == 0: " " else: text
  withLayoutDir(font, wrapWidth, markup and text.len > 0, measureCtx, content, dir):
    var w, h: cint
    pangoLayoutGetPixelSize(layout, addr w, addr h)
    result = TextMeasure(
      width: (if text.len == 0: 0.0'f32 else: w.float32),
      height: h.float32,
      baseline: toPixels(pangoLayoutGetBaseline(layout)),
      lineCount: pangoLayoutGetLineCount(layout).int
    )

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
    result = measureUncached(text, font, wrapWidth, markup, dir)

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

type
  CharAttrs* = object
    ## Per codepoint of a string (and one more for its end).
    byteAt*: seq[int]          ## byte offset of each codepoint, then text.len
    cursorStop*: seq[bool]     ## a caret may stand before this codepoint
    backspaceChar*: seq[bool]  ## Backspace removes just the codepoint before it,
                               ## not the whole cluster (a combining mark, say)

const
  LogAttrCursorPosition = 1'u32 shl 4
  LogAttrBackspaceChar = 1'u32 shl 10

var
  attrsText: string
  attrsCache: CharAttrs

proc charAttrs*(text: string): CharAttrs =
  ## Cluster information for `text`. The last answer is kept: typing asks about
  ## the same string several times per key.
  if attrsCache.byteAt.len > 0 and attrsText == text:
    return attrsCache
  var offsets: seq[int]
  var i = 0
  while i < text.len:
    offsets.add i
    inc i
    while i < text.len and (ord(text[i]) and 0xC0) == 0x80: inc i
  offsets.add text.len
  result.byteAt = offsets
  result.cursorStop = newSeq[bool](offsets.len)
  result.backspaceChar = newSeq[bool](offsets.len)
  if text.len == 0:
    result.cursorStop[0] = true
  else:
    ensureMeasureCtx()
    withLayout("Sans 12", -1, false, measureCtx, text):
      var n: cint
      let attrs = cast[ptr UncheckedArray[uint32]](
        pangoLayoutGetLogAttrsReadonly(layout, addr n))
      for k in 0 ..< min(int(n), offsets.len):
        result.cursorStop[k] = (attrs[k] and LogAttrCursorPosition) != 0
        result.backspaceChar[k] = (attrs[k] and LogAttrBackspaceChar) != 0
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

proc moveCaretVisually*(text: string, index: int, direction: int): Option[int] =
  ## One step left (-1) or right (+1) *on screen* from byte `index`. In text that
  ## mixes directions this differs from the logical order: in Hebrew, Right
  ## moves backwards through the string. `none` when there is nowhere further to
  ## go in that direction (the end of the line on screen).
  if text.len == 0:
    return
  ensureMeasureCtx()
  withLayout("Sans 12", -1, false, measureCtx, text):
    var newIndex, newTrailing: cint
    pangoLayoutMoveCursorVisually(layout, 1, index.cint, 0, direction.cint,
                                  addr newIndex, addr newTrailing)
    if newIndex < 0 or newIndex > text.len:
      return none(int)
    var pos = int(newIndex)
    for _ in 0 ..< int(newTrailing):          # trailing = characters past the index
      inc pos
      while pos < text.len and (ord(text[pos]) and 0xC0) == 0x80: inc pos
    return some(pos)

proc softBreaks*(text, font: string, wrapWidth: int32): seq[int] =
  ## Where one paragraph (no newlines) wraps at `wrapWidth` pixels: the byte
  ## offset each visual line starts at, the first always 0. Pango breaks
  ## where the Unicode line-breaking rules allow, so Thai and CJK wrap
  ## between words and a word longer than the width is split.
  result = @[0]
  if text.len == 0 or wrapWidth <= 0:
    return
  ensureMeasureCtx()
  withLayout(font, wrapWidth, false, measureCtx, text):
    let n = pangoLayoutGetLineCount(layout)
    for i in 1 ..< n:
      let line = pangoLayoutGetLineReadonly(layout, i)
      if line != nil:
        result.add int(line.start_index)

# ---------------------------------------------------------------------------
# Cursor geometry and hit testing (for editable text)
# ---------------------------------------------------------------------------
proc cursorPosition*(text, font: string, byteIndex: int,
                     wrapWidth: int32 = -1, dir = tdAuto): CursorPos =
  ## Caret rectangle for a byte index — where to draw the insertion point.
  ensureMeasureCtx()
  withLayoutDir(font, wrapWidth, false, measureCtx, text, dir):
    var strong, weak: PangoRectangle
    pangoLayoutGetCursorPos(layout, byteIndex.cint, addr strong, addr weak)
    result = CursorPos(
      x: toPixels(strong.x),
      y: toPixels(strong.y),
      height: toPixels(strong.height)
    )

proc indexFromPosition*(text, font: string, x, y: float32,
                        wrapWidth: int32 = -1, dir = tdAuto): HitResult =
  ## Which byte index sits under a point — click-to-place-caret.
  ensureMeasureCtx()
  withLayoutDir(font, wrapWidth, false, measureCtx, text, dir):
    var index, trailing: cint
    let inside = pangoLayoutXyToIndex(layout, toPangoUnits(x), toPangoUnits(y),
                                      addr index, addr trailing)
    result = HitResult(index: index.int, trailing: trailing.int,
                       inside: inside != 0)

# ---------------------------------------------------------------------------
# Rasterisation
# ---------------------------------------------------------------------------
proc rasteriseA8(text, font: string, wrapWidth: int32,
                 m: TextMeasure, dir = tdAuto): seq[Color] =
  ## Coverage mask -> white RGBA. Colour comes from the draw tint.
  let w = max(1'i32, m.width.int32)
  let h = max(1'i32, m.height.int32)

  let surface = cairoImageSurfaceCreate(CairoFormatA8, w, h)
  let ctx = cairoCreate(surface)
  cairoSetSourceRgba(ctx, 1.0, 1.0, 1.0, 1.0)

  withLayoutDir(font, wrapWidth, false, ctx, text, dir):
    cairoMoveTo(ctx, 0.0, 0.0)
    pangoCairoShowLayout(ctx, layout)

  cairoSurfaceFlush(surface)
  let stride = cairoImageSurfaceGetStride(surface)
  let data = cairoImageSurfaceGetData(surface)

  result = newSeq[Color](w * h)
  if not data.isNil:
    for y in 0 ..< h:
      let row = y * stride
      for x in 0 ..< w:
        result[y * w + x] = Color(r: 255, g: 255, b: 255, a: data[row + x])

  cairoDestroy(ctx)
  cairoSurfaceDestroy(surface)

proc rasteriseArgb32(markupText, font: string, wrapWidth: int32,
                     m: TextMeasure): seq[Color] =
  ## Full-colour path, for Pango markup with per-run colours
  ## (`<span foreground='red'>`). Draw this with a White tint.
  let w = max(1'i32, m.width.int32)
  let h = max(1'i32, m.height.int32)

  let surface = cairoImageSurfaceCreate(CairoFormatArgb32, w, h)
  let ctx = cairoCreate(surface)
  cairoSetSourceRgba(ctx, 0.0, 0.0, 0.0, 1.0)

  withLayout(font, wrapWidth, true, ctx, markupText):
    cairoMoveTo(ctx, 0.0, 0.0)
    pangoCairoShowLayout(ctx, layout)

  cairoSurfaceFlush(surface)
  let stride = cairoImageSurfaceGetStride(surface)
  let data = cairoImageSurfaceGetData(surface)

  result = newSeq[Color](w * h)
  if not data.isNil:
    for y in 0 ..< h:
      var src = y * stride
      for x in 0 ..< w:
        # Cairo ARGB32 on a little-endian host is B,G,R,A and *premultiplied*.
        # Undo the premultiplication, or every antialiased edge comes out dark.
        let a = data[src + 3]
        var r = data[src + 2]
        var g = data[src + 1]
        var b = data[src + 0]
        if a != 0 and a != 255:
          r = uint8(min(255, r.int * 255 div a.int))
          g = uint8(min(255, g.int * 255 div a.int))
          b = uint8(min(255, b.int * 255 div a.int))
        result[y * w + x] = Color(r: r, g: g, b: b, a: a)
        src += 4

  cairoDestroy(ctx)
  cairoSurfaceDestroy(surface)

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
    cache[key].lastUsed = stdtimes.getTime()
    return addr cache[key]

  inc cacheMisses
  let m = measure(text, font, wrapWidth, markup, dir)
  let w = max(1'i32, m.width.int32)
  let h = max(1'i32, m.height.int32)

  let pixels = if markup: rasteriseArgb32(text, font, wrapWidth, m)
               else: rasteriseA8(text, font, wrapWidth, m, dir)

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

proc paragraphDir*(text: string): TextDir =
  ## The direction a paragraph is laid out in: that of its first strong
  ## character, as Pango decides it (left to right when it has none).
  if text.len == 0: tdLtr
  elif pangoFindBaseDir(text.cstring, text.len.cint) == 1: tdRtl
  else: tdLtr

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
