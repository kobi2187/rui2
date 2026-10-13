## Keyboard for "pick one of N" widgets: SegmentedControl, RadioGroup, TabControl.
##
## They differ in where the options are (a row, a column, a strip) and so which
## arrows move along them, and nothing else. Home and End go to the ends in all
## three; at an end the key is *not* taken (`handled` false), so it can move
## focus on instead of getting stuck in the control.

import raylib

type ChoiceMove* = tuple[handled: bool, index: int]

proc choiceKey*(key: KeyboardKey, count, current: int, vertical: bool): ChoiceMove =
  ## What `key` does to the selection. `handled` false: not a choice key, or already
  ## at that end.
  if count <= 0: return (false, current)
  let target = case key
    of KeyboardKey.Home: 0
    of KeyboardKey.End: count - 1
    of KeyboardKey.Up: (if vertical: current - 1 else: -2)
    of KeyboardKey.Down: (if vertical: current + 1 else: -2)
    of KeyboardKey.Left: (if vertical: -2 else: current - 1)
    of KeyboardKey.Right: (if vertical: -2 else: current + 1)
    else: -2
  if target == -2 or target < 0 or target >= count or target == current:
    return (false, current)
  (true, target)
