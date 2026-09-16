## Focus Manager
##
## Global coordination of keyboard focus across all widgets.
## Ensures only one widget has focus at a time, handles tab navigation,
## and routes keyboard events to the focused widget.
##
## Responsibilities:
## - Track currently focused widget
## - Automatic unfocus when focusing new widget
## - Tab/Shift+Tab navigation through focus chain
## - Route keyboard events to focused widget
## - Trigger onFocus/onBlur callbacks

import rui_core
import focus_groups
import std/[options, tables]

export focus_groups

import raylib

type
  FocusManager* = ref object
    focusedWidget*: Widget           # Currently focused widget (nil if none)
    focusChain*: seq[Widget]         # Tab order (built from widget tree)
    focusChainDirty*: bool           # Needs rebuild
    builtAtVersion: int              # tree structure version the chain was built at
    focusableWidgets*: Table[WidgetId, Widget]  # Quick lookup

    # Configurable navigation keys
    nextFocusKeys*: seq[KeyboardKey]      # Keys to move to next widget (default: Tab)
    prevFocusKeys*: seq[KeyboardKey]      # Keys to move to previous widget (default: none)
    prevFocusModifiers*: seq[KeyboardKey] # Modifiers for prev (default: Shift)

    # Within a focus group
    activeGroup*: Widget
      ## The group arrow keys currently navigate, or nil at the top level.
      ## Kept in step with `focusedWidget` by setFocus.
    groupNextKeys*: seq[KeyboardKey]      # Within a group, forwards (default: Down, Right)
    groupPrevKeys*: seq[KeyboardKey]      # Within a group, backwards (default: Up, Left)
    exitGroupKeys*: seq[KeyboardKey]      # Pop one level (default: Escape)
    wrapWithinGroup*: bool
      ## Does an arrow key at the end of a group come round to the start?
      ## Default false: an arrow that silently jumps out of the group the user
      ## is reading is worse than one that does nothing. See focus_groups.nim
      ## for the rest of that argument.

# ============================================================================
# Initialization
# ============================================================================

proc newFocusManager*(): FocusManager =
  ## Create a new focus manager with default Tab/Shift+Tab navigation
  result = FocusManager(
    focusedWidget: nil,
    focusChain: @[],
    focusChainDirty: true,
    builtAtVersion: -1,              # -1 can never match a real version
    focusableWidgets: initTable[WidgetId, Widget](),
    nextFocusKeys: @[Tab],
    prevFocusKeys: @[],
    prevFocusModifiers: @[LeftShift, RightShift],
    activeGroup: nil,
    groupNextKeys: @[KeyboardKey.Down, KeyboardKey.Right],
    groupPrevKeys: @[KeyboardKey.Up, KeyboardKey.Left],
    exitGroupKeys: @[KeyboardKey.Escape],
    wrapWithinGroup: false
  )
# ============================================================================
# Configuration
# ============================================================================

proc setGroupKeys*(fm: FocusManager,
                   nextKeys: seq[KeyboardKey],
                   prevKeys: seq[KeyboardKey] = @[],
                   exitKeys: seq[KeyboardKey] = @[]) =
  ## Configure the keys that navigate *within* the active focus group.
  ## Examples:
  ##   fm.setGroupKeys(@[Down], @[Up], @[Escape])       # a vertical list
  ##   fm.setGroupKeys(@[Right], @[Left], @[Escape])    # a toolbar
  ##   fm.setGroupKeys(@[J], @[K], @[Escape])           # vim-style
  ##
  ## These are only consulted after the focused widget has declined the key, so
  ## a TextInput inside a group keeps Left and Right for its own caret.
  fm.groupNextKeys = nextKeys
  fm.groupPrevKeys = prevKeys
  fm.exitGroupKeys = exitKeys

