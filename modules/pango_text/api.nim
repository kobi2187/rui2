## Pango Text Module - Public API
##
## Pango+Cairo text rendering pipeline with caching.
## Provides high-quality text rendering as a replacement for Raylib's built-in text.
##
## Usage:
##   import modules/pango_text/api
##
##   # Simple text drawing
##   drawText("Hello", 100, 100, 20, BLACK)
##
##   # With custom font
##   drawText("Code", 100, 150, 16, GREEN, "Monospace")
##
##   # Explicit style
##   let style = TextStyle(fontFamily: "Sans", fontSize: 24, color: RED, maxWidth: 300)
##   drawTextEx("Long text", 100, 100, style)
##
## Requires:
##   External pangolib_binding as sibling directory to rui2/

import ./pangowrapper
import ./text_render
import ./text_cache

export pangowrapper
export text_render
export text_cache
