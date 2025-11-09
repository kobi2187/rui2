## Drawing Primitives - Unified Module
##
## This module has been refactored into focused, composable sub-modules
## following the Forth philosophy: small, obvious functions that compose.
##
## Module Structure:
## - primitives/shapes.nim      (~240 lines) - Basic geometric shapes and effects
## - primitives/text.nim        (~210 lines) - Text rendering and measurement
## - primitives/controls.nim    (~380 lines) - Interactive UI controls
## - primitives/panels.nim      (~180 lines) - Containers, cards, panels
## - primitives/indicators.nim  (~210 lines) - Status symbols and progress
##
## Total: ~1220 lines split into 5 focused modules (was 1292 in one file)
##
## This file re-exports all primitives for backward compatibility.
## All existing code continues to work unchanged.

import primitives/shapes
import primitives/text
import primitives/controls
import primitives/panels
import primitives/indicators

# Re-export everything for backward compatibility
export shapes
export text
export controls
export panels
export indicators

## Migration Notes:
##
## The old monolithic file has been preserved as drawing_primitives.nim.old
## for reference. Once you've verified everything works, you can remove it.
##
## Benefits of the new structure:
## - Much easier to find specific drawing functions
## - Clear separation of concerns
## - Each module is maintainable size (<400 lines)
## - Easier to test individual primitives
## - Better compile times (can import only what you need)
##
## Example of targeted imports:
##   import drawing_primitives/primitives/shapes  # Only shapes
##   import drawing_primitives/primitives/text    # Only text
##   import drawing_primitives                    # Everything (like before)
