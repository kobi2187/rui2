## Drawing primitives: the shapes and parts every widget draws with.
##
## - primitives/shapes   boxes (with a BoxFinish), lines, the shader-drawn shapes
## - primitives/bevel    the 3D edges of classic desktops (a theme's bevelStyle)
## - primitives/controls, panels, indicators: older drawing helpers for parts
##
## Themed control parts (a button's box, a check box, a slider...) are in
## widget_primitives.nim; this module is what they are made of.

import primitives/shapes
# text module not imported to avoid identifier conflicts with common field name "text"
# import it directly where needed: import drawing_primitives/primitives/text
import primitives/controls
import primitives/panels
import primitives/indicators
import primitives/bevel

export shapes
export controls
export panels
export indicators
export bevel
