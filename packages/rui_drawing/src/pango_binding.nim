## Minimal Pango / PangoCairo / Cairo binding
## ==========================================
##
## RUI2's text code referenced a `pangolib_binding/` directory that is not in
## the repository, so the Pango path was dead and every widget fell back to
## raylib's built-in 10-pixel bitmap font. This module is a small, direct FFI
## binding covering exactly what text layout and rasterisation need — no GTK,
## no gintro, no generated bindings.
##
## Only the calls used by `pango_text.nim` are declared. Everything is an opaque
## pointer; nothing here is exposed to widget code.

import std/strutils

{.passC: staticExec("pkg-config --cflags pangocairo").}
{.passL: staticExec("pkg-config --libs pangocairo").}

const
  cairoHdr = "<cairo.h>"
  pangoHdr = "<pango/pangocairo.h>"

type
  CairoSurface* = distinct pointer
  CairoContext* = distinct pointer
  PangoLayout* = distinct pointer
  PangoFontDescription* = distinct pointer
  GObject* = distinct pointer

  CairoFormat* {.size: sizeof(cint).} = enum
    ## Values must match cairo_format_t exactly.
    CairoFormatInvalid = -1
    CairoFormatArgb32 = 0
    CairoFormatRgb24 = 1
    CairoFormatA8 = 2
    CairoFormatA1 = 3

  PangoWrapMode* {.size: sizeof(cint).} = enum
    PangoWrapWord = 0
    PangoWrapChar = 1
    PangoWrapWordChar = 2

  PangoAlignment* {.size: sizeof(cint).} = enum
    PangoAlignLeft = 0
    PangoAlignCenter = 1
    PangoAlignRight = 2

  PangoEllipsizeMode* {.size: sizeof(cint).} = enum
    PangoEllipsizeNone = 0
    PangoEllipsizeStart = 1
    PangoEllipsizeMiddle = 2
    PangoEllipsizeEnd = 3

  CairoFontOptions* = distinct pointer
  PangoContext* = distinct pointer

  PangoRectangle* {.importc: "PangoRectangle", header: pangoHdr,
                    bycopy, completeStruct.} = object
    ## Pango units (1/1024 px), not pixels.
    x*, y*, width*, height*: cint

  CairoAntialias* {.size: sizeof(cint).} = enum
    ## cairo_antialias_t
    CairoAntialiasDefault = 0
    CairoAntialiasNone = 1
    CairoAntialiasGray = 2
    CairoAntialiasSubpixel = 3
    CairoAntialiasFast = 4
    CairoAntialiasGood = 5
    CairoAntialiasBest = 6

  CairoSubpixelOrder* {.size: sizeof(cint).} = enum
    ## cairo_subpixel_order_t
    CairoSubpixelDefault = 0
    CairoSubpixelRgb = 1
    CairoSubpixelBgr = 2
    CairoSubpixelVrgb = 3
    CairoSubpixelVbgr = 4

  CairoHintStyle* {.size: sizeof(cint).} = enum
    ## cairo_hint_style_t
    CairoHintDefault = 0
    CairoHintNone = 1
    CairoHintSlight = 2
    CairoHintMedium = 3
    CairoHintFull = 4

const
  PANGO_SCALE* = 1024
    ## Pango works in 1/1024ths of a pixel.

proc isNil*(s: CairoSurface): bool {.borrow.}
proc isNil*(c: CairoContext): bool {.borrow.}
proc isNil*(l: PangoLayout): bool {.borrow.}
proc isNil*(d: PangoFontDescription): bool {.borrow.}

# ---------------------------------------------------------------------------
# Cairo
# ---------------------------------------------------------------------------
proc cairoImageSurfaceCreate*(format: CairoFormat, width, height: cint): CairoSurface
  {.importc: "cairo_image_surface_create", header: cairoHdr.}

proc cairoSurfaceDestroy*(s: CairoSurface)
  {.importc: "cairo_surface_destroy", header: cairoHdr.}

