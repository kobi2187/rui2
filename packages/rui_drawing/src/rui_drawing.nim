## rui_drawing - public API barrel
##
## Drawing comes in three layers, and the theme that colours them:
##
## - **Shapes** (drawing_primitives: primitives/shapes, sdf, marks, bevel, and
##   text): boxes with a `BoxFinish`, shadows, lines, triangles, images, glyph
##   marks. They take colours as arguments and know nothing of the theme.
## - **Parts** (widget_primitives): every themed piece of a control -- its box,
##   a check box, a radio, a slider, a progress bar, a scroll bar, a tooltip, a
##   tab, a menu row -- drawn from ThemeProps with the theme's finish.
## - **Surfaces** (theme_background, tiles, textures, backdrop): what is behind
##   the widgets -- the window background, background tiles, frosted glass, a
##   modal's backdrop.
##
## The theme (theme_sys_core, theme_file, theme_manager, brand themes) is data:
## State x Intent -> ThemeProps, read and written by its own fields.

import drawing_primitives; export drawing_primitives  # shapes: boxes, marks, bevels
import theme_types;        export theme_types
import theme_sys_core;     export theme_sys_core
import theme_state;        export theme_state   # the visual-state ladder, once
import theme_manager;      export theme_manager
import theme_check;        export theme_check   # contrast ratios, contrastProblems
import builtin_themes;     export builtin_themes
import widget_primitives;  export widget_primitives
import backdrop;           export backdrop     # a modal's frozen, themed page
import pango_binding;       export pango_binding   # Pango/Cairo FFI
import pango_text;          export pango_text      # glyph cache, cursor + hit-test API
import primitives/text;       export text
# primitives/text_cache was deleted: 428 lines with no callers anywhere. The
# real glyph and measurement caches live in pango_text, exported above.
import tiles;              export tiles        # background tiles built into the program
import textures;           export textures     # pictures from files, loaded once
import theme_background;   export theme_background  # a theme's tiled picture behind everything
import primitives/sdf
export drawSdfBox, drawSdfShadow, drawSdfSegment, drawSdfTriangle, drawSdfImage, BoxFinish
  # smooth boxes, soft shadows, lines and triangles: what a decoration's own
  # painter (rui_widgets decoration.nim) draws with
