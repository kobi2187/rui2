## Pango Helpers - Forth Style Refactoring
##
## Small, composable functions for Pango text rendering
## Each function does ONE thing clearly

import raylib
import ../pangolib_binding/src/[pangotypes, pangoprivate]
import std/[options, results]

# ============================================================================
# Predicates - Cairo Surface State
# ============================================================================

proc hasValidSurface*(layout: TextLayout): bool =
  ## Check if layout has a valid Cairo surface
  layout.surface != nil

proc hasValidContext*(layout: TextLayout): bool =
  ## Check if layout has a valid Cairo context
  layout.cairoCtx != nil

proc hasValidLayout*(layout: TextLayout): bool =
  ## Check if layout has a valid Pango layout
  layout.layout != nil

# ============================================================================
# Queries - Get Surface Information
# ============================================================================

proc getLayoutPixelSize*(layout: TextLayout): tuple[w, h: cint] =
  ## Get layout dimensions in pixels
  var w, h: cint
  pango_layout_get_pixel_size(layout.layout, addr w, addr h)
  (w, h)

proc getSurfaceWidth*(surface: ptr cairo_surface_t): cint =
  ## Get Cairo surface width
  cairo_image_surface_get_width(surface)

proc getSurfaceHeight*(surface: ptr cairo_surface_t): cint =
  ## Get Cairo surface height
  cairo_image_surface_get_height(surface)

proc getSurfaceStride*(surface: ptr cairo_surface_t): cint =
  ## Get Cairo surface stride
  cairo_image_surface_get_stride(surface)

proc getSurfaceData*(surface: ptr cairo_surface_t): pointer =
  ## Get pointer to surface pixel data
  cairo_image_surface_get_data(surface)

proc getSurfaceDimensions*(surface: ptr cairo_surface_t): tuple[w, h, stride: cint] =
  ## Get all surface dimensions at once
  let w = getSurfaceWidth(surface)
  let h = getSurfaceHeight(surface)
  let stride = getSurfaceStride(surface)
  (w, h, stride)

# ============================================================================
# Actions - Cairo Resource Management
# ============================================================================

proc destroySurface*(layout: var TextLayout) =
  ## Destroy Cairo surface if exists
  if layout.hasValidSurface():
    cairo_surface_destroy(layout.surface)
    layout.surface = nil

proc destroyContext*(layout: var TextLayout) =
  ## Destroy Cairo context if exists
  if layout.hasValidContext():
    cairo_destroy(layout.cairoCtx)
    layout.cairoCtx = nil

proc destroyCairoResources*(layout: var TextLayout) =
  ## Clean up all Cairo resources
  layout.destroyContext()
  layout.destroySurface()

# ============================================================================
# Actions - Surface Creation
# ============================================================================

proc createImageSurface*(w, h: cint): ptr cairo_surface_t =
  ## Create new ARGB32 image surface
  cairo_image_surface_create(CAIRO_FORMAT_ARGB32, w, h)

proc createCairoContext*(surface: ptr cairo_surface_t): ptr cairo_t =
  ## Create Cairo context from surface
  cairo_create(surface)

proc setWhiteTextColor*(ctx: ptr cairo_t) =
  ## Set Cairo to draw white text
  cairo_set_source_rgba(ctx, 1.0, 1.0, 1.0, 1.0)

# ============================================================================
# Pixel Format Conversion - Extract Components
# ============================================================================

proc extractBlue*(data: ptr UncheckedArray[uint8], idx: int): uint8 =
  ## Extract blue component from ARGB32 data
  data[idx + 0]

proc extractGreen*(data: ptr UncheckedArray[uint8], idx: int): uint8 =
  ## Extract green component from ARGB32 data
  data[idx + 1]

proc extractRed*(data: ptr UncheckedArray[uint8], idx: int): uint8 =
  ## Extract red component from ARGB32 data
  data[idx + 2]

proc extractAlpha*(data: ptr UncheckedArray[uint8], idx: int): uint8 =
  ## Extract alpha component from ARGB32 data
  data[idx + 3]

proc extractARGB*(data: ptr UncheckedArray[uint8], idx: int): tuple[r, g, b, a: uint8] =
  ## Extract all ARGB32 components at once
  let b = extractBlue(data, idx)
  let g = extractGreen(data, idx)
  let r = extractRed(data, idx)
  let a = extractAlpha(data, idx)
  (r, g, b, a)

# ============================================================================
# Pixel Format Conversion - Store Components
# ============================================================================

proc storeRed*(dest: var seq[uint8], idx: int, r: uint8) =
  ## Store red component to RGBA data
  dest[idx + 0] = r

proc storeGreen*(dest: var seq[uint8], idx: int, g: uint8) =
  ## Store green component to RGBA data
  dest[idx + 1] = g

proc storeBlue*(dest: var seq[uint8], idx: int, b: uint8) =
  ## Store blue component to RGBA data
  dest[idx + 2] = b

proc storeAlpha*(dest: var seq[uint8], idx: int, a: uint8) =
  ## Store alpha component to RGBA data
  dest[idx + 3] = a

