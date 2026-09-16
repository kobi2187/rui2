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
import std/[options, tables]

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
    prevFocusModifiers: @[LeftShift, RightShift]
  )
# ============================================================================
# Configuration
# ============================================================================

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

proc clearFocus*(fm: FocusManager) =
  ## Remove focus from current widget
  if fm.focusedWidget != nil:
    fm.focusedWidget.focused = false
    # Trigger onBlur callback
    if fm.focusedWidget.onBlur.isSome:
      fm.focusedWidget.onBlur.get()()
    fm.focusedWidget = nil

proc setFocus*(fm: FocusManager, widget: Widget) =
  ## Set focus to a specific widget
  ## Automatically unfocuses previous widget

  if widget == nil:
    fm.clearFocus()
    return

  # Don't refocus same widget
  if fm.focusedWidget == widget:
    return

  # Unfocus previous widget
  if fm.focusedWidget != nil:
    fm.focusedWidget.focused = false
    # Trigger onBlur callback on previous widget
    if fm.focusedWidget.onBlur.isSome:
      fm.focusedWidget.onBlur.get()()

  # Focus new widget
  fm.focusedWidget = widget
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

proc nextFocus*(fm: FocusManager, rootWidget: Widget) =
  ## Move focus to next widget in tab order
  ## Wraps around to first widget if at end

  fm.ensureFocusChain(rootWidget)

  if fm.focusChain.len == 0:
    return

  # No current focus - focus first widget
  if fm.focusedWidget == nil:
    fm.setFocus(fm.focusChain[0])
    return

  # Find current widget in chain
  var currentIndex = -1
  for i, widget in fm.focusChain:
    if widget == fm.focusedWidget:
      currentIndex = i
      break

  # Move to next (wrap around)
  if currentIndex >= 0:
    let nextIndex = (currentIndex + 1) mod fm.focusChain.len
    fm.setFocus(fm.focusChain[nextIndex])
  else:
    # Current widget not in chain (removed?) - focus first
    fm.setFocus(fm.focusChain[0])

proc prevFocus*(fm: FocusManager, rootWidget: Widget) =
  ## Move focus to previous widget in tab order
  ## Wraps around to last widget if at beginning

  fm.ensureFocusChain(rootWidget)

  if fm.focusChain.len == 0:
    return

  # No current focus - focus last widget
  if fm.focusedWidget == nil:
    fm.setFocus(fm.focusChain[^1])  # Last widget
    return

  # Find current widget in chain
  var currentIndex = -1
  for i, widget in fm.focusChain:
    if widget == fm.focusedWidget:
      currentIndex = i
      break

  # Move to previous (wrap around)
  if currentIndex >= 0:
    let prevIndex = if currentIndex == 0:
                      fm.focusChain.len - 1
                    else:
                      currentIndex - 1
    fm.setFocus(fm.focusChain[prevIndex])
  else:
    # Current widget not in chain (removed?) - focus last
    fm.setFocus(fm.focusChain[^1])

# ============================================================================
# Event Routing
# ============================================================================

proc handleKeyboardEvent*(fm: FocusManager, event: GuiEvent, rootWidget: Widget): bool =
  ## Route a keyboard event, innermost first.
  ##
  ## **The focused widget gets first refusal.** Only keys it leaves unhandled
  ## reach this manager's own navigation keys. That is what lets a focused
  ## ListBox use Up/Down for its rows while the same keys move between widgets
  ## everywhere else, and a TextInput keep Home for its caret.
  ##
  ## This used to be the other way round -- navigation keys were tested first,
  ## so a focused widget never saw any key that had been configured for
  ## navigation, and the two levels could not coexist.
  ##
  ## Returns true if the event was handled, by either level.
  if fm.focusedWidget != nil and fm.focusedWidget.handleInput(event):
    return true

  # Not claimed by the focused widget: fall outward to navigation.
  if event.kind == evKeyDown:
    # Check if this is a next-focus key
    if event.key in fm.nextFocusKeys:
      # Check if modifiers pressed (for prev focus)
      var modifierPressed = false
      for modifier in fm.prevFocusModifiers:
        if isKeyDown(modifier):
          modifierPressed = true
          break

      if modifierPressed:
        fm.prevFocus(rootWidget)
      else:
        fm.nextFocus(rootWidget)
      return true

    # Check if this is a prev-focus key (without modifiers)
    if event.key in fm.prevFocusKeys:
      fm.prevFocus(rootWidget)
      return true

  # The focused widget already had its turn at the top, so there is nothing
  # left to try.
  false

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
