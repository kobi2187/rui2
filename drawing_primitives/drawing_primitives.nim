## Drawing Primitives - Unified Module
##
## This module provides drawing utilities for RUI2 widgets.
##
## Module Structure:
## - drawing_effects.nim   (~730 lines) - Visual effects (bevels, gradients, shadows, glow)
## - brand_helpers.nim     (~270 lines) - Brand feature extraction utilities
## - theme_sys_core.nim    - Theme system types
## - builtin_themes.nim    - Built-in themes
##
## This file re-exports all utilities for easy access.

import primitives/shapes
# text module not imported to avoid identifier conflicts with common field name "text"
# import it directly where needed: import drawing_primitives/primitives/text
import primitives/controls
import primitives/panels
import primitives/indicators

# Re-export everything for backward compatibility
# Note: text module not exported to avoid conflicts with common field name "text"
# Widgets can import primitives/text directly if needed
export shapes
export controls
export panels
export indicators
import drawing_effects
import brand_helpers

# Re-export everything
export drawing_effects
export brand_helpers

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
