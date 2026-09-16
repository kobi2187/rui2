## rui_drawing - public API barrel
##
## Drawing primitives, visual effects, the theme system (state x intent),
## text cache, and theme-aware widget primitives.

import drawing_primitives; export drawing_primitives  # shapes, controls, panels, indicators, effects
import theme_types;        export theme_types
import theme_sys_core;     export theme_sys_core
import theme_state;        export theme_state   # the visual-state ladder, once
import theme_manager;      export theme_manager
import builtin_themes;     export builtin_themes
import widget_primitives;  export widget_primitives
import pango_binding;       export pango_binding   # Pango/Cairo FFI
import pango_text;          export pango_text      # glyph cache, cursor + hit-test API
import primitives/text;       export text
# primitives/text_cache was deleted: 428 lines with no callers anywhere. The
# real glyph and measurement caches live in pango_text, exported above.
