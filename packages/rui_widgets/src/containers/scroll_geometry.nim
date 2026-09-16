## Which scrollbars a viewport needs, and where their thumbs sit.
##
## Split out of scrollview.nim, where `layout` and `render` each worked it out
## for themselves from the same four numbers. They already disagreed: `layout`
## clamped the scroll offsets against a viewport reduced by both scrollbars,
## while `render` sized the thumbs against one reduced by neither, so a thumb
## could run past the end of its own track.
##
## The part worth stating out loud is that the two scrollbars are mutually
## dependent. Showing a vertical scrollbar narrows the viewport, which can
## create the need for a horizontal one, which shortens the viewport, which can
## create the need for a vertical one. Deciding them independently -- which is
## what the old code did, twice over -- gets the corner case wrong: content
## that fits horizontally by less than the scrollbar's width gets no horizontal
## scrollbar and is quietly unreachable.

import rui_core

type
  ScrollExtent* = object
    ## Content against viewport, before any scrollbars are taken out.
    contentWidth*, contentHeight*: float32
    viewportWidth*, viewportHeight*: float32
    scrollbarWidth*: float32

  ScrollBars* = object
    ## What the extent works out to.
    vertical*, horizontal*: bool
    ## The viewport that is actually left for content, once the bars are in.
    innerWidth*, innerHeight*: float32

const MinThumb* = 20.0'f32
  ## A thumb shorter than this is too small to grab.

proc secondPass(e: ScrollExtent, vertical, horizontal: bool):
    tuple[vertical, horizontal: bool] =
  ## Exactly one bar so far: re-ask the other against the viewport this one has
  ## already narrowed. One pass is enough, because a bar can only be added and
  ## the second bar cannot un-need the first.
  if vertical and not horizontal:
    (true, e.contentWidth > e.viewportWidth - e.scrollbarWidth)
  elif horizontal and not vertical:
    (e.contentHeight > e.viewportHeight - e.scrollbarWidth, true)
  else:
    (vertical, horizontal)

proc scrollBarsFor*(e: ScrollExtent): ScrollBars =
  ## Decide each bar against the bare viewport, then let secondPass settle the
  ## mutual dependency.
  let (v, h) = secondPass(e, e.contentHeight > e.viewportHeight,
                             e.contentWidth > e.viewportWidth)
  result.vertical = v
  result.horizontal = h
  result.innerWidth = e.viewportWidth -
                      (if v: e.scrollbarWidth else: 0.0'f32)
  result.innerHeight = e.viewportHeight -
                       (if h: e.scrollbarWidth else: 0.0'f32)

proc maxScrollX*(e: ScrollExtent, bars: ScrollBars): float32 =
  max(0.0'f32, e.contentWidth - bars.innerWidth)

proc maxScrollY*(e: ScrollExtent, bars: ScrollBars): float32 =
  max(0.0'f32, e.contentHeight - bars.innerHeight)

proc thumbLength*(trackLength, viewLength, contentLength: float32): float32 =
  ## As long a share of the track as the view is of the content, floored at
  ## MinThumb so it stays grabbable however long the content gets.
  if contentLength <= 0:
    return trackLength
  max(MinThumb, trackLength * min(1.0'f32, viewLength / contentLength))

proc thumbOffset*(trackLength, thumbLength, scroll, maxScroll: float32): float32 =
  ## How far down (or along) the track the thumb starts.
  ##
  ## Measured against the *free* travel, trackLength - thumbLength, not the
  ## whole track. Against the whole track a fully scrolled thumb hangs off the
  ## end by its own length.
  if maxScroll <= 0:
    return 0.0'f32
  clamp(scroll / maxScroll, 0.0'f32, 1.0'f32) * (trackLength - thumbLength)

proc verticalTrack*(bounds: Rect, padding, scrollbarWidth: float32,
                    bars: ScrollBars): Rect =
  ## Down the right-hand edge, stopping short of a horizontal bar if there is
  ## one, so the two do not overlap in the corner.
  Rect(x: bounds.x + bounds.width - scrollbarWidth,
       y: bounds.y + padding,
       width: scrollbarWidth,
       height: bars.innerHeight)

proc horizontalTrack*(bounds: Rect, padding, scrollbarWidth: float32,
                      bars: ScrollBars): Rect =
  Rect(x: bounds.x + padding,
       y: bounds.y + bounds.height - scrollbarWidth,
       width: bars.innerWidth,
       height: scrollbarWidth)
