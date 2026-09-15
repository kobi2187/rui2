## Pango-backed text rendering
## ===========================
##
## Replaces raylib's built-in bitmap font with real font rasterisation.
##
## How it works
## ------------
## Pango lays the text out and Cairo rasterises it into an **A8 (alpha-only)**
## surface — a coverage mask, with no colour of its own. That mask is uploaded
## as a white RGBA texture whose alpha is the coverage, and drawn with raylib's
## `tint` parameter supplying the colour.
##
## Doing it that way means the cache key is just *(text, font, wrap width)* —
## not the colour. The same label re-tinted for hover, disabled or theme changes
## reuses one texture instead of re-rasterising, and a theme switch costs
## nothing.
##
## Measurement goes through the same layout engine, so `measureText` finally
## returns the real advance width and line height. That is what lets containers
## size themselves to their content.

import std/[tables, hashes]
import raylib
import pango_binding

export fontDescString

type
  TextMeasure* = object
    width*: float32
    height*: float32
    baseline*: float32

  CachedGlyphs = object
    texture: Texture2D
    width, height: float32
    baseline: float32

  CacheKey = object
    text: string
    font: string
    wrapWidth: int32   ## -1 for "no wrapping"

proc hash(k: CacheKey): Hash =
  var h: Hash = 0
  h = h !& hash(k.text)
  h = h !& hash(k.font)
  h = h !& hash(k.wrapWidth)
  !$h

# ---------------------------------------------------------------------------
# Shared measurement context
# ---------------------------------------------------------------------------
# Laying text out does not need a real drawing surface, so one 1x1 surface is
# created once and reused for every measurement.

var
  measureSurface: CairoSurface
  measureCtx: CairoContext
  cache: Table[CacheKey, CachedGlyphs]
  cacheBudget = 512

proc ensureMeasureCtx() =
  if measureCtx.pointer.isNil:
    measureSurface = cairoImageSurfaceCreate(CairoFormatA8, 1, 1)
    measureCtx = cairoCreate(measureSurface)

template withLayout(font: string, wrapWidth: int32,
                    ctx: CairoContext, body: untyped) =
  ## Create a configured PangoLayout named `layout`, run `body`, then free it.
  var layout {.inject.} = pangoCairoCreateLayout(ctx)
  let desc = pangoFontDescriptionFromString(font.cstring)
  pangoLayoutSetFontDescription(layout, desc)
  pangoFontDescriptionFree(desc)
  if wrapWidth > 0:
    pangoLayoutSetWidth(layout, wrapWidth * PANGO_SCALE)
    pangoLayoutSetWrap(layout, PangoWrapWordChar)
  else:
    pangoLayoutSetWidth(layout, -1)
    pangoLayoutSetSingleParagraphMode(layout, 1)
  body
  gObjectUnref(layout.pointer)

proc measure*(text: string, font: string, wrapWidth: int32 = -1): TextMeasure =
  ## Real text metrics from the layout engine.
  if text.len == 0:
    # An empty string still occupies a line: report the font's line height so
    # empty labels and inputs keep their row height.
    ensureMeasureCtx()
    withLayout(font, -1, measureCtx):
      pangoLayoutSetText(layout, " ".cstring, 1)
      var w, h: cint
      pangoLayoutGetPixelSize(layout, addr w, addr h)
      result = TextMeasure(width: 0, height: h.float32,
                           baseline: pangoLayoutGetBaseline(layout).float32 / PANGO_SCALE)
    return

  ensureMeasureCtx()
  withLayout(font, wrapWidth, measureCtx):
    pangoLayoutSetText(layout, text.cstring, text.len.cint)
    var w, h: cint
    pangoLayoutGetPixelSize(layout, addr w, addr h)
    result = TextMeasure(
      width: w.float32,
      height: h.float32,
      baseline: pangoLayoutGetBaseline(layout).float32 / PANGO_SCALE
    )

proc rasterise(text: string, font: string, wrapWidth: int32): CachedGlyphs =
  ## Render the text to an alpha mask and upload it as a white RGBA texture.
  let m = measure(text, font, wrapWidth)
  let w = max(1'i32, m.width.int32)
  let h = max(1'i32, m.height.int32)

  let surface = cairoImageSurfaceCreate(CairoFormatA8, w, h)
  let ctx = cairoCreate(surface)

  # Opaque source: on an A8 surface the painted value *is* the coverage.
  cairoSetSourceRgba(ctx, 1.0, 1.0, 1.0, 1.0)

  withLayout(font, wrapWidth, ctx):
    pangoLayoutSetText(layout, text.cstring, text.len.cint)
    cairoMoveTo(ctx, 0.0, 0.0)
    pangoCairoShowLayout(ctx, layout)

  cairoSurfaceFlush(surface)

  let stride = cairoImageSurfaceGetStride(surface)
  let data = cairoImageSurfaceGetData(surface)

  # Expand the coverage mask into white RGBA. Alpha carries the glyph shape;
  # the colour arrives later as raylib's draw tint.
  var pixels = newSeq[Color](w * h)
  if not data.isNil:
    for y in 0 ..< h:
      let row = y * stride
      for x in 0 ..< w:
        pixels[y * w + x] = Color(r: 255, g: 255, b: 255, a: data[row + x])

  let tex = loadTextureFromData(pixels, w, h)
  # Text is drawn at its native size, so point sampling keeps the glyph edges
  # exactly as Pango rasterised them (already antialiased) instead of blurring.
  setTextureFilter(tex, TextureFilter.Point)

  result = CachedGlyphs(texture: tex, width: m.width, height: m.height,
                        baseline: m.baseline)

proc getGlyphs(text, font: string, wrapWidth: int32): ptr CachedGlyphs =
  let key = CacheKey(text: text, font: font, wrapWidth: wrapWidth)
  if key notin cache:
    if cache.len >= cacheBudget:
      # Crude but adequate: text churn is dominated by a handful of labels.
      cache.clear()
    cache[key] = rasterise(text, font, wrapWidth)
  addr cache[key]

proc drawTextPango*(text: string, x, y: float32, font: string,
                    color: Color, wrapWidth: int32 = -1) =
  ## Draw `text` with its top-left corner at (x, y).
  if text.len == 0:
    return
  let g = getGlyphs(text, font, wrapWidth)
  drawTexture(g.texture, Vector2(x: x, y: y), color)

proc measureTextPango*(text: string, font: string,
                       wrapWidth: int32 = -1): TextMeasure =
  measure(text, font, wrapWidth)

proc clearTextCache*() =
  ## Drop every cached glyph texture (the GPU memory is released by naylib's
  ## destructor as the entries go away).
  cache.clear()

proc textCacheLen*(): int = cache.len
