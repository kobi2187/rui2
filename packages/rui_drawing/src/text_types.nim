## The vocabulary every text engine speaks: what a measurement, a caret, a hit
## and a string's character boundaries look like, the font options, and the
## font description string. No FFI here, so a module can name these types
## without linking Pango (see text_engine.nim for which engine is linked).

import std/strutils

type
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

# ---------------------------------------------------------------------------

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

type
  CharAttrs* = object
    ## Per codepoint of a string (and one more for its end).
    byteAt*: seq[int]          ## byte offset of each codepoint, then text.len
    cursorStop*: seq[bool]     ## a caret may stand before this codepoint
    backspaceChar*: seq[bool]  ## Backspace removes just the codepoint before it,
                               ## not the whole cluster (a combining mark, say)
    wordStart*: seq[bool]      ## a word begins here / ends before here, by the
    wordEnd*: seq[bool]        ## Unicode rules plus Pango's per-script ones --
                               ## dictionary-based for Thai, Lao, Khmer, which
                               ## are written without spaces

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