proc setNavigationKeys*(fm: FocusManager,
                       nextKeys: seq[KeyboardKey],
                       prevKeys: seq[KeyboardKey] = @[],
                       prevModifiers: seq[KeyboardKey] = @[]) =
  ## Configure which keys trigger focus navigation
  ## Examples:
  ##   fm.setNavigationKeys(@[Tab], @[], @[LeftShift, RightShift])  # Tab/Shift+Tab
  ##   fm.setNavigationKeys(@[Down], @[Up])                         # Up/Down arrows
  ##   fm.setNavigationKeys(@[J], @[K])                             # Vim-style j/k
  fm.nextFocusKeys = nextKeys
  fm.prevFocusKeys = prevKeys
  fm.prevFocusModifiers = prevModifiers

# ============================================================================
# Focus Chain Building
# ============================================================================

proc collectFocusableWidgets(widget: Widget, result: var seq[Widget]) =
  ## Recursively collect focusable widgets in tree order
  ## A widget is focusable if it's visible, enabled, and can accept keyboard input

  if not widget.visible or not widget.enabled:
    return

  # Opt-in, via the `focusable` field. This used to add every visible and
  # enabled widget -- so the root container and every static Label were tab
  # stops -- with a `TODO: Add isFocusable field to Widget type` explaining why.
  #
  # Note the recursion continues regardless: a container is normally not a stop
  # itself, but its children still are.
  if widget.focusable:
    result.add(widget)

  for child in widget.children:
    collectFocusableWidgets(child, result)

proc buildFocusChain*(fm: FocusManager, rootWidget: Widget) =
  ## Rebuild the focus chain from the widget tree
  ## Call this when widgets are added/removed or tree structure changes

  fm.focusChain = @[]
  fm.focusableWidgets.clear()

  if rootWidget != nil:
    collectFocusableWidgets(rootWidget, fm.focusChain)

    # Build lookup table
    for widget in fm.focusChain:
      fm.focusableWidgets[widget.id] = widget

  fm.focusChainDirty = false
  fm.builtAtVersion = structureVersion()

proc ensureFocusChain(fm: FocusManager, rootWidget: Widget) =
  ## Rebuild the focus chain when it is stale.
  ##
  ## Stale means either something asked for a rebuild explicitly (markDirty, a
  ## visibility change) or the tree's shape has changed since the chain was
  ## built. The version check is what makes a widget added after the first Tab
  ## press reachable; before it, `focusChainDirty` was set true once at
  ## construction, cleared on first use, and never set again by anything.
  ##
  ## Comparing two ints per navigation, not walking the tree -- an unchanged
  ## tree costs nothing.
  if fm.focusChainDirty or fm.builtAtVersion != structureVersion():
    fm.buildFocusChain(rootWidget)

# ============================================================================
# Focus Management
# ============================================================================

proc blurCurrent(fm: FocusManager) =
  if fm.focusedWidget == nil:
    return
  fm.focusedWidget.focused = false
  if fm.focusedWidget.onBlur.isSome:
    fm.focusedWidget.onBlur.get()()

proc clearFocus*(fm: FocusManager) =
  ## Remove focus from current widget
  fm.blurCurrent()
  fm.focusedWidget = nil
  fm.activeGroup = nil

proc setFocus*(fm: FocusManager, widget: Widget) =
  ## Set focus to a specific widget
  ## Automatically unfocuses previous widget

  if widget == nil:
    fm.clearFocus()
    return

  # Don't refocus same widget
  if fm.focusedWidget == widget:
    return

  fm.blurCurrent()

  # Focus new widget. The active group follows the focus rather than being set
  # separately, so clicking into a list makes its arrow keys live for the same
  # reason tabbing into it does -- there is one answer to "which group are we
  # in", derived from where focus actually is.
  fm.focusedWidget = widget
  fm.activeGroup = enclosingGroup(widget)
  widget.focused = true
  # Trigger onFocus callback on new widget
  if widget.onFocus.isSome:
    widget.onFocus.get()()

proc getFocusedWidget*(fm: FocusManager): Widget =
  ## Get currently focused widget (nil if none)
  fm.focusedWidget

proc hasFocus*(fm: FocusManager, widget: Widget): bool =
  ## Check if widget has focus
  fm.focusedWidget == widget

# ============================================================================
# Tab Navigation
# ============================================================================

