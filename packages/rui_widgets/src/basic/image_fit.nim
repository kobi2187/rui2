## Where an image of a given size goes inside a box of a given size.
##
## Split out of image.nim, where it was 120 lines inside a `render` body: five
## fit modes, each spelling out its own centring arithmetic, with Contain's
## branch duplicated inside ScaleDown. Pure geometry that needed a GL context
## and an image file to exercise.
##
## The modes follow CSS object-fit, which is worth knowing because it settles
## the questions the names do not: Contain and Cover both preserve the aspect
## ratio and differ only in which dimension they satisfy, Fill does not preserve
## it at all, None ignores the box entirely, and ScaleDown is Contain that
## refuses to enlarge.

import rui_core

import raylib

type
  ImageFit* = enum
    Contain   ## Scale to fit within bounds, maintaining aspect ratio
    Cover     ## Scale to cover bounds, maintaining aspect ratio (may crop)
    Fill      ## Stretch to fill bounds (may distort)
    None      ## Display at original size (may crop)
    ScaleDown ## Like Contain but never scale up

proc centredIn*(bounds: Rect, width, height: float32): Rectangle =
  ## A box of the given size, centred in `bounds`. Negative offsets are fine and
  ## mean the image overflows, which is what Cover and None are allowed to do.
  Rectangle(
    x: bounds.x + (bounds.width - width) / 2,
    y: bounds.y + (bounds.height - height) / 2,
    width: width, height: height)

proc scaledToFit*(bounds: Rect, imageAspect: float32): Rectangle =
  ## The largest box of this aspect ratio that fits inside `bounds`.
  if imageAspect > bounds.width / bounds.height:
    # Wider than the box: width is the binding constraint.
    centredIn(bounds, bounds.width, bounds.width / imageAspect)
  else:
    centredIn(bounds, bounds.height * imageAspect, bounds.height)

proc scaledToCover*(bounds: Rect, imageAspect: float32): Rectangle =
  ## The smallest box of this aspect ratio that covers `bounds`. The mirror of
  ## scaledToFit: the same comparison picks the other dimension.
  if imageAspect > bounds.width / bounds.height:
    centredIn(bounds, bounds.height * imageAspect, bounds.height)
  else:
    centredIn(bounds, bounds.width, bounds.width / imageAspect)

proc isDegenerate(bounds: Rect, texWidth, texHeight: float32): bool =
  ## A zero-sized box or image. Every mode divides by one of these.
  bounds.width <= 0 or bounds.height <= 0 or texWidth <= 0 or texHeight <= 0

proc wholeOf(bounds: Rect): Rectangle =
  Rectangle(x: bounds.x, y: bounds.y,
            width: bounds.width, height: bounds.height)

proc destinationFor*(fitMode: ImageFit, bounds: Rect,
                     texWidth, texHeight: float32): Rectangle =
  ## Where to paint an image of texWidth x texHeight inside `bounds`.
  ##
  ## A degenerate box or image falls back to filling the bounds rather than
  ## dividing by zero -- a zero-sized widget paints nothing anyway, so the
  ## result is unobservable and a NaN rectangle is not.
  if isDegenerate(bounds, texWidth, texHeight):
    return wholeOf(bounds)

  let imageAspect = texWidth / texHeight
  case fitMode
  of Fill:
    wholeOf(bounds)
  of Contain:
    scaledToFit(bounds, imageAspect)
  of Cover:
    scaledToCover(bounds, imageAspect)
  of None:
    centredIn(bounds, texWidth, texHeight)
  of ScaleDown:
    if texWidth <= bounds.width and texHeight <= bounds.height:
      centredIn(bounds, texWidth, texHeight)
    else:
      scaledToFit(bounds, imageAspect)
