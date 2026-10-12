## rui_windows -- optional in-app windows.
##
## Not part of the `rui` barrel: `import rui_windows` to use it. An app that
## does not pays nothing; the only coupling in core is a pointer-press hook, a
## pointer capture and a focus scope, each a nil check.
##
## See `window.nim` for the widget and `window_manager.nim` for z-order and
## activation.

import window_geometry, window_manager, window
export window_geometry, window_manager, window
