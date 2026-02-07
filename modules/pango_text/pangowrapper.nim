## Wrapper for pangolib_binding that works with RUI2
## Re-exports the Pango+Cairo→Raylib pipeline
##
## pangolib_binding must be available as a sibling directory:
##   /home/user/
##     ├── rui2/
##     └── pangolib_binding/
##         └── src/
##             ├── pangotypes.nim
##             └── pangocore.nim

import raylib
import std/[options, results]

# Import from sibling directory pangolib_binding
# From modules/pango_text/ we go ../../.. to reach sibling
import ../../../pangolib_binding/src/[pangotypes, pangocore]

# Re-export everything
export pangotypes, pangocore
export initTextLayout, freeTextLayout
export getCursorPosition, getTextIndexFromPosition

## Usage:
##
## ```nim
## import pango_integration/pangowrapper
##
## let result = initTextLayout("Hello World", maxWidth = 400)
## if result.isOk:
##   var layout = result.get()
##   defer: freeTextLayout(layout)
##   drawTexture(layout.texture, 100, 100, WHITE)
## else:
##   echo "Error: ", result.error.message
## ```
