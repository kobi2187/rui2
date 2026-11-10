## Short ways to say the common Flutter layouts.
##
## Flutter's names are long (`UnconstrainedBox`, `FractionallySizedBox`,
## `IntrinsicHeight`), and the commonest uses wrap one widget. Each shortcut
## here is either a **modifier** that wraps the widget it follows and returns
## the wrapper (as `.margin` does), or a **short constructor** for the block
## form. Both are plain procs: they work in `ui:`, in ordinary code and with
## `Embed(w)`.
##
## ```nim
## ui:
##   Column(crossAxisAlignment = CrossAxisAlignment.stretch, spacing = 8.0):
##     ImageWidget(imagePath = "cover.png").aspect(16 / 9)       # AspectRatio
##     Button(text = "OK").ownSize                    # keeps its size in the stretch
##     Row(crossAxisAlignment = CrossAxisAlignment.stretch).sameHeight:
##       Card(): ...                                  # every card as tall as the tallest
##       Card(): ...
##     Gap(12)                                        # SizedBox(height: 12) in a Column
##     Label(text = "Saved").showIf(saved.value)       # Visibility
##   Stack():
##     ImageWidget(imagePath = "map.png").cover                  # Positioned.fill
##     Badge(text = "3").at(right = 8, top = 8)       # Positioned
## ```
##
## Modifiers apply in the order written, so a wrapper and what follows it go
## together: `Button(...).center.flex` gives the Center the flex share,
## `Button(...).flex.center` gives it to the Button inside the Center (where
## it does nothing). Put `.flex` / `.flexible` last.

import rui_core
import std/math
import boxes, stack, constraint_boxes

proc wrap[W: Widget](wrapper: W, child: Widget): W =
  wrapper.addChild child
  wrapper

# --- placing --------------------------------------------------------------------

proc center*(widget: Widget): Center =
  ## `Center(child: widget)`: all the room there is, the widget in the middle.
  newCenter().wrap(widget)

proc align*(widget: Widget, alignment: Alignment): Align =
  ## `Align(alignment: ..., child: widget)`: `.align(Alignment.bottomRight)`.
  newAlign(alignment = alignment).wrap(widget)

proc align*(widget: Widget, x, y: float32): Align =
  ## The same, by numbers: -1 is left / top, 0 the middle, 1 right / bottom.
  newAlign(alignment = Alignment(x: x, y: y)).wrap(widget)

proc at*(widget: Widget, left = NaN.float32, top = NaN.float32, right = NaN.float32,
         bottom = NaN.float32, width = NaN.float32, height = NaN.float32): Positioned =
  ## `Positioned(...)` in a Stack: pinned by the edges given. Pinned at both
  ## ends of an axis, the widget spans between them.
  newPositioned(left = left, top = top, right = right, bottom = bottom,
                width = width, height = height).wrap(widget)

proc cover*(widget: Widget): Positioned =
  ## `Positioned.fill`: the whole Stack.
  widget.at(left = 0, top = 0, right = 0, bottom = 0)

# --- sizing -----------------------------------------------------------------------

proc ownSize*(widget: Widget, alignment = AlignmentCenter): UnconstrainedBox =
  ## `UnconstrainedBox`: the widget at its own size wherever it is -- in a
  ## stretch, an Expanded, a tight parent -- overflowing if it must. The way to
  ## say "my size wins" (the CSS rule) for one widget.
  newUnconstrainedBox(alignment = alignment).wrap(widget)

proc overflow*(widget: Widget, minWidth = NaN.float32, maxWidth = NaN.float32,
               minHeight = NaN.float32, maxHeight = NaN.float32): OverflowBox =
  ## `OverflowBox`: the widget under the limits given (the rest are the
  ## parent's), which may exceed the parent; the box is as big as allowed.
  newOverflowBox(minWidth = minWidth, maxWidth = maxWidth,
                 minHeight = minHeight, maxHeight = maxHeight).wrap(widget)

proc limit*(widget: Widget, width = Inf.float32, height = Inf.float32): LimitedBox =
  ## `LimitedBox`: at most this big where the parent sets no limit (inside a
  ## scroll view, along a Row); no effect where it does.
  newLimitedBox(maxWidth = width, maxHeight = height).wrap(widget)

proc aspect*(widget: Widget, ratio: float32): AspectRatio =
  ## `AspectRatio`: width / height = `ratio`, as big as the room allows.
  newAspectRatio(aspectRatio = ratio).wrap(widget)

proc fraction*(widget: Widget, width = NaN.float32, height = NaN.float32,
               alignment = AlignmentCenter): FractionallySizedBox =
  ## `FractionallySizedBox`: `width` / `height` as shares (0..1) of the room.
  newFractionallySizedBox(widthFactor = width, heightFactor = height,
                          alignment = alignment).wrap(widget)

proc sameHeight*(widget: Widget): IntrinsicHeight =
  ## `IntrinsicHeight`: around a stretched Row, every child as tall as the
  ## tallest (a divider beside cards, cards of equal height).
  newIntrinsicHeight().wrap(widget)

proc sameWidth*(widget: Widget): IntrinsicWidth =
  ## `IntrinsicWidth`: around a stretched Column, every child as wide as the
  ## widest (a menu of equal buttons).
  newIntrinsicWidth().wrap(widget)

# --- showing ------------------------------------------------------------------------

proc showIf*(widget: Widget, shown: bool, keepSize = false): Visibility =
  ## `Visibility`: shown, or hidden -- gone, or (`keepSize`) leaving its room.
  newVisibility(shown = shown, maintainSize = keepSize).wrap(widget)

proc offstage*(widget: Widget, offstage = true): Offstage =
  ## `Offstage`: laid out but not shown, and taking no room.
  newOffstage(offstage = offstage).wrap(widget)

# --- short constructors, for the block form -----------------------------------------
#
# `Ratio(16 / 9): ImageWidget(...)` in `ui:` calls `newRatio`; the block's widget is
# added to what it returns.

proc newGap*(size: float32): SizedBox =
  ## `Gap(12)`: a 12-pixel gap in a Row or a Column (a SizedBox that size on
  ## both axes; the one across is harmless).
  newSizedBox(width = size, height = size)

proc newOwnSize*(alignment = AlignmentCenter): UnconstrainedBox =
  newUnconstrainedBox(alignment = alignment)

proc newRatio*(ratio: float32): AspectRatio = newAspectRatio(aspectRatio = ratio)

proc newFraction*(width = NaN.float32, height = NaN.float32,
                  alignment = AlignmentCenter): FractionallySizedBox =
  newFractionallySizedBox(widthFactor = width, heightFactor = height, alignment = alignment)

proc newLimit*(width = Inf.float32, height = Inf.float32): LimitedBox =
  newLimitedBox(maxWidth = width, maxHeight = height)

proc newSameHeight*(): IntrinsicHeight = newIntrinsicHeight()
proc newSameWidth*(): IntrinsicWidth = newIntrinsicWidth()

proc newShowIf*(shown: bool, keepSize = false): Visibility =
  newVisibility(shown = shown, maintainSize = keepSize)

proc newAt*(left = NaN.float32, top = NaN.float32, right = NaN.float32,
            bottom = NaN.float32, width = NaN.float32, height = NaN.float32): Positioned =
  newPositioned(left = left, top = top, right = right, bottom = bottom,
                width = width, height = height)