proc navigationLevel(fm: FocusManager, rootWidget: Widget): Widget =
  ## The level Tab navigates: one step outside whatever group the focus is in.
  ## At the top level that is the root itself.
  let inner = enclosingGroup(fm.focusedWidget)
  if inner == nil:
    return rootWidget
  let outer = enclosingGroup(inner)
  if outer == nil: rootWidget else: outer

proc nextLanding(entries: openArray[Widget], current: Widget,
                 delta: int): Widget =
  ## The widget Tab should actually land on, skipping empty groups.
  ##
  ## A group with nothing focusable in it must not swallow the keypress, so the
  ## walk continues past it. `guard` stops a tree of nothing but empty groups
  ## spinning. Wrapping at this level is the long-standing Tab behaviour.
  var current = current
  var guard = entries.len + 1
  while guard > 0:
    dec guard
    let nextEntry = step(entries, current, delta, wrap = true)
    if nextEntry.isNone:
      return nil
    let target = descend(nextEntry.get(), forward = delta >= 0)
    if target != nil:
      return target
    current = nextEntry.get()
  nil

proc moveAcross(fm: FocusManager, rootWidget: Widget, delta: int) =
  ## Tab, or Shift+Tab: move between entries at the level *outside* any group
  ## the focus is currently in.
  ##
  ## Tab always leaves the group, wherever in it the focus sits. That is the
  ## roving-tabindex contract: a group is one stop, not N. Arrow keys are what
  ## move inside it.
  ##
  ## Nested groups leave one level per press, which is what makes a list inside
  ## a tab page inside a form navigable without the user having to know how
  ## deeply it is nested.
  fm.ensureFocusChain(rootWidget)

  let level = fm.navigationLevel(rootWidget)
  let entries = focusEntries(level)
  if entries.len == 0:
    return

  let landing = nextLanding(entries, entryFor(level, fm.focusedWidget), delta)
  if landing != nil:
    fm.setFocus(landing)

proc nextFocus*(fm: FocusManager, rootWidget: Widget) =
  ## Move focus to the next entry in tab order, wrapping at the end.
  fm.moveAcross(rootWidget, 1)

proc prevFocus*(fm: FocusManager, rootWidget: Widget) =
  ## Move focus to the previous entry in tab order, wrapping at the start.
  fm.moveAcross(rootWidget, -1)

proc moveWithinGroup*(fm: FocusManager, delta: int): bool =
  ## An arrow key inside the active group. False when there is no group, or
  ## when the move would run off an end and wrapping is off -- in which case
  ## the key is left unhandled rather than jumping somewhere unexpected.
  if fm.activeGroup == nil:
    return false
  let entries = focusEntries(fm.activeGroup)
  let current = entryFor(fm.activeGroup, fm.focusedWidget)
  let nextEntry = step(entries, current, delta, fm.wrapWithinGroup)
  if nextEntry.isNone:
    return false
  let target = descend(nextEntry.get(), forward = delta >= 0)
  if target == nil:
    return false
  fm.setFocus(target)
  true

proc landingOutside(level, group: Widget): Widget =
  ## Somewhere at `level` to put the focus that is not inside `group`.
  for entry in focusEntries(level):
    if entry != group:
      let target = descend(entry, forward = true)
      if target != nil:
        return target
  nil

proc popLevel(group, outer: Widget): Widget =
  ## Where Escape pops to: the enclosing group if there is one, otherwise the
  ## container the group sits in. nil when the group is the whole tree.
  if outer != nil: outer else: group.parent

proc exitGroup*(fm: FocusManager): bool =
  ## Escape: leave the innermost group, one level only.
  ##
  ## Focus moves to the group's own level rather than being cleared, so the user
  ## is still somewhere and the next Tab continues from there. From a list
  ## inside a tab page, Escape leaves the list and stays on the page -- which is
  ## the nested case that makes "one level" the right answer rather than "all
  ## the way out".
  if fm.activeGroup == nil:
    return false
  let group = fm.activeGroup
  let outer = enclosingGroup(group)
  let level = popLevel(group, outer)
  if level == nil:
    # A group with no parent is the whole tree; there is nowhere to pop to.
    return false

  # Prefer the group itself if it is a tab stop in its own right; otherwise the
  # first thing at that level which is not inside it.
  let landing = if group.focusable: group else: landingOutside(level, group)
  if landing != nil:
    fm.setFocus(landing)

  # Whether or not there was somewhere to land, arrows stop routing into the
  # group -- being unable to leave is worse than leaving without moving.
  fm.activeGroup = outer
  true

