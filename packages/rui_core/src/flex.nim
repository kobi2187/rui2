## Flex allocation: how a Row or Column shares out its main axis.
##
## Flutter's rule. The children without a flex factor are laid out first, at
## their natural size. Whatever main-axis room is left is then divided between
## the flex children in proportion to their factors: an `Expanded` (tight)
## child gets exactly its share, a `Flexible` (loose) child at most its share
## -- its natural size if that is smaller. A container with no bounded main
## axis has no room to divide, and its flex children keep their natural size.
##
## The factor lives on the child, as `Widget.flexGrow` (set by Expanded,
## Flexible, Spacer or the `flex` modifier), with `Widget.flexLoose` for
## Flexible's fit.

import types

proc flexSizes*(factors: openArray[float32], loose: openArray[bool],
                natural: openArray[float32], free: float32): seq[float32] =
  ## The main-axis size of each flex child (factor > 0) given `free` room.
  ## Non-flex entries come back as their natural size. `free` < 0 means the
  ## axis is unbounded: every child keeps its natural size.
  result = newSeq[float32](factors.len)
  var total = 0.0'f32
  for i, f in factors:
    result[i] = natural[i]
    if f > 0: total += f
  if free < 0 or total <= 0:
    return
  let perFlex = max(0.0'f32, free) / total
  for i, f in factors:
    if f > 0:
      let share = perFlex * f
      result[i] = if loose[i]: min(natural[i], share) else: share
