## Click runs: a click, a double-click, a triple-click.
##
## A click within the user's double-click time of the last one, on the same
## target, continues the run; anything slower, or on another target (another
## row of a list), starts a new one. Shared by everything that tells a
## double-click from two clicks -- a text field selecting a word, a list
## opening the row.

import rui_core
import std/monotimes

type ClickRun* = object
  count*: int        ## 1..3 within a run, 0 before any click
  at*: int64         ## when the last click of the run landed, MonoTime ticks (ns):
                     ## a plain number, so scripting can report it
  target*: int       ## what it landed on: a row, or 0 when there is only one

proc countClick*(run: var ClickRun, at: MonoTime, target = 0, most = 3): int =
  ## Record a click on `target` at `at`; returns 1 for a single click, 2 for a
  ## double-click, up to `most`.
  let window = int64(prefs.doubleClickMs) * 1_000_000
  if run.count > 0 and target == run.target and at.ticks - run.at <= window:
    run.count = min(run.count + 1, most)
  else:
    run.count = 1
  run.at = at.ticks
  run.target = target
  run.count
