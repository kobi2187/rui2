## The few Xlib and SHAPE-extension calls shaped windows need, loaded at run
## time.
##
## Loaded with std/dynlib rather than linked, so a program using rui_shaped
## still starts where there is no libX11 or libXext (Wayland without
## XWayland, Windows, macOS): `x11Available` is then false and the detector
## picks another method instead of the loader refusing to run the program.

import std/dynlib

type
  Display* = object
  XWindow* = culong
  Atom* = culong
  XRectangle* {.bycopy.} = object
    x*, y*: cshort
    width*, height*: cushort

const
  ShapeBounding* = 0.cint   ## what is drawn
  ShapeInput* = 2.cint      ## what takes the pointer
  ShapeSet* = 0.cint
  Unsorted* = 0.cint
  TrueColor = 4.cint

type
  OpenDisplayFn = proc(name: cstring): ptr Display {.cdecl.}
  CloseDisplayFn = proc(d: ptr Display): cint {.cdecl.}
  FlushFn = proc(d: ptr Display): cint {.cdecl.}
  SyncFn = proc(d: ptr Display, discardEvents: cint): cint {.cdecl.}
  InternAtomFn = proc(d: ptr Display, name: cstring, onlyIfExists: cint): Atom {.cdecl.}
  SelectionOwnerFn = proc(d: ptr Display, atom: Atom): XWindow {.cdecl.}
  DefaultScreenFn = proc(d: ptr Display): cint {.cdecl.}
  MatchVisualFn = proc(d: ptr Display, screen, depth, class: cint, info: pointer): cint {.cdecl.}
  WindowAttrsFn = proc(d: ptr Display, w: XWindow, attrs: pointer): cint {.cdecl.}
  ShapeQueryFn = proc(d: ptr Display, eventBase, errorBase: ptr cint): cint {.cdecl.}
  ShapeVersionFn = proc(d: ptr Display, major, minor: ptr cint): cint {.cdecl.}
  ShapeRectsFn = proc(d: ptr Display, w: XWindow, kind, x, y: cint,
                      rects: ptr XRectangle, n, op, ordering: cint) {.cdecl.}
  ShapeMaskFn = proc(d: ptr Display, w: XWindow, kind, x, y: cint,
                     pixmap: culong, op: cint) {.cdecl.}
  QueryPointerFn = proc(d: ptr Display, w: XWindow, root, child: ptr XWindow,
                        rootX, rootY, winX, winY: ptr cint, mask: ptr cuint): cint {.cdecl.}

type X11* = object
  ## The loaded calls; `ok` false when the libraries are not there.
  ok*: bool
  shapeOk*: bool                 ## libXext and its SHAPE calls loaded
  openDisplay*: OpenDisplayFn
  closeDisplay*: CloseDisplayFn
  flush*: FlushFn
  sync*: SyncFn
  internAtom*: InternAtomFn
  selectionOwner*: SelectionOwnerFn
  defaultScreen*: DefaultScreenFn
  matchVisual*: MatchVisualFn
  windowAttrs*: WindowAttrsFn
  shapeQuery*: ShapeQueryFn
  shapeVersion*: ShapeVersionFn
  shapeRects*: ShapeRectsFn
  shapeMask*: ShapeMaskFn
  queryPointer*: QueryPointerFn

var loaded: X11
var tried = false

proc x11*(): X11 =
  ## The calls, loaded on first use.
  if tried: return loaded
  tried = true
  let xlib = loadLibPattern("libX11.so(|.6)")
  if xlib == nil: return
  template sym(lib, T, name): untyped = cast[T](lib.symAddr(name))
  loaded.openDisplay = sym(xlib, OpenDisplayFn, "XOpenDisplay")
  loaded.closeDisplay = sym(xlib, CloseDisplayFn, "XCloseDisplay")
  loaded.flush = sym(xlib, FlushFn, "XFlush")
  loaded.sync = sym(xlib, SyncFn, "XSync")
  loaded.internAtom = sym(xlib, InternAtomFn, "XInternAtom")
  loaded.selectionOwner = sym(xlib, SelectionOwnerFn, "XGetSelectionOwner")
  loaded.defaultScreen = sym(xlib, DefaultScreenFn, "XDefaultScreen")
  loaded.matchVisual = sym(xlib, MatchVisualFn, "XMatchVisualInfo")
  loaded.windowAttrs = sym(xlib, WindowAttrsFn, "XGetWindowAttributes")
  loaded.queryPointer = sym(xlib, QueryPointerFn, "XQueryPointer")
  loaded.ok = loaded.openDisplay != nil and loaded.internAtom != nil
  let xext = loadLibPattern("libXext.so(|.6)")
  if xext != nil:
    loaded.shapeQuery = sym(xext, ShapeQueryFn, "XShapeQueryExtension")
    loaded.shapeVersion = sym(xext, ShapeVersionFn, "XShapeQueryVersion")
    loaded.shapeRects = sym(xext, ShapeRectsFn, "XShapeCombineRectangles")
    loaded.shapeMask = sym(xext, ShapeMaskFn, "XShapeCombineMask")
    loaded.shapeOk = loaded.shapeQuery != nil and loaded.shapeRects != nil
  loaded

proc hasArgbVisual*(x: X11, d: ptr Display): bool =
  ## Whether the server offers a 32-bit TrueColor visual: what a window with a
  ## see-through framebuffer is made with.
  var info: array[64, byte]      # XVisualInfo, which is only filled in here
  x.matchVisual(d, x.defaultScreen(d), 32, TrueColor, info[0].addr) != 0

proc windowDepth*(x: X11, d: ptr Display, w: XWindow): int =
  ## The window's colour depth: 32 when its framebuffer has an alpha channel.
  var attrs: array[256, byte]    # XWindowAttributes: x, y, width, height, border_width, depth, ...
  if x.windowAttrs(d, w, attrs[0].addr) == 0: return 0
  cast[ptr array[6, cint]](attrs[0].addr)[5].int

proc compositorRunning*(x: X11, d: ptr Display): bool =
  ## A compositing manager owns _NET_WM_CM_S<screen> while it runs; without
  ## one, a window's transparent pixels show as black, not the desktop.
  let atom = x.internAtom(d, cstring("_NET_WM_CM_S" & $x.defaultScreen(d)), 0)
  atom != 0 and x.selectionOwner(d, atom) != 0

proc pointerOnScreen*(x: X11, d: ptr Display, w: XWindow): (bool, cint, cint) =
  ## Where the pointer is on the screen (not relative to a window that may be
  ## moving): what dragging a window by its body needs.
  var root, child: XWindow
  var rx, ry, wx, wy: cint
  var mask: cuint
  if x.queryPointer == nil: return (false, 0, 0)
  let ok = x.queryPointer(d, w, root.addr, child.addr, rx.addr, ry.addr,
                          wx.addr, wy.addr, mask.addr) != 0
  (ok, rx, ry)
