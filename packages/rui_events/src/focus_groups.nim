## Two-level keyboard navigation: between groups, and within one.
##
## A **focus group** is one Tab stop from outside. Tab moves onto the group and
## lands directly on a member; arrow keys move between members; Tab again
## leaves the whole group rather than stepping through it; Escape leaves it
## without moving on. That is the "roving tabindex" arrangement every desktop
## toolkit uses for lists, toolbars and radio groups, and it is what stops a
## twenty-row list being twenty tab stops.
##
## ## The four decisions, and why these answers
##
## These were open questions on issue #19. The answers below are the
## conventional ones; each is stated here so a different choice is a visible
## change rather than a silent one.
##
## **Tab enters the group, Enter is not required.** Tab lands on a member
## directly, and Tab from anywhere inside leaves. The alternative -- Tab skips
## the group, Enter descends -- means a keyboard user cannot reach a list
## without knowing it is there. Roving tabindex is what WAI-ARIA specifies for
## composite widgets and what GTK, Qt and Win32 all do.
##
## **Escape pops one level.** From a list inside a tab page, Escape leaves the
## list and stays on the page. Popping all the way out would make the key
## unrepeatable and would surprise in exactly the nested case that motivates
## groups at all.
##
## **Navigation stops at the ends; it does not wrap and does not leak.** Down on
## the last row does nothing. Wrapping is defensible and is what the top-level
## Tab chain does, so it is a parameter -- but the default is "stop", because an
## arrow key that silently jumps out of the group the user is reading is worse
## than one that does nothing. `step` takes `wrap` for callers that disagree.
##
## **Groups nest.** A list inside a tab page inside a form is three levels, and
## `enclosingGroup` walks out one at a time.
##
## ## Everything here is a pure function over the tree
##
## No FocusManager, no event, no window. focus_manager.nim holds the state --
## which group is active, which widget is focused -- and asks these questions.

import rui_core
import std/options

proc isGroup*(widget: Widget): bool =
  ## A hidden or disabled group is not a group: its members are unreachable, so
  ## treating it as a stop would strand Tab inside an empty container.
  widget != nil and widget.focusGroup and widget.visible and widget.enabled

proc enclosingGroup*(widget: Widget): Widget =
  ## Nearest ancestor that is a group, or nil at the top level. Does not
  ## consider `widget` itself -- a group's own enclosing group is the one
  ## outside it, which is what makes Escape pop exactly one level.
  if widget == nil:
    return nil
  var w = widget.parent
  while w != nil:
    if w.isGroup:
      return w
    w = w.parent
  nil

proc groupDepth*(widget: Widget): int =
  ## How many groups enclose this widget. 0 at the top level.
  var w = enclosingGroup(widget)
  while w != nil:
    inc result
    w = enclosingGroup(w)

proc isWithin*(widget, scope: Widget): bool =
  ## Is `widget` inside `scope`? A nil scope is the whole tree, so everything is
  ## within it.
  if scope == nil:
    return true
  var w = widget
  while w != nil:
    if w == scope:
      return true
    w = w.parent
  false

proc navigable(widget: Widget): bool =
  ## Reachable at all: an invisible or disabled widget is not, and neither is
  ## anything inside it.
  widget.visible and widget.enabled

proc collectEntries(scope: Widget, dest: var seq[Widget]) =
  for child in scope.children:
    if not child.navigable:
      continue
    if child.isGroup:
      # A nested group is one entry and is not descended into. That is the whole
      # point: its members belong to its own level, not to this one.
      dest.add(child)
      continue
    if child.focusable:
      dest.add(child)
    # A focusable widget can still contain focusable children -- a composite
    # with its own inner controls -- so the walk continues past it either way.
    collectEntries(child, dest)

proc focusEntries*(scope: Widget): seq[Widget] =
  ## What Tab (or an arrow key, inside a group) steps through at this level:
  ## the focusable widgets directly under `scope`, plus each nested group as a
  ## single entry.
  ##
  ## The same proc serves both levels, which is the reason groups nest for free:
  ## navigating inside a group is navigating the entries of that group, and
  ## navigating at the top is navigating the entries of the root.
  if scope != nil:
    collectEntries(scope, result)

proc entryContaining(entries: openArray[Widget], widget, scope: Widget): Widget =
  ## Walk out from `widget` to the first ancestor-or-self that `entries` lists,
  ## stopping at `scope`.
  var w = widget
  while w != nil and w != scope:
    if w in entries:
      return w
    w = w.parent
  nil

proc entryFor*(scope, widget: Widget): Widget =
  ## Which entry of `scope` the focus is currently "on".
  ##
  ## Focus sits on a leaf, but the thing being navigated at this level may be a
  ## group several levels up -- or the leaf itself, if it is an entry in its own
  ## right. So this walks out from the widget and returns the first
  ## ancestor-or-self that `focusEntries` actually lists.
  ##
  ## Walking to a direct child of `scope` instead would be wrong: entries are
  ## not necessarily direct children. A focusable control inside a plain VStack
  ## is an entry of the level the VStack sits in, and the VStack is not.
  if widget == nil or not widget.isWithin(scope):
    return nil
  entryContaining(focusEntries(scope), widget, scope)

proc indexOf(entries: openArray[Widget], widget: Widget): int =
  for i, entry in entries:
    if entry == widget:
      return i
  -1

proc endOf(entries: openArray[Widget], delta: int): Widget =
  ## Where navigation starts when the focus is not at this level yet: whichever
  ## end the direction implies.
  if delta >= 0: entries[0] else: entries[^1]

proc wrapped(entries: openArray[Widget], target: int,
             wrap: bool): Option[Widget] =
  ## Past an end. `none` unless the caller asked for wrapping -- which is the
  ## signal to do something else (leave the group, leave the key unhandled)
  ## rather than a failure. Same shape as list_input.nextFocusIndex.
  if wrap: some(entries[(target + entries.len) mod entries.len])
  else: none(Widget)

proc step*(entries: openArray[Widget], current: Widget, delta: int,
           wrap: bool): Option[Widget] =
  ## The entry `delta` places from `current`, or `none` at the end when not
  ## wrapping.
  if entries.len == 0:
    return none(Widget)

  let index = entries.indexOf(current)
  if index < 0:
    return some(entries.endOf(delta))

  let target = index + delta
  if target < 0 or target >= entries.len:
    return entries.wrapped(target, wrap)
  some(entries[target])

proc firstMember*(group: Widget): Widget =
  ## Where focus lands when Tab enters a group forwards.
  ##
  ## A group whose first entry is itself a group recurses, so Tab into a tab
  ## page holding a list lands on the list's first row rather than on the list.
  let entries = focusEntries(group)
  if entries.len == 0:
    return nil
  if entries[0].isGroup:
    return firstMember(entries[0])
  entries[0]

proc lastMember*(group: Widget): Widget =
  ## Where focus lands when Shift+Tab enters a group backwards -- at its end,
  ## so reversing direction retraces the same path.
  let entries = focusEntries(group)
  if entries.len == 0:
    return nil
  if entries[^1].isGroup:
    return lastMember(entries[^1])
  entries[^1]

proc descend*(entry: Widget, forward: bool): Widget =
  ## The widget that should actually receive focus when navigation arrives at
  ## `entry`. A plain widget is itself; a group hands over to a member.
  ##
  ## Returns nil for an empty group, which the caller reads as "skip it" -- a
  ## group with nothing focusable in it must not swallow the Tab.
  if not entry.isGroup:
    return entry
  if forward: firstMember(entry) else: lastMember(entry)
