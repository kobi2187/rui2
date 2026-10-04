## What the keyboard help overlay says, as plain values.
##
## The overlay is a shade over the window with two kinds of message:
##
## - a line along the top for the general navigation keys -- the user's own
##   bindings, so if they moved Tab to F6 that is what it says;
## - a small badge beside every widget that has a shortcut (`.shortcut("Ctrl+S")`),
##   so the keys for *this* application are shown where they apply.
##
## Everything here is pure: wording, collecting the badges from a widget tree,
## and placing a badge so that it stays on screen and off its neighbours.

import std/[strutils, options]
import raylib
import types
import keys
import key_map

type
  HelpEntry* = tuple[keys, text: string]

  HintMark* = tuple[target: Rect, keys: string]
    ## A widget with a shortcut: where it is, and what to press.

const shortText*: array[NavAction, string] = [
  nextInGroup: "next widget",
  prevInGroup: "previous widget",
  leaveGroup: "leave container",
  nextGroup: "next container",
  prevGroup: "previous container",
  showHelp: "help"]

proc keyName(k: KeyboardKey): string =
  ## Short, familiar names for the keys people navigate with.
  case k
  of KeyboardKey.Up: "↑"
  of KeyboardKey.Down: "↓"
  of KeyboardKey.Left: "←"
  of KeyboardKey.Right: "→"
  of KeyboardKey.Escape: "Esc"
  else: $k

proc display*(c: Chord): string =
  ## How a chord reads to a person: the chord itself, except that Shift+Slash
  ## is the "?" it types.
  if c.key == KeyboardKey.Slash and c.mods == {kmShift}:
    return "?"
  var parts: seq[string]
  if kmCtrl in c.mods: parts.add "Ctrl"
  if kmAlt in c.mods: parts.add "Alt"
  if kmShift in c.mods: parts.add "Shift"
  parts.add keyName(c.key)
  parts.join("+")

proc keysText*(map: KeyMap, action: NavAction): string =
  ## "Tab / F6" -- every chord bound to the action, or "(unbound)".
  var parts: seq[string]
  for c in map.bindings[action]:
    parts.add c.display
  if parts.len == 0: "(unbound)" else: parts.join("/")

proc navigationItems*(map: KeyMap): seq[HelpEntry] =
  ## The navigation keys, in the order a person reaches for them. An action the
  ## user has unbound is left out: there is nothing to press.
  for action in [nextGroup, prevGroup, nextInGroup, prevInGroup, leaveGroup, showHelp]:
    if map.bindings[action].len > 0:
      result.add (map.keysText(action), shortText[action])

proc infoLine*(map: KeyMap): string =
  ## One line: "Tab next container  ·  Shift+Tab previous container  ·  ...".
  var parts: seq[string]
  for item in navigationItems(map):
    parts.add item.keys & " " & item.text
  parts.join("   ·   ")

proc collectHints*(root: Widget): seq[HintMark] =
  ## Every visible, enabled widget under `root` that has a shortcut, in tree
  ## order, with the chord as a person would read it.
  if root == nil or not root.visible:
    return
  if root.hotkey.len > 0 and root.enabled and root.bounds.width > 0:
    let parsed = parseKeyChord(root.hotkey)
    if parsed.isSome:
      result.add (root.bounds, display((parsed.get.key, parsed.get.mods)))
  for child in root.children:
    result.add collectHints(child)

proc placeBadge*(target: Rect, size: Size, within: Rect,
                 taken: openArray[Rect] = []): Rect =
  ## Where a badge of `size` goes for a widget at `target`: hanging off its
  ## bottom-left edge (overlapping it a little, so it reads as attached, but
  ## clear of the label in the middle), kept inside `within`, and moved down
  ## past any badge already placed there so neighbouring hints never sit on
  ## each other.
  result = Rect(x: target.x + 4, y: target.y + target.height - size.height * 0.3,
                width: size.width, height: size.height)
  for _ in 0 ..< 8:
    var moved = false
    for t in taken:
      if result.x < t.x + t.width and result.x + result.width > t.x and
         result.y < t.y + t.height and result.y + result.height > t.y:
        result.y = t.y + t.height + 2
        moved = true
    if not moved: break
  result.x = clamp(result.x, within.x, max(within.x, within.x + within.width - result.width))
  result.y = clamp(result.y, within.y, max(within.y, within.y + within.height - result.height))

proc shortcutMatches*(widget: Widget, key: KeyboardKey, mods: set[KeyMod]): bool =
  ## Whether this key press is the widget's shortcut.
  if widget.hotkey.len == 0:
    return false
  let parsed = parseKeyChord(widget.hotkey)
  parsed.isSome and parsed.get.key == key and parsed.get.mods == mods

proc findShortcut*(root: Widget, key: KeyboardKey, mods: set[KeyMod]): Widget =
  ## The first visible, enabled widget whose shortcut this is, or nil.
  if root == nil or not root.visible:
    return nil
  if root.enabled and root.shortcutMatches(key, mods):
    return root
  for child in root.children:
    let hit = findShortcut(child, key, mods)
    if hit != nil:
      return hit
  nil
