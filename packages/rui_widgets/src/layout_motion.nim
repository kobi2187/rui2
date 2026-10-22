## Containers that move their children instead of snapping them.
##
## A container with `animateLayout` (the `.animateLayout()` modifier) works out
## its children's places as always, then arranges each one at a rectangle
## easing toward its place, over the theme's `layoutSeconds`. The children's
## bounds really are those rectangles each frame -- hit-testing, focus rings
## and everything else follow them -- so a panel that grows pushes its
## siblings aside the way a drawer slides, and a minimised one gives its room
## back the same way.
##
## The motion is relative to the container: when the container itself moves
## (inside an animating parent, say), its children go with it at once and only
## their own rearrangement eases. Nothing animates on a child's first
## placement, when the user's preferences say `motion: reduced` (or off), or
## when the theme's layoutSeconds is 0.

import rui_core
import rui_drawing
import std/tables

var moving = initTable[pointer, Animated[Rect]]()
  ## Each moving child's rectangle, relative to its container's top-left.

proc relative(r: Rect, origin: Rect): Rect =
  Rect(x: r.x - origin.x, y: r.y - origin.y, width: r.width, height: r.height)

proc arrangeMoving*(container, child: Widget, target: Rect) =
  ## Give `child` its place `target` (absolute, like `arrange`), travelling
  ## there if `container` animates its layout and the child had a place before.
  if not container.animateLayout:
    child.arrange(target)
    return
  let key = cast[pointer](child)
  let local = target.relative(container.bounds)
  let seconds = currentTheme.layoutSeconds
  if key notin moving or not easingAllowed() or seconds <= 0:
    if key notin moving:
      # Forget it when it goes, so the table does not hold every widget a
      # container ever had.
      child.disposers.add proc() = moving.del(key)
    moving[key] = newAnimated(local)
    child.arrange(target)
    return
  var anim = moving[key]
  # While it travels, follow asks for the container to be laid out again next
  # frame, which brings us back here with the rect one step further on.
  let now = anim.follow(container, local, seconds, easeInOut)
  moving[key] = anim
  child.arrange(Rect(x: container.bounds.x + now.x, y: container.bounds.y + now.y,
                     width: now.width, height: now.height))
