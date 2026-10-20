## What this machine can do for a non-rectangular window, and which method to
## use. The capabilities are found at run time; the choice is a pure function
## of them, so it is tested without a display.
##
## The methods, from the spikes (packages/rui_shaped/spikes/REPORT.md):
##
## - smTransparentInput: a see-through framebuffer (soft, antialiased edges,
##   any alpha) plus an OS input region so clicks on see-through pixels reach
##   what is behind. X11 with a compositor and the SHAPE extension.
## - smTransparent: the see-through framebuffer alone. Soft edges, but the
##   whole rectangle still takes clicks. Wayland (GLFW cannot set an input
##   region there), Windows when soft edges matter more, macOS (which passes
##   clicks on transparent pixels through by itself).
## - smOsShape: the OS clips the window to a region. Hard edges (a pixel is in
##   or out), clicks outside fall through, no compositor needed. X11 without a
##   compositor, Windows (SetWindowRgn).
## - smRectangle: none of the above works; an ordinary undecorated rectangle,
##   the shape drawn on a backdrop.

type
  ShapePlatform* = enum
    spX11, spWayland, spWindows, spMacOS, spOther

  ShapeMethod* = enum
    smRectangle, smOsShape, smTransparent, smTransparentInput

  ShapeCaps* = object
    platform*: ShapePlatform
    x11*: bool              ## libX11 loaded and the display opened
    shapeExt*: bool         ## X11 SHAPE extension present
    compositor*: bool       ## a compositing manager is running
    argbVisual*: bool       ## a 32-bit visual exists for a see-through window
    windowDepth*: int       ## after the window opened: 32 = alpha granted

proc chooseMethod*(c: ShapeCaps, softEdges = true, clickThrough = true): ShapeMethod =
  ## The best method `c` allows. `softEdges`: antialiased outlines matter;
  ## `clickThrough`: clicks on the see-through parts must reach what is
  ## behind. Where both cannot be had (Windows), `clickThrough` wins unless
  ## soft edges were asked for and click-through was not.
  case c.platform
  of spX11:
    if c.compositor and c.argbVisual:
      if clickThrough and c.shapeExt: smTransparentInput else: smTransparent
    elif c.shapeExt: smOsShape
    else: smRectangle
  of spWayland: smTransparent
  of spWindows:
    if softEdges and not clickThrough: smTransparent else: smOsShape
  of spMacOS: smTransparent
  of spOther: smRectangle

proc confirmMethod*(c: ShapeCaps, chosen: ShapeMethod): ShapeMethod =
  ## After the window is open: a see-through method whose window did not get
  ## an alpha channel (no 32-bit visual granted) would show black where it
  ## should be clear; fall back to the OS region, or the rectangle.
  result = chosen
  if c.platform == spX11 and chosen in {smTransparent, smTransparentInput} and
     c.windowDepth > 0 and c.windowDepth != 32:
    result = if c.shapeExt: smOsShape else: smRectangle

proc needsTransparentFramebuffer*(m: ShapeMethod): bool =
  m in {smTransparent, smTransparentInput}

proc setsBoundingRegion*(m: ShapeMethod): bool = m == smOsShape
proc setsInputRegion*(m: ShapeMethod): bool = m in {smOsShape, smTransparentInput}

proc describe*(m: ShapeMethod): string =
  case m
  of smTransparentInput: "see-through window, soft edges, clicks pass through the clear parts"
  of smTransparent: "see-through window, soft edges, the whole rectangle takes clicks"
  of smOsShape: "OS-clipped window, hard edges, clicks pass through outside the shape"
  of smRectangle: "plain rectangle: this system cannot shape windows"