proc cairoSurfaceFlush*(s: CairoSurface)
  {.importc: "cairo_surface_flush", header: cairoHdr.}

proc cairoImageSurfaceGetData*(s: CairoSurface): ptr UncheckedArray[uint8]
  {.importc: "cairo_image_surface_get_data", header: cairoHdr.}

proc cairoImageSurfaceGetStride*(s: CairoSurface): cint
  {.importc: "cairo_image_surface_get_stride", header: cairoHdr.}

proc cairoCreate*(s: CairoSurface): CairoContext
  {.importc: "cairo_create", header: cairoHdr.}

proc cairoDestroy*(c: CairoContext)
  {.importc: "cairo_destroy", header: cairoHdr.}

proc cairoSetSourceRgba*(c: CairoContext, r, g, b, a: cdouble)
  {.importc: "cairo_set_source_rgba", header: cairoHdr.}

proc cairoSetOperator*(c: CairoContext, op: cint)
  {.importc: "cairo_set_operator", header: cairoHdr.}

proc cairoPaint*(c: CairoContext)
  {.importc: "cairo_paint", header: cairoHdr.}

proc cairoMoveTo*(c: CairoContext, x, y: cdouble)
  {.importc: "cairo_move_to", header: cairoHdr.}

# ---------------------------------------------------------------------------
# Pango
# ---------------------------------------------------------------------------
proc pangoCairoCreateLayout*(c: CairoContext): PangoLayout
  {.importc: "pango_cairo_create_layout", header: pangoHdr.}

proc pangoCairoShowLayout*(c: CairoContext, l: PangoLayout)
  {.importc: "pango_cairo_show_layout", header: pangoHdr.}

proc pangoCairoUpdateLayout*(c: CairoContext, l: PangoLayout)
  {.importc: "pango_cairo_update_layout", header: pangoHdr.}

proc pangoLayoutSetText*(l: PangoLayout, text: cstring, length: cint)
  {.importc: "pango_layout_set_text", header: pangoHdr.}

proc pangoLayoutSetMarkup*(l: PangoLayout, markup: cstring, length: cint)
  {.importc: "pango_layout_set_markup", header: pangoHdr.}

proc pangoLayoutGetPixelSize*(l: PangoLayout, width, height: ptr cint)
  {.importc: "pango_layout_get_pixel_size", header: pangoHdr.}

proc pangoLayoutGetBaseline*(l: PangoLayout): cint
  {.importc: "pango_layout_get_baseline", header: pangoHdr.}

proc pangoLayoutSetWidth*(l: PangoLayout, width: cint)
  {.importc: "pango_layout_set_width", header: pangoHdr.}

proc pangoLayoutSetWrap*(l: PangoLayout, mode: PangoWrapMode)
  {.importc: "pango_layout_set_wrap", header: pangoHdr.}

proc pangoLayoutSetAlignment*(l: PangoLayout, a: PangoAlignment)
  {.importc: "pango_layout_set_alignment", header: pangoHdr.}

proc pangoLayoutSetEllipsize*(l: PangoLayout, m: PangoEllipsizeMode)
  {.importc: "pango_layout_set_ellipsize", header: pangoHdr.}

proc pangoLayoutSetSingleParagraphMode*(l: PangoLayout, setting: cint)
  {.importc: "pango_layout_set_single_paragraph_mode", header: pangoHdr.}

proc pangoLayoutSetFontDescription*(l: PangoLayout, d: PangoFontDescription)
  {.importc: "pango_layout_set_font_description", header: pangoHdr.}

proc pangoLayoutIndexToPos*(l: PangoLayout, index: cint, pos: pointer)
  {.importc: "pango_layout_index_to_pos", header: pangoHdr.}

proc pangoLayoutXyToIndex*(l: PangoLayout, x, y: cint,
                           index, trailing: ptr cint): cint
  {.importc: "pango_layout_xy_to_index", header: pangoHdr.}