proc groupDelta(fm: FocusManager, key: KeyboardKey): int =
  ## Which way an arrow key moves inside a group; 0 for a key that is neither.
  if key in fm.groupNextKeys: 1
  elif key in fm.groupPrevKeys: -1
  else: 0

proc handleGroupKeys(fm: FocusManager, key: KeyboardKey): bool =
  ## The innermost level: arrows and Escape inside the active group.
  if fm.activeGroup == nil:
    return false
  let delta = fm.groupDelta(key)
  if delta != 0:
    return fm.moveWithinGroup(delta)
  key in fm.exitGroupKeys and fm.exitGroup()

proc anyModifierDown(fm: FocusManager): bool =
  for modifier in fm.prevFocusModifiers:
    if isKeyDown(modifier):
      return true
  false

proc handleNavigationKeys(fm: FocusManager, key: KeyboardKey,
                          rootWidget: Widget): bool =
  ## The outer level: Tab and Shift+Tab between entries.
  if key in fm.nextFocusKeys:
    if fm.anyModifierDown(): fm.prevFocus(rootWidget)
    else: fm.nextFocus(rootWidget)
    return true
  if key in fm.prevFocusKeys:
    fm.prevFocus(rootWidget)
    return true
  false

proc handleKeyboardEvent*(fm: FocusManager, event: GuiEvent,
                          rootWidget: Widget): bool =
  ## Route a keyboard event outward: focused widget, then its group, then the
  ## global navigation keys.
  ##
  ## **The focused widget gets first refusal.** Only keys it leaves unhandled
  ## reach the group or the manager. That is what lets a focused ListBox use
  ## Up/Down for its rows while the same keys move between toolbar buttons
  ## elsewhere, and a TextInput keep Left and Right for its caret even inside a
  ## group that navigates with them.
  ##
  ## This used to be the other way round -- navigation keys were tested first,
  ## so a focused widget never saw any key that had been configured for
  ## navigation, and the levels could not coexist.
  ##
  ## Returns true if the event was handled, at any level.
  if fm.focusedWidget != nil and fm.focusedWidget.handleInput(event):
    return true

  if event.kind != evKeyDown:
    return false

  fm.handleGroupKeys(event.key) or
    fm.handleNavigationKeys(event.key, rootWidget)

# ============================================================================
# Focus Request from Click
# ============================================================================

proc requestFocus*(fm: FocusManager, widget: Widget) =
  ## Request focus (typically called when widget is clicked)
  ## Same as setFocus but more explicit name for click handling
  fm.setFocus(widget)

# ============================================================================
# Tree Change Notifications
# ============================================================================

proc markDirty*(fm: FocusManager) =
  ## Mark focus chain as dirty (needs rebuild)
  ## Call this when widgets are added/removed from tree
  fm.focusChainDirty = true

proc widgetRemoved*(fm: FocusManager, widget: Widget) =
  ## Notify that a widget was removed
  ## Clears focus if it was the focused widget

  if fm.focusedWidget == widget:
    fm.clearFocus()

  fm.markDirty()

# ============================================================================
# Debug/Stats
# ============================================================================

proc getStats*(fm: FocusManager): string =
  ## Return focus manager statistics
  result = "FocusManager Stats:\n"
  result &= "  Focused widget: "
  if fm.focusedWidget != nil:
    result &= $fm.focusedWidget.id
  else:
    result &= "none"
  result &= "\n"
  result &= "  Focus chain length: " & $fm.focusChain.len & "\n"
  result &= "  Chain dirty: " & $fm.focusChainDirty & "\n"
