## Windows: a window region (SetWindowRgn) from rectangles, loaded at run time.
##
## The region clips both drawing and clicks, so on Windows it is the
## click-through method with hard edges; soft edges come from GLFW's
## transparent framebuffer instead, which then takes clicks everywhere.
## Written to the documented Win32 API and type-checked, but not yet run on
## Windows: the spikes ran on Linux/X11.

import std/dynlib
import mask

type
  CreateRectRgnFn = proc(l, t, r, b: cint): pointer {.stdcall.}
  CombineRgnFn = proc(dest, a, b: pointer, mode: cint): cint {.stdcall.}
  DeleteObjectFn = proc(obj: pointer): cint {.stdcall.}
  SetWindowRgnFn = proc(hwnd, rgn: pointer, redraw: cint): cint {.stdcall.}

const RgnOr = 2.cint

proc applyWindowRegion*(hwnd: pointer, rects: seq[ShapeRect]): bool =
  ## Clip the window to `rects`. False when the calls could not be loaded.
  let gdi = loadLib("gdi32.dll")
  let user = loadLib("user32.dll")
  if gdi == nil or user == nil: return false
  let createRect = cast[CreateRectRgnFn](gdi.symAddr("CreateRectRgn"))
  let combine = cast[CombineRgnFn](gdi.symAddr("CombineRgn"))
  let delete = cast[DeleteObjectFn](gdi.symAddr("DeleteObject"))
  let setRgn = cast[SetWindowRgnFn](user.symAddr("SetWindowRgn"))
  if createRect == nil or combine == nil or setRgn == nil: return false
  let region = createRect(0, 0, 0, 0)
  for r in rects:
    let piece = createRect(r.x.cint, r.y.cint, (r.x + r.w).cint, (r.y + r.h).cint)
    discard combine(region, region, piece, RgnOr)
    discard delete(piece)
  # The system owns the region from here; it must not be deleted.
  setRgn(hwnd, region, 1) != 0

type
  WinPoint {.bycopy.} = object
    x, y: int32
  GetCursorPosFn = proc(p: ptr WinPoint): cint {.stdcall.}

proc cursorOnScreen*(): (bool, int32, int32) =
  ## The pointer's screen position (GetCursorPos).
  let user = loadLib("user32.dll")
  if user == nil: return (false, 0'i32, 0'i32)
  let get = cast[GetCursorPosFn](user.symAddr("GetCursorPos"))
  var p: WinPoint
  if get == nil or get(p.addr) == 0: return (false, 0'i32, 0'i32)
  (true, p.x, p.y)