proc storeRGBA*(dest: var seq[uint8], idx: int, r, g, b, a: uint8) =
  ## Store all RGBA components at once
  storeRed(dest, idx, r)
  storeGreen(dest, idx, g)
  storeBlue(dest, idx, b)
  storeAlpha(dest, idx, a)

# ============================================================================
# Index Calculations
# ============================================================================

proc calcSourceIndex*(y, stride: cint): int =
  ## Calculate source index for row
  y.int * stride.int

proc calcDestIndex*(y, w: cint): int =
  ## Calculate dest index for row (RGBA = 4 bytes per pixel)
  y.int * w.int * 4

proc calcRGBABufferSize*(w, h: cint): int =
  ## Calculate size needed for RGBA buffer
  w.int * h.int * 4

# ============================================================================
# Conversion - ARGB32 to RGBA
# ============================================================================

proc convertRow*(srcData: ptr UncheckedArray[uint8],
                destData: var seq[uint8],
                y, w, stride: cint) =
  ## Convert one row from ARGB32 to RGBA
  var srcIdx = calcSourceIndex(y, stride)
  var destIdx = calcDestIndex(y, w)

  for x in 0..<w:
    let (r, g, b, a) = extractARGB(srcData, srcIdx)
    storeRGBA(destData, destIdx, r, g, b, a)
    srcIdx += 4
    destIdx += 4

proc convertARGB32toRGBA*(srcData: pointer, w, h, stride: cint): seq[uint8] =
  ## Convert Cairo ARGB32 surface to Raylib RGBA format
  result = newSeq[uint8](calcRGBABufferSize(w, h))
  let src = cast[ptr UncheckedArray[uint8]](srcData)

  for y in 0..<h:
    convertRow(src, result, y, w, stride)

# ============================================================================
# Raylib Texture Creation
# ============================================================================

proc calcTextureMemory*(w, h: cint): int =
  ## Calculate texture memory usage in bytes (RGBA)
  w.int * h.int * 4

proc createImage*(data: var seq[uint8], w, h: cint): Image =
  ## Create Raylib Image from RGBA data
  Image(
    data: data[0].addr,
    width: w,
    height: h,
    mipmaps: 1,
    format: UncompressedR8g8b8a8
  )

proc isValidTexture*(texture: Texture2D): bool =
  ## Check if texture was created successfully
  texture.id != 0

# ============================================================================
# Font Options Mapping
# ============================================================================

proc mapAntialias*(aa: AntialiasMode): cairo_antialias_t =
  ## Map our antialias mode to Cairo enum
  case aa
  of aaDefault: CAIRO_ANTIALIAS_DEFAULT
  of aaNone: CAIRO_ANTIALIAS_NONE
  of aaGray: CAIRO_ANTIALIAS_GRAY
  of aaSubpixel: CAIRO_ANTIALIAS_SUBPIXEL

proc mapSubpixelOrder*(order: SubpixelOrder): cairo_subpixel_order_t =
  ## Map our subpixel order to Cairo enum
  case order
  of soDefault: CAIRO_SUBPIXEL_ORDER_DEFAULT
  of soRGB: CAIRO_SUBPIXEL_ORDER_RGB
  of soBGR: CAIRO_SUBPIXEL_ORDER_BGR
  of soVRGB: CAIRO_SUBPIXEL_ORDER_VRGB
  of soVBGR: CAIRO_SUBPIXEL_ORDER_VBGR

proc mapHintStyle*(hint: HintStyle): cairo_hint_style_t =
  ## Map our hint style to Cairo enum
  case hint
  of hsNone: CAIRO_HINT_STYLE_NONE
  of hsLight: CAIRO_HINT_STYLE_SLIGHT
  of hsMedium: CAIRO_HINT_STYLE_MEDIUM
  of hsFull: CAIRO_HINT_STYLE_FULL

proc mapWrapMode*(wrap: WrapMode): cint =
  ## Map our wrap mode to Pango enum
  case wrap
  of wmWord: PANGO_WRAP_WORD
  of wmChar: PANGO_WRAP_CHAR
  of wmWordChar: PANGO_WRAP_WORD_CHAR

proc mapFontStyle*(style: FontStyle): cint =
  ## Map our font style to Pango enum
  case style
  of fsNormal: PANGO_STYLE_NORMAL
  of fsItalic: PANGO_STYLE_ITALIC
  of fsOblique: PANGO_STYLE_OBLIQUE

# ============================================================================
# Pango Units Conversion
# ============================================================================

proc toPixels*(pangoUnits: cint): int32 =
  ## Convert Pango units to pixels
  (pangoUnits.int32 div PANGO_SCALE)

proc toPangoUnits*(pixels: float): cint =
  ## Convert pixels to Pango units
  (pixels * PANGO_SCALE.float).cint

proc toPangoUnits*(pixels: int): cint =
  ## Convert integer pixels to Pango units
  (pixels * PANGO_SCALE).cint