proc pangoFontDescriptionFromString*(s: cstring): PangoFontDescription
  {.importc: "pango_font_description_from_string", header: pangoHdr.}

proc pangoFontDescriptionFree*(d: PangoFontDescription)
  {.importc: "pango_font_description_free", header: pangoHdr.}

proc gObjectUnref*(o: pointer)
  {.importc: "g_object_unref", header: "<glib-object.h>".}


# ---------------------------------------------------------------------------
# Cairo font options (antialiasing / hinting / subpixel order)
# ---------------------------------------------------------------------------
proc cairoFontOptionsCreate*(): CairoFontOptions
  {.importc: "cairo_font_options_create", header: cairoHdr.}

proc cairoFontOptionsDestroy*(o: CairoFontOptions)
  {.importc: "cairo_font_options_destroy", header: cairoHdr.}

proc cairoFontOptionsSetAntialias*(o: CairoFontOptions, a: CairoAntialias)
  {.importc: "cairo_font_options_set_antialias", header: cairoHdr.}

proc cairoFontOptionsSetHintStyle*(o: CairoFontOptions, h: CairoHintStyle)
  {.importc: "cairo_font_options_set_hint_style", header: cairoHdr.}

proc cairoFontOptionsSetSubpixelOrder*(o: CairoFontOptions,
                                       s: CairoSubpixelOrder)
  {.importc: "cairo_font_options_set_subpixel_order", header: cairoHdr.}

proc pangoCairoContextSetFontOptions*(c: PangoContext, o: CairoFontOptions)
  {.importc: "pango_cairo_context_set_font_options", header: pangoHdr.}

proc pangoLayoutGetContext*(l: PangoLayout): PangoContext
  {.importc: "pango_layout_get_context", header: pangoHdr.}

proc pangoLayoutContextChanged*(l: PangoLayout)
  {.importc: "pango_layout_context_changed", header: pangoHdr.}

# ---------------------------------------------------------------------------
# Layout queries used by text editing
# ---------------------------------------------------------------------------
proc pangoLayoutSetAutoDir*(l: PangoLayout, autoDir: cint)
  {.importc: "pango_layout_set_auto_dir", header: pangoHdr.}

proc pangoLayoutGetLineCount*(l: PangoLayout): cint
  {.importc: "pango_layout_get_line_count", header: pangoHdr.}

proc pangoLayoutGetCursorPos*(l: PangoLayout, index: cint,
                              strong, weak: ptr PangoRectangle)
  {.importc: "pango_layout_get_cursor_pos", header: pangoHdr.}

proc cairoImageSurfaceGetWidth*(s: CairoSurface): cint
  {.importc: "cairo_image_surface_get_width", header: cairoHdr.}

proc cairoImageSurfaceGetHeight*(s: CairoSurface): cint
  {.importc: "cairo_image_surface_get_height", header: cairoHdr.}

# ---------------------------------------------------------------------------
# Pango unit conversion
# ---------------------------------------------------------------------------
proc toPixels*(pangoUnits: cint): float32 {.inline.} =
  pangoUnits.float32 / PANGO_SCALE.float32

proc toPangoUnits*(pixels: float32): cint {.inline.} =
  cint(pixels * PANGO_SCALE.float32)

# ---------------------------------------------------------------------------
# Font description strings
# ---------------------------------------------------------------------------
proc fontDescString*(family: string, size: float32,
                     bold = false, italic = false): string =
  ## Build a Pango font description such as "DejaVu Sans Bold Italic 14".
  ## An empty family falls back to the fontconfig "Sans" alias, which resolves
  ## on any system with fonts installed.
  result = if family.len == 0: "Sans" else: family
  if bold: result.add " Bold"
  if italic: result.add " Italic"
  # Pango parses a trailing number as the size in points.
  result.add " " & formatFloat(size, ffDecimal, 1)
