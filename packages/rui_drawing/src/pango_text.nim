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

import std/[tables, hashes]
import std/times as stdtimes  # raylib also exports stdtimes.getTime()
import raylib
import pango_binding

export fontDescString
export CairoAntialias, CairoSubpixelOrder, CairoHintStyle

type
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
  measureCache: Table[CacheKey, TextMeasure]
  measureHits, measureMisses = 0
  maxMeasureEntries* = 4000

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

template withLayout(font: string, wrapWidth: int32, markup: bool,
                    ctx: CairoContext, content: string, body: untyped) =
  ## Build a configured PangoLayout named `layout`, run `body`, then free it.
  var layout {.inject.} = pangoCairoCreateLayout(ctx)
  applyFontOptions(layout)

  let desc = pangoFontDescriptionFromString(font.cstring)
  pangoLayoutSetFontDescription(layout, desc)
  pangoFontDescriptionFree(desc)

  # Let Pango pick the base direction from the text itself, so a Hebrew or
  # Arabic string lays out right-to-left without the caller saying so.
  pangoLayoutSetAutoDir(layout, 1)

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

# ---------------------------------------------------------------------------
# Measurement
# ---------------------------------------------------------------------------
proc measureUncached(text: string, font: string, wrapWidth: int32 = -1,
                     markup = false): TextMeasure =
  ## Real text metrics from the layout engine.
  ensureMeasureCtx()

  # An empty string still occupies a line, so measure a space to get the font's
  # line height: empty labels and inputs keep their row height.
  let content = if text.len == 0: " " else: text
  withLayout(font, wrapWidth, markup and text.len > 0, measureCtx, content):
    var w, h: cint
    pangoLayoutGetPixelSize(layout, addr w, addr h)
    result = TextMeasure(
      width: (if text.len == 0: 0.0'f32 else: w.float32),
      height: h.float32,
      baseline: toPixels(pangoLayoutGetBaseline(layout)),
      lineCount: pangoLayoutGetLineCount(layout).int
    )

proc measure*(text: string, font: string, wrapWidth: int32 = -1,
              markup = false): TextMeasure =
  ## Cached text metrics.
  let key = CacheKey(text: text, font: font, wrapWidth: wrapWidth,
                     markup: markup)
  if key in measureCache:
    inc measureHits
    return measureCache[key]

  inc measureMisses
  result = measureUncached(text, font, wrapWidth, markup)

  if measureCache.len >= maxMeasureEntries:
    measureCache.clear()   # metrics are cheap to recompute
  measureCache[key] = result

# ---------------------------------------------------------------------------
# Cursor geometry and hit testing (for editable text)
# ---------------------------------------------------------------------------
proc cursorPosition*(text, font: string, byteIndex: int,
                     wrapWidth: int32 = -1): CursorPos =
  ## Caret rectangle for a byte index — where to draw the insertion point.
  ensureMeasureCtx()
  withLayout(font, wrapWidth, false, measureCtx, text):
    var strong, weak: PangoRectangle
    pangoLayoutGetCursorPos(layout, byteIndex.cint, addr strong, addr weak)
    result = CursorPos(
      x: toPixels(strong.x),
      y: toPixels(strong.y),
      height: toPixels(strong.height)
    )

proc indexFromPosition*(text, font: string, x, y: float32,
                        wrapWidth: int32 = -1): HitResult =
  ## Which byte index sits under a point — click-to-place-caret.
  ensureMeasureCtx()
  withLayout(font, wrapWidth, false, measureCtx, text):
    var index, trailing: cint
    let inside = pangoLayoutXyToIndex(layout, toPangoUnits(x), toPangoUnits(y),
                                      addr index, addr trailing)
    result = HitResult(index: index.int, trailing: trailing.int,
                       inside: inside != 0)

# ---------------------------------------------------------------------------
# Rasterisation
# ---------------------------------------------------------------------------
proc rasteriseA8(text, font: string, wrapWidth: int32,
                 m: TextMeasure): seq[Color] =
  ## Coverage mask -> white RGBA. Colour comes from the draw tint.
  let w = max(1'i32, m.width.int32)
  let h = max(1'i32, m.height.int32)

  let surface = cairoImageSurfaceCreate(CairoFormatA8, w, h)
  let ctx = cairoCreate(surface)
  cairoSetSourceRgba(ctx, 1.0, 1.0, 1.0, 1.0)

  withLayout(font, wrapWidth, false, ctx, text):
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
               markup: bool): ptr CachedGlyphs =
  let key = CacheKey(text: text, font: font, wrapWidth: wrapWidth,
                     markup: markup)
  if key in cache:
    inc cacheHits
    cache[key].lastUsed = stdtimes.getTime()
    return addr cache[key]

  inc cacheMisses
  let m = measure(text, font, wrapWidth, markup)
  let w = max(1'i32, m.width.int32)
  let h = max(1'i32, m.height.int32)

  let pixels = if markup: rasteriseArgb32(text, font, wrapWidth, m)
               else: rasteriseA8(text, font, wrapWidth, m)

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
  if text.len == 0:
    return
  let g = getGlyphs(text, font, wrapWidth, markup = false)
  drawTexture(g.texture, Vector2(x: x, y: y), color)

proc drawMarkupPango*(markup: string, x, y: float32, font: string,
                      wrapWidth: int32 = -1) =
  ## Draw Pango markup — per-run colours, weights and sizes inside one string,
  ## e.g. `"plain <b>bold</b> <span foreground='#c00'>red</span>"`.
  ## Colours come from the markup, so no tint is applied.
  if markup.len == 0:
    return
  let g = getGlyphs(markup, font, wrapWidth, markup = true)
  drawTexture(g.texture, Vector2(x: x, y: y), White)

proc measureTextPango*(text: string, font: string,
                       wrapWidth: int32 = -1): TextMeasure =
  measure(text, font, wrapWidth)

proc measureMarkupPango*(markup: string, font: string,
                         wrapWidth: int32 = -1): TextMeasure =
  measure(markup, font, wrapWidth, markup = true)

proc clearTextCache*() =
  ## Drop every cached glyph texture and metric. naylib's destructors release
  ## the GPU memory as the entries go away.
  cache.clear()
  cacheMemoryBytes = 0
  measureCache.clear()

proc textCacheStats*(): TextureCacheStats =
  TextureCacheStats(entries: cache.len, memoryBytes: cacheMemoryBytes,
                    hits: cacheHits, misses: cacheMisses,
                    measureEntries: measureCache.len,
                    measureHits: measureHits, measureMisses: measureMisses)

proc textCacheLen*(): int = cache.len
