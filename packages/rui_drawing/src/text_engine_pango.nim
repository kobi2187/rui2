## The Pango text engine: layout, metrics, caret geometry and rasterisation
## through Pango and Cairo. The desktop default; pango_text.nim holds the
## caches and drawing every engine shares, and text_engine.nim picks this one
## or text_engine_stb.nim.

import std/[unicode, options]
import raylib
import pango_binding

var
  measureSurface: CairoSurface
  measureCtx: CairoContext
  renderOptions = FontRenderOptions(antialias: CairoAntialiasGray,
                                    hintStyle: CairoHintSlight,
                                    subpixelOrder: CairoSubpixelDefault)

const engineName* = "pango"

proc engineSetOptions*(opts: FontRenderOptions) =
  renderOptions = opts

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

proc engineMeasure*(text: string, font: string, wrapWidth: int32 = -1,
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

const
  LogAttrCursorPosition = 1'u32 shl 4
  LogAttrWordStart = 1'u32 shl 5
  LogAttrWordEnd = 1'u32 shl 6
  LogAttrBackspaceChar = 1'u32 shl 10

proc engineCharAttrs*(text: string): CharAttrs =
  ## Cluster information for `text`, by the Unicode rules Pango implements.
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
  result.wordStart = newSeq[bool](offsets.len)
  result.wordEnd = newSeq[bool](offsets.len)
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
        result.wordStart[k] = (attrs[k] and LogAttrWordStart) != 0
        result.wordEnd[k] = (attrs[k] and LogAttrWordEnd) != 0

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
proc engineRasteriseA8*(text, font: string, wrapWidth: int32,
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

proc engineRasteriseArgb32*(markupText, font: string, wrapWidth: int32,
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

proc paragraphDir*(text: string): TextDir =
  ## The direction a paragraph is laid out in: that of its first strong
  ## character, as Pango decides it (left to right when it has none).
  if text.len == 0: tdLtr
  elif pangoFindBaseDir(text.cstring, text.len.cint) == 1: tdRtl
  else: tdLtr
