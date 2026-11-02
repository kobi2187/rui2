## Drawing primitives: the shapes and parts every widget draws with.
##
## - primitives/shapes   boxes (with a BoxFinish), lines, the shader-drawn shapes
## - primitives/bevel    the 3D edges of classic desktops (a theme's bevelStyle)
## - primitives/marks   small theme-free drawings (check mark, arrow, alert
##                       symbol, focus outline, disabled veil, group box frame)
##
## Themed control parts (a button's box, a check box, a slider...) are in
## widget_primitives.nim; this module is what they are made of.

import primitives/shapes
# text module not imported to avoid identifier conflicts with common field name "text"
# import it directly where needed: import drawing_primitives/primitives/text
import primitives/marks
import primitives/bevel

export shapes
export marks
export bevel
